class_name DuelController
extends Node

# The duel's rules engine. Pure state machine over two fighters: it takes a
# DuelContext, consumes actions, and emits what happened. It draws nothing,
# reads no game state, and decides no consequences.
#
# It is driven by `advance(delta)`, which `_process` calls when the controller
# lives in a scene tree. Tests instantiate it outside the tree and step it by
# hand, so the whole fight is verifiable headlessly.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")
const DuelContextScript := preload("res://game/scripts/duel/DuelContext.gd")
const DuelOpponentBrainScript := preload("res://game/scripts/duel/DuelOpponentBrain.gd")

const SIDE_PLAYER := "player"
const SIDE_OPPONENT := "opponent"

const STATE_WAITING := "waiting"
const STATE_READY := "ready"
const STATE_WINDUP := "windup"
const STATE_RECOVER := "recover"
const STATE_EVADE := "evade"
const STATE_STAGGER := "stagger"
const STATE_TAUNT := "taunt"
const STATE_PISTOL := "pistol_draw"
const STATE_YIELD := "yield"

const HIT_CLEAN := "clean"
const HIT_INTERRUPT := "interrupt"
const HIT_RIPOSTE := "riposte"
const HIT_WRONG_EVADE := "wrong_evade"
const HIT_PISTOL := "pistol"

# How long a player input survives while they are still recovering. Without it
# the fight punishes correct-but-early reads, which reads as dropped input.
const INPUT_BUFFER_TIME := 0.18

signal duel_started
signal state_changed(side: String, state: String, action: String, duration: float)
signal hit_landed(side: String, action: String, damage: float, kind: String)
signal attack_countered(side: String, attack: String, evasion: String)
signal taunt_landed(side: String)
signal pistol_fired(side: String)
signal pistol_spoiled(side: String)
signal vigor_changed(side: String, fraction: float)
signal support_changed(side: String, count: float, fraction: float)
signal support_surged(side: String)
signal support_broken(side: String)
signal duel_finished(result: Dictionary)

var context: Dictionary = {}
var rules: Dictionary = {}
var timing: Dictionary = {}
var damage_rules: Dictionary = {}
var taunt_rules: Dictionary = {}
var support_rules: Dictionary = {}
# The fight going on around the duellists, when the caller supplied one. Empty
# for a straight one-on-one.
var support: Dictionary = {}
var weapons: Dictionary = {}
var difficulty: Dictionary = {}
var fighters: Dictionary = {}
var is_running: bool = false
var elapsed: float = 0.0
var opening_timer: float = 0.0
var finish_timer: float = -1.0
var pending_outcome: String = ""
var pending_reason: String = ""
var rng := RandomNumberGenerator.new()
# Off means the opposing fighter only acts when something calls
# submit_opponent_action: tests drive scripted exchanges through it, and a
# future caller could script a story duel the same way.
var opponent_brain_enabled: bool = true

var _brain: RefCounted


func configure(duel_context: Dictionary) -> void:
	context = DuelContextScript.normalize(duel_context)
	rules = ContentCatalog.load_duel_rules(str(context.get("rules_id", "default")))
	timing = rules.get("timing", {})
	damage_rules = rules.get("damage", {})
	taunt_rules = rules.get("taunt", {})
	support_rules = rules.get("support", {})
	weapons = ContentCatalog.load_duel_weapons()
	# The duel reads only its own section of the game-wide level, by the id its
	# caller supplied. It never asks what the player's difficulty setting is.
	difficulty = ContentCatalog.load_difficulty_section(str(context.get("difficulty_id", "normal")), "duel")
	_apply_difficulty()
	var seed_value := int(context.get("rng_seed", 0))
	if seed_value > 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_brain = DuelOpponentBrainScript.new()


