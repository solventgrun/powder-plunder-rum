class_name DuelOpponentBrain
extends RefCounted

# The opposing fighter's head. It plays by exactly the same rules as the player
# — it sees a wind-up, it reacts after its reaction time, and it can be wrong.
# All of its character comes from the profile numbers, so a weary merchant
# master and a sharp fleet captain are the same code with different data.

const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")

# Randomisation around the pause so the rhythm never reads as a metronome.
const PAUSE_JITTER_MIN := 0.85
const PAUSE_JITTER_MAX := 1.25
# A punish is a reaction too, not a reflex: even a taken opening waits a beat.
const PUNISH_REACTION_SCALE := 0.7
# A fighter must always get to ATTEMPT an answer to a tell it was shown; how
# good the answer is, is what read_accuracy decides. Without this a slow
# reaction simply exceeded the wind-up it was meant to answer and the opponent
# stood there taking hits — a weary captain stopped defending altogether rather
# than defending badly (playtest 2026-08-17). The margin is how much of the
# wind-up must remain after the answer is chosen.
const ANSWER_MARGIN := 0.08
# Pressing an advantage should still cost some of the normal breathing room.
const PUNISH_PAUSE_SCALE := 0.7

var profile: Dictionary = {}
var difficulty: Dictionary = {}
var rng: RandomNumberGenerator

var _reaction_timer: float = -1.0
var _watching_windup: bool = false
# Breathing room between voluntary attacks. This, not aggression, is what makes
# a duel feel relentless or fair — playtest 2026-08-17 found the opponent
# attacking every ~0.6s plus swing time, which read as unfair rather than hard.
var _attack_pause: float = 0.0
# One decision per opening, taken when it appears rather than re-rolled every
# frame: re-rolling a chance 60 times a second means it always fires.
var _watching_opening: bool = false
var _punish_armed: bool = false
var _punish_timer: float = 0.0


func configure(fighter: Dictionary, shared_rng: RandomNumberGenerator, difficulty_record: Dictionary = {}) -> void:
	profile = fighter.get("data", {})
	difficulty = difficulty_record
	rng = shared_rng if shared_rng else RandomNumberGenerator.new()
	_reaction_timer = -1.0
	_watching_windup = false
	_watching_opening = false
	_punish_armed = false
	_punish_timer = 0.0
	# Do not open the fight with an instant attack.
	_begin_pause()


func advance(delta: float, self_fighter: Dictionary, target: Dictionary, controller: Node) -> void:
	_attack_pause = maxf(0.0, _attack_pause - delta)
	_punish_timer = maxf(0.0, _punish_timer - delta)
	_track_tell(delta, target, controller)
	_track_opening(target, controller)

	if str(self_fighter.get("state")) != controller.STATE_READY:
		return

	if _answer_tell(self_fighter, target, controller):
		return
	if _punish_opening(self_fighter, target, controller):
		return
	_press_attack(self_fighter, target, controller)


# Watch for the moment the target commits to an attack, then start the clock on
# how long this fighter takes to notice it.
func _track_tell(delta: float, target: Dictionary, controller: Node) -> void:
	var target_is_winding_up := str(target.get("state")) == "windup"
	if target_is_winding_up and not _watching_windup:
		_watching_windup = true
		# Clamp the reaction to what this particular wind-up can accommodate, so
		# a fast weapon or a weary captain still produces an attempted answer.
		# Where there is room to spare, reaction time still matters.
		var windup := float(target.get("state_duration", 0.6))
		var latest := windup - float(controller.timing.get("evade_startup", 0.05)) - ANSWER_MARGIN
		_reaction_timer = clampf(float(profile.get("reaction_time", 0.35)), 0.0, maxf(0.05, latest))
	elif not target_is_winding_up:
		_watching_windup = false
		_reaction_timer = -1.0
	if _reaction_timer > 0.0:
		_reaction_timer -= delta


func _answer_tell(self_fighter: Dictionary, target: Dictionary, controller: Node) -> bool:
	if not _watching_windup or _reaction_timer > 0.0:
		return false
	_watching_windup = false

	var incoming := str(target.get("action"))
	# Too late to get an evasion up: better to trade than to flinch into it.
	if float(target.get("state_time", 0.0)) <= float(controller.timing.get("evade_startup", 0.05)):
		return _attack(controller)

	if rng.randf() <= _read_accuracy(self_fighter, controller):
		return controller.submit_opponent_action(DuelActionScript.counter_for(incoming))

	# A misread is either the wrong evasion or a reckless trade.
	if rng.randf() < 0.65:
		var wrong: Array = DuelActionScript.EVASIONS.filter(func(evasion): return evasion != DuelActionScript.counter_for(incoming))
		return controller.submit_opponent_action(str(wrong[rng.randi_range(0, wrong.size() - 1)]))
	return _attack(controller)


