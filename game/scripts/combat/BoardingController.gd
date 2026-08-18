class_name BoardingController
extends Node

# The naval half of CROSS SWORDS, and the only place that knows about both
# ships and duels. It decides when grapples can be thrown, translates the
# enemy's battered state into a weaker captain, and turns the duel's verdict
# back into ship consequences.
#
# Everything ship-shaped stops here: game/scripts/duel/ stays context-free
# (docs/design/boarding-duel-brief.md).

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const DuelContextScript := preload("res://game/scripts/duel/DuelContext.gd")
const DuelArenaScript := preload("res://game/scripts/duel/DuelArena.gd")
const GameDifficultyScript := preload("res://game/scripts/content/GameDifficulty.gd")
const ShipGeometryScript := preload("res://game/scripts/combat/ShipGeometry.gd")

const BLOCK_NONE := ""
const BLOCK_DISTANCE := "CLOSE ALONGSIDE TO BOARD"
const BLOCK_SPEED := "TOO FAST - MATCH HER SPEED"
const BLOCK_CREW := "TOO FEW HANDS TO BOARD"

signal boarding_started
signal boarding_resolved(outcome: String, result: Dictionary)

@export var player_ship_path: NodePath
@export var target_ship_path: NodePath
# The battle's own HUD, hidden while the duel is on screen. The duel cannot do
# this itself without knowing what a caller's HUD looks like, so the caller
# owns it.
@export var battle_hud_path: NodePath
@export var enabled: bool = true
# Editor/test toggle in the same spirit as the target ship's ai_enabled: lets a
# battle be exercised without an enemy boarding attempt firing off mid-test.
@export var enemy_boarding_enabled: bool = true

var rules: Dictionary = {}
var player_ship: Node3D
var target_ship: Node3D
var is_available: bool = false
var is_boarding: bool = false
var block_reason: String = BLOCK_DISTANCE
var last_outcome: String = ""
# Who threw the grapples. The duel is the same fight either way; what changes is
# whose crew is defending their own deck, and how it is framed.
var initiator: String = "player"
# The enemy has decided to come for you. Set once per opportunity, not re-rolled
# every frame, and visible to the player before the grapples land.
var enemy_intends_boarding: bool = false

var _grapple_timer: float = -1.0
var _arena: Node3D
var _enemy_decision_made: bool = false


func _ready() -> void:
	rules = ContentCatalog.load_boarding_rules()
	player_ship = get_node_or_null(player_ship_path) as Node3D
	target_ship = get_node_or_null(target_ship_path) as Node3D


func _process(delta: float) -> void:
	if _grapple_timer >= 0.0:
		_grapple_timer -= delta
		if _grapple_timer <= 0.0:
			_grapple_timer = -1.0
			_launch_duel()
		return
	if not enabled or is_boarding:
		return
	_update_availability()
	if is_available and Input.is_action_just_pressed("board"):
		begin_boarding("player")
		return
	_update_enemy_intent()


# Boarding is offered whenever you are alongside (user call 2026-08-17). How
# softened they are changes the captain you meet, not whether you may try.
func _update_availability() -> void:
	is_available = false
	block_reason = BLOCK_DISTANCE
	if player_ship == null or target_ship == null:
		return
	if _is_out_of_action(player_ship) or _is_out_of_action(target_ship):
		return

	if get_hull_gap() > get_alongside_gap():
		block_reason = BLOCK_DISTANCE
		return
	if get_closing_speed() > float(rules.get("max_closing_speed", 5.0)):
		block_reason = BLOCK_SPEED
		return
	if float(player_ship.get("crew")) < float(rules.get("minimum_crew", 6)):
		block_reason = BLOCK_CREW
		return

	block_reason = BLOCK_NONE
	is_available = true


func get_distance() -> float:
	if player_ship == null or target_ship == null:
		return INF
	return player_ship.global_position.distance_to(target_ship.global_position)


# Water between the hulls, which is what a grapple actually has to cross.
func get_hull_gap() -> float:
	return ShipGeometryScript.hull_gap(player_ship, target_ship)