# `player_weapon_id` comes from the pre-duel weapon panel; an empty string keeps
# whatever the context asked for.
func start(player_weapon_id: String = "") -> void:
	if context.is_empty():
		configure({})
	fighters = {
		SIDE_PLAYER: _make_fighter(context.get("player", {}), player_weapon_id),
		SIDE_OPPONENT: _make_fighter(context.get("opponent", {}), "")
	}
	_build_support()
	elapsed = 0.0
	opening_timer = float(timing.get("opening_delay", 1.0))
	finish_timer = -1.0
	pending_outcome = ""
	pending_reason = ""
	is_running = true
	_brain.configure(fighters[SIDE_OPPONENT], rng, difficulty)
	duel_started.emit()
	for side in [SIDE_PLAYER, SIDE_OPPONENT]:
		vigor_changed.emit(side, get_vigor_fraction(side))
		if has_support():
			support_changed.emit(side, get_support_count(side), get_support_fraction(side))
		_set_state(side, STATE_WAITING, "", opening_timer)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not is_running:
		return
	elapsed += delta

	if finish_timer >= 0.0:
		finish_timer -= delta
		_tick_fighter(SIDE_PLAYER, delta)
		_tick_fighter(SIDE_OPPONENT, delta)
		if finish_timer <= 0.0:
			_finish(pending_outcome)
		return

	if opening_timer > 0.0:
		opening_timer -= delta
		if opening_timer <= 0.0:
			_set_state(SIDE_PLAYER, STATE_READY, "", 0.0)
			_set_state(SIDE_OPPONENT, STATE_READY, "", 0.0)
		return

	_tick_fighter(SIDE_PLAYER, delta)
	_tick_fighter(SIDE_OPPONENT, delta)
	if not is_running or finish_timer >= 0.0:
		return
	_advance_support(delta)
	if finish_timer >= 0.0:
		return
	_tick_player_buffer(delta)
	if opponent_brain_enabled and _brain:
		_brain.advance(delta, fighters[SIDE_OPPONENT], fighters[SIDE_PLAYER], self)


# Returns true when the action was accepted now; a rejected action is buffered
# briefly so a slightly-early press still lands.
func submit_player_action(action: String) -> bool:
	if not is_running or finish_timer >= 0.0 or opening_timer > 0.0:
		return false
	if _submit_action(SIDE_PLAYER, action):
		return true
	var fighter: Dictionary = fighters.get(SIDE_PLAYER, {})
	if not fighter.is_empty() and str(fighter.get("state")) != STATE_YIELD:
		fighter["buffered_action"] = action
		fighter["buffer_time"] = INPUT_BUFFER_TIME
	return false


# Used by the opponent brain, which decides in the same vocabulary the player
# uses — there is no privileged AI action set.
func submit_opponent_action(action: String, as_feint: bool = false) -> bool:
	return _submit_action(SIDE_OPPONENT, action, as_feint)


# The caller can pull the plug (the ship sinks under the duel, the player quits
# out). The result still honours the contract so callers have one code path.
func abandon() -> void:
	if not is_running:
		return
	_finish(DuelContextScript.OUTCOME_ABANDONED)


func get_fighter(side: String) -> Dictionary:
	return fighters.get(side, {})


func get_vigor_fraction(side: String) -> float:
	var fighter: Dictionary = fighters.get(side, {})
	if fighter.is_empty():
		return 0.0
	var max_vigor := float(fighter.get("max_vigor", 1.0))
	return clampf(float(fighter.get("vigor", 0.0)) / max_vigor, 0.0, 1.0) if max_vigor > 0.0 else 0.0


func has_support() -> bool:
	return not support.is_empty()


func get_support_count(side: String) -> float:
	return float(support.get(side, {}).get("count", 0.0))


func get_support_fraction(side: String) -> float:
	var side_support: Dictionary = support.get(side, {})
	var starting := float(side_support.get("starting_count", 0.0))
	if starting <= 0.0:
		return 0.0
	return clampf(float(side_support.get("count", 0.0)) / starting, 0.0, 1.0)


func get_support_label(side: String) -> String:
	return str(support.get(side, {}).get("label", ""))


func can_use_pistol(side: String) -> bool:
	var fighter: Dictionary = fighters.get(side, {})
	return bool(fighter.get("has_pistol", false)) and not bool(fighter.get("pistol_spent", false))


func is_rattled(side: String) -> bool:
	return float(fighters.get(side, {}).get("rattle_time", 0.0)) > 0.0


