class_name DuelContext
extends RefCounted

# The payload a caller hands the duel system, and the payload it gets back.
#
# This is the whole reuse contract (docs/design/boarding-duel-brief.md): the
# duel reads nothing but the context, and reports nothing but the result. A
# boarding action, a tavern brawl, and a story duel differ only in the numbers
# and strings a caller puts in here.
#
# Nothing in game/scripts/duel/ may reach outside this dictionary for state.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

# Keys every result carries. The smoke test asserts these so a future change to
# the duel cannot quietly break callers that read the result.
const RESULT_KEYS := [
	"outcome",
	"reason",
	"winner",
	"player_vigor_fraction",
	"opponent_vigor_fraction",
	"player_weapon",
	"opponent_weapon",
	"hits_landed",
	"hits_taken",
	"pistol_fired",
	"support",
	"duration",
	"caller_payload"
]

const OUTCOME_PLAYER_WIN := "player_win"
const OUTCOME_PLAYER_LOSS := "player_loss"
const OUTCOME_ABANDONED := "abandoned"

# `outcome` says who won; `reason` says how. Callers that only care about the
# verdict never have to learn the second one.
const REASON_CAPTAIN_YIELDED := "captain_yielded"
const REASON_SUPPORT_LOST := "support_lost"
const REASON_ABANDONED := "abandoned"

# A supporting force fighting alongside a duellist. Meaning is the caller's:
# boarding passes crew, a tavern brawl could pass shipmates, a land duel a
# squad. `count` is people, `strength` is how well they fight per head.
const DEFAULT_SUPPORT := {
	"label": "",
	"count": 0.0,
	"strength": 1.0
}

const DEFAULT_FIGHTER := {
	"name": "Fighter",
	"subtitle": "",
	"vigor": 100.0,
	"weapon": "longsword",
	"pistol": false,
	"reaction_time": 0.35,
	"read_accuracy": 0.55,
	"aggression": 0.6,
	"feint_chance": 0.2,
	"pistol_discipline": 0.5,
	"coat": "3a2416",
	"accent": "8f1a10",
	"hat": "none"
}


# A fully-formed context with sane defaults. Callers override what they care
# about; anything they leave out still produces a playable fight, which is what
# keeps a new caller cheap to add.
static func create(overrides: Dictionary = {}) -> Dictionary:
	var context := {
		"rules_id": "default",
		"difficulty_id": "normal",
		"arena": "ship_deck",
		"title": "DUEL",
		"subtitle": "",
		"weapon_choices": [],
		"player": {},
		"opponent": {},
		"support": {},
		"caller_payload": {}
	}
	for key in overrides:
		context[key] = overrides[key]
	return normalize(context)


static func normalize(context: Dictionary) -> Dictionary:
	var normalized := context.duplicate(true)
	normalized["rules_id"] = str(normalized.get("rules_id", "default"))
	normalized["difficulty_id"] = str(normalized.get("difficulty_id", "normal"))
	normalized["arena"] = str(normalized.get("arena", "ship_deck"))
	normalized["title"] = str(normalized.get("title", "DUEL"))
	normalized["subtitle"] = str(normalized.get("subtitle", ""))
	if not normalized.get("caller_payload") is Dictionary:
		normalized["caller_payload"] = {}

	var choices: Array = normalized.get("weapon_choices", [])
	if choices.is_empty():
		choices = ContentCatalog.load_duel_weapon_records().map(func(record): return str(record.get("id", "")))
	normalized["weapon_choices"] = choices.filter(func(id): return not str(id).is_empty())

	normalized["player"] = normalize_fighter(normalized.get("player", {}))
	normalized["opponent"] = normalize_fighter(normalized.get("opponent", {}))
	normalized["support"] = normalize_support(normalized.get("support", {}))
	if str(normalized["player"].get("name", "")) == DEFAULT_FIGHTER["name"]:
		normalized["player"]["name"] = "You"
	return normalized


# Supporting forces are optional. An empty dictionary means a straight duel with
# nobody else on the floor, which is exactly what a tavern brawl or a story duel
# should get without asking for it.
static func normalize_support(support: Dictionary) -> Dictionary:
	if support.is_empty():
		return {}
	var normalized := {}
	for side in ["player", "opponent"]:
		if not support.get(side) is Dictionary:
			continue
		var side_support := DEFAULT_SUPPORT.duplicate(true)
		for key in support[side]:
			side_support[key] = support[side][key]
		side_support["count"] = maxf(0.0, float(side_support.get("count", 0.0)))
		side_support["strength"] = maxf(0.01, float(side_support.get("strength", 1.0)))
		normalized[side] = side_support
	# One-sided support would mean an unopposed massacre; treat it as none.
	if normalized.size() < 2:
		return {}
	return normalized


static func normalize_fighter(fighter: Dictionary) -> Dictionary:
	var normalized := DEFAULT_FIGHTER.duplicate(true)
	for key in fighter:
		normalized[key] = fighter[key]
	normalized["vigor"] = maxf(1.0, float(normalized.get("vigor", 100.0)))
	normalized["pistol"] = bool(normalized.get("pistol", false))
	normalized["reaction_time"] = maxf(0.0, float(normalized.get("reaction_time", 0.35)))
	for unit_field in ["read_accuracy", "aggression", "feint_chance", "pistol_discipline"]:
		normalized[unit_field] = clampf(float(normalized.get(unit_field, 0.5)), 0.0, 1.0)
	return normalized


# Build a fighter from a duel profile record. Callers that have their own idea
# of a combatant (a named rival, a story character) can skip this entirely and
# hand over a plain dictionary.
static func fighter_from_profile(profile_id: String, overrides: Dictionary = {}) -> Dictionary:
	var profiles := ContentCatalog.load_duel_profiles()
	var profile: Dictionary = profiles.get(profile_id, {})
	var fighter := {}
	for key in ["name", "vigor", "weapon", "reaction_time", "read_accuracy", "aggression", "feint_chance", "pistol_discipline", "coat", "accent", "hat"]:
		if profile.has(key):
			fighter[key] = profile[key]
	fighter["profile_id"] = str(profile.get("id", profile_id))
	fighter["pistol"] = randf() <= float(profile.get("pistol_chance", 0.0))
	for key in overrides:
		fighter[key] = overrides[key]
	return normalize_fighter(fighter)


# Which archetype defends a given deck. Faction beats ship type, so a pirate
# crew on a captured galleon still fields a pirate captain.
static func captain_profile_id(faction: String, ship_type: String) -> String:
	var best_profile := ""
	var best_score := -1
	for record in ContentCatalog.load_captain_assignment_records():
		var record_faction := str(record.get("faction", "any"))
		var record_ship_type := str(record.get("ship_type", "any"))
		if record_faction != "any" and record_faction != faction:
			continue
		if record_ship_type != "any" and record_ship_type != ship_type:
			continue
		var score := 0
		if record_faction != "any":
			score += 2
		if record_ship_type != "any":
			score += 1
		if score > best_score:
			best_score = score
			best_profile = str(record.get("profile", ""))
	return best_profile