func get_alongside_gap() -> float:
	return float(rules.get("alongside_gap", 1.6))


func get_closing_speed() -> float:
	var player_velocity: Vector3 = player_ship.get("velocity") if player_ship and player_ship.get("velocity") != null else Vector3.ZERO
	var target_velocity: Vector3 = target_ship.get("velocity") if target_ship and target_ship.get("velocity") != null else Vector3.ZERO
	return (player_velocity - target_velocity).length()


# The enemy can come for you too (user call 2026-08-17). They decide once per
# opportunity — deciding every frame would mean any chance above zero fires
# immediately — then bear down on you, which is the warning you get.
func _update_enemy_intent() -> void:
	if not enemy_boarding_enabled or target_ship == null or player_ship == null:
		return
	if _is_out_of_action(player_ship) or _is_out_of_action(target_ship):
		_set_enemy_intent(false)
		return

	var tuning := GameDifficultyScript.section("boarding")
	var in_reach := get_hull_gap() <= get_alongside_gap() * float(rules.get("enemy_interest_multiplier", 2.6))
	if not in_reach:
		# Out of the running: forget this opportunity so a fresh one can happen.
		_enemy_decision_made = false
		_set_enemy_intent(false)
		return

	if not _enemy_decision_made:
		_enemy_decision_made = true
		_set_enemy_intent(_enemy_would_board(tuning))

	if not enemy_intends_boarding:
		return
	# They have committed; grapple as soon as they are actually alongside.
	if get_hull_gap() <= get_alongside_gap() and get_closing_speed() <= float(rules.get("max_closing_speed", 5.0)):
		begin_boarding("enemy")


func _enemy_would_board(tuning: Dictionary) -> bool:
	var their_crew := float(target_ship.get("crew"))
	var our_crew := float(player_ship.get("crew"))
	if their_crew < float(rules.get("minimum_crew", 6)):
		return false
	# They want the odds before they try it — how much so is a difficulty knob.
	var required := float(tuning.get("enemy_crew_advantage", 1.25))
	if our_crew > 0.0 and their_crew / our_crew < required:
		return false
	return randf() <= float(tuning.get("enemy_boarding_chance", 0.4))


func _set_enemy_intent(intends: bool) -> void:
	if enemy_intends_boarding == intends:
		return
	enemy_intends_boarding = intends
	if target_ship and target_ship.get("wants_to_board") != null:
		target_ship.set("wants_to_board", intends)
	if intends:
		print("%s bears down to board!" % _target_name())


func begin_boarding(by: String = "player") -> void:
	if is_boarding:
		return
	initiator = by
	is_boarding = true
	is_available = false
	_set_enemy_intent(false)
	_grapple_timer = float(rules.get("grapple_time", 1.0))
	if by == "player":
		print("Grapples away! Boarding %s." % _target_name())
	else:
		print("%s throws grapples aboard!" % _target_name())
	boarding_started.emit()


# How much fight the enemy crew has left, 0..1. This is the whole reward for
# softening them up with grape shot before you go over the rail.
func get_enemy_condition() -> float:
	if target_ship == null:
		return 1.0
	var condition: Dictionary = rules.get("condition", {})
	var crew_weight := float(condition.get("crew_weight", 0.65))
	var morale_weight := float(condition.get("morale_weight", 0.35))
	var total := crew_weight + morale_weight
	if total <= 0.0:
		return 1.0
	var crew := float(target_ship.call("get_crew_fraction"))
	var morale := float(target_ship.call("get_morale_fraction"))
	return clampf((crew * crew_weight + morale * morale_weight) / total, 0.0, 1.0)