# Difficulty scales the OPPONENT only, and multiplies whatever the archetype
# already said — so a Fleet Captain stays tougher than a Merchant Master at
# every level. Pacing (how often they attack, how often they punish an opening)
# lives on the brain and matters more to how hard a duel feels than any of this.
func _apply_difficulty() -> void:
	if difficulty.is_empty():
		return
	var opponent: Dictionary = context.get("opponent", {})
	if opponent.is_empty():
		return
	opponent["vigor"] = float(opponent.get("vigor", 100.0)) * float(difficulty.get("vigor_multiplier", 1.0))
	opponent["reaction_time"] = float(opponent.get("reaction_time", 0.35)) * float(difficulty.get("reaction_time_multiplier", 1.0))
	opponent["read_accuracy"] = clampf(float(opponent.get("read_accuracy", 0.55)) * float(difficulty.get("read_accuracy_multiplier", 1.0)), 0.0, 1.0)
	opponent["aggression"] = clampf(float(opponent.get("aggression", 0.6)) * float(difficulty.get("aggression_multiplier", 1.0)), 0.0, 1.0)
	opponent["feint_chance"] = clampf(float(opponent.get("feint_chance", 0.2)) * float(difficulty.get("feint_chance_multiplier", 1.0)), 0.0, 1.0)
	opponent["pistol_discipline"] = clampf(float(opponent.get("pistol_discipline", 0.5)) * float(difficulty.get("pistol_discipline_multiplier", 1.0)), 0.0, 1.0)
	context["opponent"] = opponent


func _build_support() -> void:
	support = {}
	var context_support: Dictionary = context.get("support", {})
	if context_support.is_empty():
		return
	for side in [SIDE_PLAYER, SIDE_OPPONENT]:
		var side_data: Dictionary = context_support.get(side, {})
		var count := float(side_data.get("count", 0.0))
		support[side] = {
			"label": str(side_data.get("label", "")),
			"count": count,
			"starting_count": count,
			"strength": float(side_data.get("strength", 1.0)),
			"surge": 1.0,
			"reported": ceili(count)
		}


# The melee around the duel. Each side kills at a rate set by its OWN numbers,
# so an advantage compounds — but a captain landing blows surges their side, so
# fencing well buys time against worse odds without erasing them.
func _advance_support(delta: float) -> void:
	if not has_support():
		return
	var base := float(support_rules.get("base_kill_rate", 0.012))
	var decay := float(support_rules.get("surge_decay", 0.4))

	# Both sides swing from the counts they had at the start of the tick, so
	# whoever is processed first gains no advantage from it.
	var losses := {}
	for side in [SIDE_PLAYER, SIDE_OPPONENT]:
		var attacker: Dictionary = support[side]
		losses[_other_side(side)] = float(attacker.get("count", 0.0)) * float(attacker.get("strength", 1.0)) * float(attacker.get("surge", 1.0)) * base * delta
	for side in [SIDE_PLAYER, SIDE_OPPONENT]:
		_reduce_support(side, float(losses.get(side, 0.0)))
		var side_support: Dictionary = support[side]
		side_support["surge"] = move_toward(float(side_support.get("surge", 1.0)), 1.0, decay * delta)

	for side in [SIDE_PLAYER, SIDE_OPPONENT]:
		if get_support_count(side) <= 0.0:
			support_broken.emit(side)
			_begin_conclusion(side, DuelContextScript.REASON_SUPPORT_LOST)
			return


func _reduce_support(side: String, amount: float) -> void:
	if amount <= 0.0 or not has_support():
		return
	var side_support: Dictionary = support[side]
	side_support["count"] = maxf(0.0, float(side_support.get("count", 0.0)) - amount)
	# Report whole people, not fractions: the HUD and the crowd only care when
	# somebody actually falls.
	var whole := ceili(float(side_support["count"]))
	if whole != int(side_support.get("reported", whole)):
		side_support["reported"] = whole
		support_changed.emit(side, float(side_support["count"]), get_support_fraction(side))


# A landed blow is felt by both crews: theirs loses men on the spot, ours takes
# heart. This is the coupling that keeps the duel and the melee one fight.
func _rally_support(source_side: String, target_side: String) -> void:
	if not has_support():
		return
	_reduce_support(target_side, float(support_rules.get("hit_burst", 1.2)))
	var source_support: Dictionary = support[source_side]
	var surged := minf(
		float(source_support.get("surge", 1.0)) + float(support_rules.get("surge_gain", 0.5)),
		float(support_rules.get("surge_max", 2.0)))
	source_support["surge"] = surged
	support_surged.emit(source_side)


