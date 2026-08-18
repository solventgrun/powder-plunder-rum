class_name DuelAction
extends RefCounted

# The duel's vocabulary, shared by the rules engine, the arena visuals, and the
# HUD legend so the three can never drift apart.
#
# Layout (user call 2026-08-17): attacks in the left column by height, evasions
# in the middle placed by which way the body moves, utility on the right.
#
#   7 CHOP     8 JUMP     9 PISTOL
#   4 THRUST   5 PARRY    6 TAUNT
#   1 SLASH    2 DUCK     3  --
#
# The evasion column is keyed to YOUR BODY — jump is up top because you go up,
# duck is at the bottom because you go down. Keying it to the incoming blade's
# height instead (press high to answer a high cut) was built and played, and the
# user reversed it: it felt worse in the hand. Both have been tried; leave it.
#
# Slot 3 is deliberately unbound; it is reserved for a future weapon-specific
# move (dagger, kick) so the pad has somewhere to grow.

const CHOP := "chop"
const THRUST := "thrust"
const SLASH := "slash"
const JUMP := "jump"
const PARRY := "parry"
const DUCK := "duck"
const TAUNT := "taunt"
const PISTOL := "pistol"

const ATTACKS := [CHOP, THRUST, SLASH]
const EVASIONS := [JUMP, PARRY, DUCK]

# Each attack has exactly one answer. Chop comes at the head, so you duck under
# it; slash comes at the legs, so you jump over it; a thrust is turned aside.
const COUNTERS := {
	CHOP: DUCK,
	THRUST: PARRY,
	SLASH: JUMP
}

# Where an attack is aimed, used for the wind-up tell and the strike pose.
const HEIGHTS := {
	CHOP: "high",
	THRUST: "mid",
	SLASH: "low"
}

const LABELS := {
	CHOP: "CHOP",
	THRUST: "THRUST",
	SLASH: "SLASH",
	JUMP: "JUMP",
	PARRY: "PARRY",
	DUCK: "DUCK",
	TAUNT: "TAUNT",
	PISTOL: "PISTOL"
}

# Numpad slot -> action. Empty slots keep their place on the legend so the pad
# always reads as a 3x3 grid.
const PAD_SLOTS := [
	[7, CHOP], [8, JUMP], [9, PISTOL],
	[4, THRUST], [5, PARRY], [6, TAUNT],
	[1, SLASH], [2, DUCK], [3, ""]
]

const INPUT_ACTIONS := {
	CHOP: "duel_chop",
	THRUST: "duel_thrust",
	SLASH: "duel_slash",
	JUMP: "duel_jump",
	PARRY: "duel_parry",
	DUCK: "duel_duck",
	TAUNT: "duel_taunt",
	PISTOL: "duel_pistol"
}


static func is_attack(action: String) -> bool:
	return ATTACKS.has(action)


static func is_evasion(action: String) -> bool:
	return EVASIONS.has(action)


static func counter_for(attack: String) -> String:
	return str(COUNTERS.get(attack, ""))


static func attack_answered_by(evasion: String) -> String:
	for attack in COUNTERS:
		if COUNTERS[attack] == evasion:
			return attack
	return ""


static func height_of(attack: String) -> String:
	return str(HEIGHTS.get(attack, "mid"))


static func label_for(action: String) -> String:
	return str(LABELS.get(action, ""))