func build_duel_context() -> Dictionary:
	var condition := get_enemy_condition()
	var scaling: Dictionary = rules.get("opponent_scaling", {})
	var weariness := 1.0 - condition

	var faction := str(_loadout_of(target_ship).get("faction", ""))
	var ship_type := str(target_ship.get("ship_type_id")) if target_ship else ""
	var profile_id := DuelContextScript.captain_profile_id(faction, ship_type)
	var opponent := DuelContextScript.fighter_from_profile(profile_id, {"subtitle": _target_name()})

	opponent["vigor"] = float(opponent.get("vigor", 100.0)) * lerpf(
		float(scaling.get("vigor_weak_multiplier", 0.55)),
		float(scaling.get("vigor_fresh_multiplier", 1.15)),
		condition)
	opponent["reaction_time"] = float(opponent.get("reaction_time", 0.35)) + float(scaling.get("reaction_penalty", 0.22)) * weariness
	# Floors keep a battered captain fighting badly rather than not at all.
	opponent["read_accuracy"] = maxf(
		float(opponent.get("read_accuracy", 0.55)) - float(scaling.get("read_penalty", 0.3)) * weariness,
		float(scaling.get("minimum_read_accuracy", 0.2)))
	opponent["aggression"] = maxf(
		float(opponent.get("aggression", 0.6)) - float(scaling.get("aggression_penalty", 0.35)) * weariness,
		float(scaling.get("minimum_aggression", 0.3)))

	var player_faction := str(_loadout_of(player_ship).get("faction", "pirates"))
	var factions := ContentCatalog.load_factions()
	var liveries := ContentCatalog.load_faction_liveries()
	var player_livery: Dictionary = liveries.get(player_faction, {})
	var opponent_livery: Dictionary = liveries.get(faction, {})
	# Dress the captains in their fleet's colours, so the livery work pays off
	# on the deck as well as at sea.
	if not opponent_livery.is_empty():
		opponent["coat"] = str(opponent_livery.get("paint", opponent.get("coat")))
		opponent["accent"] = str(opponent_livery.get("trim", opponent.get("accent")))

	var player_fighter := {
		"name": "You",
		"subtitle": str(factions.get(player_faction, {}).get("name", "")),
		"pistol": bool(rules.get("player_pistol", true)),
		"coat": str(player_livery.get("paint", "3a2416")),
		"accent": str(player_livery.get("streamer", "8f1a10")),
		"hat": "bandana"
	}

	# The crews fight too, and either can decide the boarding by wiping the other
	# out before the captains finish. The duel knows none of this — it is handed
	# two anonymous "supporting forces" and reports what became of them.
	#
	# Whoever is defending their own deck brings their whole crew and fights a
	# little better for it; the boarders bring a party and leave hands behind.
	var factions_catalog := factions
	var party_fraction := float(rules.get("boarding_party_fraction", 0.75))
	var defender_strength := float(rules.get("defender_strength", 1.1)) * float(GameDifficultyScript.value("boarding", "defender_strength_multiplier", 1.0))
	var defending := initiator == "enemy"

	var player_crew := float(player_ship.get("crew")) if player_ship else 0.0
	var enemy_crew := float(target_ship.get("crew")) if target_ship else 0.0
	var player_count := player_crew if defending else player_crew * party_fraction
	var enemy_count := enemy_crew * party_fraction if defending else enemy_crew

	# Men with muskets and cutlasses beat men with belaying pins. Small arms in
	# the hold arm as much of your party as they go round, so a crate is worth
	# carrying into a fight you mean to win on the deck.
	var player_strength := (defender_strength if defending else 1.0) + _small_arms_bonus(player_ship, player_count)
	var enemy_strength := (1.0 if defending else defender_strength) + _small_arms_bonus(target_ship, enemy_count)

	return DuelContextScript.create({
		"title": "REPEL BOARDERS" if defending else "BOARDING ACTION",
		"subtitle": _target_name(),
		"difficulty_id": GameDifficultyScript.current_id(),
		"player": player_fighter,
		"opponent": opponent,
		"support": {
			"player": {
				"label": str(factions_catalog.get(player_faction, {}).get("name", "Boarders")),
				"count": player_count,
				"strength": player_strength
			},
			"opponent": {
				"label": str(factions_catalog.get(faction, {}).get("name", "Defenders")),
				"count": enemy_count,
				"strength": enemy_strength
			}
		},
		"caller_payload": {
			"kind": "naval_boarding",
			"initiator": initiator,
			"target_name": _target_name(),
			"enemy_condition": condition
		}
	})