func _make_fighter(data: Dictionary, weapon_override: String) -> Dictionary:
	var weapon_id := weapon_override if not weapon_override.is_empty() else str(data.get("weapon", "longsword"))
	var weapon: Dictionary = weapons.get(weapon_id, {})
	if weapon.is_empty() and not weapons.is_empty():
		weapon_id = str(weapons.keys()[0])
		weapon = weapons[weapon_id]
	var vigor := float(data.get("vigor", 100.0))
	return {
		"data": data,
		"name": str(data.get("name", "Fighter")),
		"subtitle": str(data.get("subtitle", "")),
		"weapon_id": weapon_id,
		"weapon": weapon,
		"vigor": vigor,
		"max_vigor": vigor,
		"state": STATE_WAITING,
		"action": "",
		"state_time": 0.0,
		"state_duration": 0.0,
		"is_feint": false,
		"has_pistol": bool(data.get("pistol", false)),
		"pistol_spent": false,
		"pistol_fired": false,
		"rattle_time": 0.0,
		"hits_landed": 0,
		"hits_taken": 0,
		"buffered_action": "",
		"buffer_time": 0.0
	}


func _tick_fighter(side: String, delta: float) -> void:
	var fighter: Dictionary = fighters.get(side, {})
	if fighter.is_empty():
		return
	fighter["rattle_time"] = maxf(0.0, float(fighter.get("rattle_time", 0.0)) - delta)
	if float(fighter.get("state_duration", 0.0)) <= 0.0:
		return
	fighter["state_time"] = float(fighter.get("state_time", 0.0)) - delta
	if float(fighter["state_time"]) > 0.0:
		return
	_complete_state(side)


func _complete_state(side: String) -> void:
	var fighter: Dictionary = fighters[side]
	var state := str(fighter.get("state"))
	match state:
		STATE_WINDUP:
			if bool(fighter.get("is_feint", false)):
				# A feint buys the bait: short recovery, and the opponent has
				# usually spent an evasion on nothing.
				_set_state(side, STATE_RECOVER, "", _attack_recovery(fighter) * 0.6)
			else:
				_resolve_strike(side)
		STATE_EVADE:
			_set_state(side, STATE_RECOVER, "", float(timing.get("evade_recovery", 0.26)))
		STATE_TAUNT:
			_resolve_taunt(side)
		STATE_PISTOL:
			_resolve_pistol(side)
		STATE_YIELD:
			pass
		_:
			_set_state(side, STATE_READY, "", 0.0)


func _tick_player_buffer(delta: float) -> void:
	var fighter: Dictionary = fighters[SIDE_PLAYER]
	var buffered := str(fighter.get("buffered_action", ""))
	if buffered.is_empty():
		return
	fighter["buffer_time"] = float(fighter.get("buffer_time", 0.0)) - delta
	if float(fighter["buffer_time"]) <= 0.0:
		fighter["buffered_action"] = ""
		return
	if _submit_action(SIDE_PLAYER, buffered):
		fighter["buffered_action"] = ""


func _submit_action(side: String, action: String, as_feint: bool = false) -> bool:
	if not is_running or finish_timer >= 0.0 or opening_timer > 0.0:
		return false
	var fighter: Dictionary = fighters.get(side, {})
	if fighter.is_empty() or str(fighter.get("state")) != STATE_READY:
		return false

	if DuelActionScript.is_attack(action):
		fighter["is_feint"] = as_feint
		_set_state(side, STATE_WINDUP, action, _attack_windup(fighter))
		return true
	if DuelActionScript.is_evasion(action):
		var window := float(timing.get("evade_startup", 0.05)) + float(timing.get("evade_active", 0.34))
		_set_state(side, STATE_EVADE, action, window)
		return true
	if action == DuelActionScript.TAUNT:
		_set_state(side, STATE_TAUNT, action, float(timing.get("taunt_duration", 0.55)))
		return true
	if action == DuelActionScript.PISTOL:
		if not can_use_pistol(side):
			return false
		_set_state(side, STATE_PISTOL, action, float(timing.get("pistol_draw", 0.62)))
		return true
	return false