# Watch for an opening — the target recovering, staggered, taunting, or drawing
# a pistol — and decide ONCE whether to take it. Deciding per frame meant every
# mistake was punished the instant it happened, which is what made the duel feel
# unfair rather than difficult.
func _track_opening(target: Dictionary, controller: Node) -> void:
	var open := str(target.get("state")) in [controller.STATE_RECOVER, controller.STATE_STAGGER, controller.STATE_TAUNT, controller.STATE_PISTOL]
	if open and not _watching_opening:
		_watching_opening = true
		_punish_armed = rng.randf() <= float(difficulty.get("punish_chance", 0.5))
		# `punish_delay` is the fairness knob. Without it the punish wind-up
		# starts while you are still staggered from the last hit, so you spend
		# most of the tell frozen and have to answer it in whatever is left —
		# which reads as being attacked too rapidly rather than outfought
		# (playtest 2026-08-17). On lower difficulties the delay is long enough
		# that you are back on your feet before the next tell even begins.
		_punish_timer = float(profile.get("reaction_time", 0.35)) * PUNISH_REACTION_SCALE + float(difficulty.get("punish_delay", 0.0))
	elif not open:
		_watching_opening = false
		_punish_armed = false


# The cheapest damage in the fight, and the right moment to spend a shot.
func _punish_opening(_self_fighter: Dictionary, _target: Dictionary, controller: Node) -> bool:
	if not _watching_opening or not _punish_armed or _punish_timer > 0.0:
		return false
	_punish_armed = false
	if controller.can_use_pistol(controller.SIDE_OPPONENT) and rng.randf() <= float(profile.get("pistol_discipline", 0.5)):
		_begin_pause(PUNISH_PAUSE_SCALE)
		return controller.submit_opponent_action(DuelActionScript.PISTOL)
	return _attack(controller, PUNISH_PAUSE_SCALE)


func _press_attack(_self_fighter: Dictionary, target: Dictionary, controller: Node) -> bool:
	if _attack_pause > 0.0:
		return false

	# An undisciplined fighter burns the shot early for the drama of it.
	if controller.can_use_pistol(controller.SIDE_OPPONENT) and rng.randf() <= (1.0 - float(profile.get("pistol_discipline", 0.5))) * 0.25:
		_begin_pause()
		return controller.submit_opponent_action(DuelActionScript.PISTOL)

	# Gloating: only worth it against a composed opponent, and it costs an
	# opening, so keep it rare.
	if str(target.get("state")) == controller.STATE_READY and rng.randf() <= 0.06:
		_begin_pause(0.5)
		return controller.submit_opponent_action(DuelActionScript.TAUNT)

	return _attack(controller, 1.0, rng.randf() <= float(profile.get("feint_chance", 0.2)))


func _attack(controller: Node, pause_scale: float = 1.0, as_feint: bool = false) -> bool:
	_begin_pause(pause_scale)
	return controller.submit_opponent_action(_pick_attack(), as_feint)


# How long this fighter waits before swinging again. Aggression picks a point
# between the difficulty's slow and fast pauses, so "aggressive" means "presses
# more often" rather than "reacts unfairly".
func _begin_pause(scale: float = 1.0) -> void:
	var slow := float(difficulty.get("attack_pause_slow", 2.7))
	var fast := float(difficulty.get("attack_pause_fast", 1.5))
	var base := lerpf(slow, fast, clampf(float(profile.get("aggression", 0.6)), 0.0, 1.0))
	_attack_pause = base * scale * rng.randf_range(PAUSE_JITTER_MIN, PAUSE_JITTER_MAX)


func _read_accuracy(self_fighter: Dictionary, controller: Node) -> float:
	var accuracy := float(profile.get("read_accuracy", 0.55))
	if float(self_fighter.get("rattle_time", 0.0)) > 0.0:
		accuracy -= float(controller.taunt_rules.get("read_penalty", 0.25))
	return clampf(accuracy, 0.0, 1.0)


func _pick_attack() -> String:
	return str(DuelActionScript.ATTACKS[rng.randi_range(0, DuelActionScript.ATTACKS.size() - 1)])