func _launch_duel() -> void:
	_set_battle_hud_visible(false)
	_arena = DuelArenaScript.new()
	_arena.name = "SwordDuel"
	add_child(_arena)
	_arena.duel_finished.connect(_on_duel_finished)
	_arena.begin(build_duel_context())


func _on_duel_finished(result: Dictionary) -> void:
	_arena = null
	is_boarding = false
	_set_battle_hud_visible(true)
	var outcome := str(result.get("outcome", ""))

	# Casualties are whatever the melee actually cost, not a flat percentage:
	# a boarding you barely survive now shows in your crew afterwards.
	var support: Dictionary = result.get("support", {})
	_apply_crew_loss(player_ship, float(support.get("player", {}).get("losses", 0.0)))
	_apply_crew_loss(target_ship, float(support.get("opponent", {}).get("losses", 0.0)))

	if outcome == DuelContextScript.OUTCOME_PLAYER_WIN:
		_strike_colors(target_ship)
		last_outcome = "enemy_captured"
	elif outcome == DuelContextScript.OUTCOME_PLAYER_LOSS:
		# User call 2026-08-17: losing the boarding IS losing the battle —
		# whether the captain was cut down or the boarding party was wiped out.
		_strike_colors(player_ship)
		last_outcome = "player_defeated"
	else:
		last_outcome = "broken_off"

	print("Boarding resolved: %s (%s)" % [last_outcome, str(result.get("reason", ""))])
	boarding_resolved.emit(last_outcome, result)


# How much better an armed party fights, scaled by the share of it you could
# equip. One crate among a galleon's crew is nearly nothing; a full armoury is
# the cap set in data/cargo/cargo_types.yaml.
func _small_arms_bonus(ship: Node, party_size: float) -> float:
	if ship == null or party_size <= 0.0:
		return 0.0
	var loadout: Dictionary = _loadout_of(ship)
	var units := int(loadout.get("cargo", {}).get("small_arms", 0))
	if units <= 0:
		return 0.0
	var cargo: Dictionary = ContentCatalog.load_cargo_types().get("small_arms", {})
	var effect: Dictionary = cargo.get("effect", {})
	var armed := units * float(effect.get("crew_armed_per_unit", 0.0))
	return float(effect.get("fully_armed_strength_bonus", 0.0)) * clampf(armed / party_size, 0.0, 1.0)


func _apply_crew_loss(ship: Node, casualties: float) -> void:
	if ship == null or casualties <= 0.0:
		return
	ship.call("apply_crew_damage", casualties)


func _strike_colors(ship: Node) -> void:
	if ship == null:
		return
	var combat := ship.get_node_or_null("ShipCombatComponent")
	if combat and combat.has_method("strike_colors"):
		combat.call("strike_colors")
	# The AI has no reason to keep fighting a battle it has just lost.
	for flag in ["ai_enabled", "firing_enabled", "movement_enabled"]:
		if ship.get(flag) != null:
			ship.set(flag, false)


func _set_battle_hud_visible(visible_state: bool) -> void:
	if battle_hud_path.is_empty():
		return
	var hud := get_node_or_null(battle_hud_path)
	if hud and hud.get("visible") != null:
		hud.set("visible", visible_state)


func _is_out_of_action(ship: Node) -> bool:
	return bool(ship.get("is_sunk")) or bool(ship.get("has_struck_colors"))


func _target_name() -> String:
	if target_ship == null:
		return "Enemy Ship"
	var loadout := _loadout_of(target_ship)
	if not str(loadout.get("name", "")).is_empty():
		return str(loadout.get("name"))
	return str(target_ship.get("ship_display_name"))


func _loadout_of(ship: Node) -> Dictionary:
	if ship == null:
		return {}
	var loadout = ship.get("ship_loadout")
	return loadout if loadout is Dictionary else {}