func _set_state(side: String, state: String, action: String, duration: float) -> void:
	var fighter: Dictionary = fighters[side]
	fighter["state"] = state
	fighter["action"] = action
	fighter["state_duration"] = duration
	fighter["state_time"] = duration
	if state != STATE_WINDUP:
		fighter["is_feint"] = false
	state_changed.emit(side, state, action, duration)


# A wound-up attack resolves against whatever the defender is doing at the
# instant it lands. Everything except the correct evasion gets hit; how badly
# depends on how wrong they were.
func _resolve_strike(attacker_side: String) -> void:
	var attacker: Dictionary = fighters[attacker_side]
	var defender_side := _other_side(attacker_side)
	var defender: Dictionary = fighters[defender_side]
	var action := str(attacker.get("action"))
	var kind := HIT_CLEAN
	var defender_state := str(defender.get("state"))

	if defender_state == STATE_EVADE and _evade_is_active(defender):
		if str(defender.get("action")) == DuelActionScript.counter_for(action):
			var evasion := str(defender.get("action"))
			# State first, then the signal: listeners that play the swing must
			# not have it stomped by the recovery pose arriving after them.
			_set_state(attacker_side, STATE_RECOVER, "", _attack_recovery(attacker) * float(timing.get("countered_recovery_multiplier", 2.0)))
			attack_countered.emit(attacker_side, action, evasion)
			return
		kind = HIT_WRONG_EVADE
	elif defender_state == STATE_WINDUP:
		kind = HIT_INTERRUPT
	elif defender_state in [STATE_RECOVER, STATE_STAGGER, STATE_TAUNT, STATE_PISTOL]:
		kind = HIT_RIPOSTE

	var amount := float(damage_rules.get(action, 10.0)) * float(attacker.get("weapon", {}).get("damage_multiplier", 1.0))
	amount *= _hit_multiplier(kind)
	_set_state(attacker_side, STATE_RECOVER, "", _attack_recovery(attacker))
	_apply_damage(defender_side, amount, action, kind, attacker_side)


func _resolve_taunt(side: String) -> void:
	var target_side := _other_side(side)
	var target: Dictionary = fighters[target_side]
	# A taunt only lands on someone with the composure to hear it. Mid-swing,
	# they are not listening.
	if str(target.get("state")) == STATE_READY:
		target["rattle_time"] = float(taunt_rules.get("duration", 4.0))
		taunt_landed.emit(side)
	_set_state(side, STATE_RECOVER, "", float(timing.get("taunt_recovery", 0.6)))


func _resolve_pistol(side: String) -> void:
	var fighter: Dictionary = fighters[side]
	_set_state(side, STATE_RECOVER, "", float(timing.get("pistol_recovery", 0.75)))
	if bool(fighter.get("pistol_spent", false)):
		# Spoiled by a hit taken during the draw: the shot is gone anyway.
		return
	fighter["pistol_spent"] = true
	fighter["pistol_fired"] = true
	pistol_fired.emit(side)
	_apply_damage(_other_side(side), float(damage_rules.get("pistol", 26.0)), DuelActionScript.PISTOL, HIT_PISTOL, side)


func _apply_damage(target_side: String, amount: float, action: String, kind: String, source_side: String) -> void:
	var target: Dictionary = fighters[target_side]
	var source: Dictionary = fighters[source_side]

	if str(target.get("state")) == STATE_PISTOL and not bool(target.get("pistol_spent", false)):
		target["pistol_spent"] = true
		pistol_spoiled.emit(target_side)

	target["vigor"] = maxf(0.0, float(target.get("vigor", 0.0)) - amount)
	target["hits_taken"] = int(target.get("hits_taken", 0)) + 1
	source["hits_landed"] = int(source.get("hits_landed", 0)) + 1
	hit_landed.emit(source_side, action, amount, kind)
	vigor_changed.emit(target_side, get_vigor_fraction(target_side))
	_rally_support(source_side, target_side)

	if float(target["vigor"]) <= 0.0:
		_begin_conclusion(target_side, DuelContextScript.REASON_CAPTAIN_YIELDED)
		return
	_set_state(target_side, STATE_STAGGER, "", float(timing.get("stagger_duration", 0.5)))


# One end for both ways a side can lose: their captain goes down, or the force
# fighting alongside them is wiped out. `outcome` says who won, `reason` how.
func _begin_conclusion(loser_side: String, reason: String) -> void:
	if finish_timer >= 0.0:
		return
	_set_state(loser_side, STATE_YIELD, "", 0.0)
	_set_state(_other_side(loser_side), STATE_READY, "", 0.0)
	pending_outcome = DuelContextScript.OUTCOME_PLAYER_LOSS if loser_side == SIDE_PLAYER else DuelContextScript.OUTCOME_PLAYER_WIN
	pending_reason = reason
	finish_timer = float(timing.get("yield_duration", 1.6))


func _finish(outcome: String) -> void:
	is_running = false
	finish_timer = -1.0
	var player: Dictionary = fighters.get(SIDE_PLAYER, {})
	var opponent: Dictionary = fighters.get(SIDE_OPPONENT, {})
	var winner := ""
	if outcome == DuelContextScript.OUTCOME_PLAYER_WIN:
		winner = SIDE_PLAYER
	elif outcome == DuelContextScript.OUTCOME_PLAYER_LOSS:
		winner = SIDE_OPPONENT
	duel_finished.emit({
		"outcome": outcome,
		"reason": pending_reason if not pending_reason.is_empty() else DuelContextScript.REASON_ABANDONED,
		"winner": winner,
		"player_vigor_fraction": get_vigor_fraction(SIDE_PLAYER),
		"opponent_vigor_fraction": get_vigor_fraction(SIDE_OPPONENT),
		"player_weapon": str(player.get("weapon_id", "")),
		"opponent_weapon": str(opponent.get("weapon_id", "")),
		"hits_landed": int(player.get("hits_landed", 0)),
		"hits_taken": int(player.get("hits_taken", 0)),
		"pistol_fired": {
			SIDE_PLAYER: bool(player.get("pistol_fired", false)),
			SIDE_OPPONENT: bool(opponent.get("pistol_fired", false))
		},
		# Who was left standing on each side, so the caller can turn the melee
		# into whatever casualties mean in its world.
		"support": _support_result(),
		"duration": elapsed,
		"caller_payload": context.get("caller_payload", {})
	})


func _support_result() -> Dictionary:
	if not has_support():
		return {}
	var result := {}
	for side in [SIDE_PLAYER, SIDE_OPPONENT]:
		var side_support: Dictionary = support[side]
		var starting := float(side_support.get("starting_count", 0.0))
		var remaining := float(side_support.get("count", 0.0))
		result[side] = {
			"label": str(side_support.get("label", "")),
			"starting": starting,
			"remaining": remaining,
			"losses": maxf(0.0, starting - remaining)
		}
	return result


func _hit_multiplier(kind: String) -> float:
	match kind:
		HIT_INTERRUPT:
			return float(damage_rules.get("interrupt_multiplier", 1.5))
		HIT_RIPOSTE:
			return float(damage_rules.get("riposte_multiplier", 1.7))
		HIT_WRONG_EVADE:
			return float(damage_rules.get("wrong_evade_multiplier", 1.25))
		_:
			return 1.0


# An evasion has a short commitment delay before it protects, so answering a
# tell far too early misses the strike just as a late answer does.
func _evade_is_active(fighter: Dictionary) -> bool:
	var elapsed_in_state := float(fighter.get("state_duration", 0.0)) - float(fighter.get("state_time", 0.0))
	return elapsed_in_state >= float(timing.get("evade_startup", 0.05))


func _attack_windup(fighter: Dictionary) -> float:
	var base := float(timing.get("attack_windup", 0.58)) * float(fighter.get("weapon", {}).get("windup_multiplier", 1.0))
	if float(fighter.get("rattle_time", 0.0)) > 0.0:
		base *= 1.0 + float(taunt_rules.get("windup_penalty", 0.22))
	return base


func _attack_recovery(fighter: Dictionary) -> float:
	return float(timing.get("attack_recovery", 0.42)) * float(fighter.get("weapon", {}).get("recovery_multiplier", 1.0))


func _other_side(side: String) -> String:
	return SIDE_OPPONENT if side == SIDE_PLAYER else SIDE_PLAYER
