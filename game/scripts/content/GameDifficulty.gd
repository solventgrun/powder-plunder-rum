class_name GameDifficulty
extends RefCounted

# The game-wide difficulty setting, and the one way every system should read it.
#
# The player picks a level once, when creating a new game (user call
# 2026-08-17) — never per encounter. `GameSession.game_difficulty` holds that
# choice for the session; this class turns it into tuning numbers.
#
# Adding a new consumer (naval combat, land battles, overworld spawning) is two
# steps and touches nothing else:
#
#   1. add a `<system>:` section to every level in
#      data/difficulty/difficulty_levels.yaml
#   2. read it where you need it:
#        var tuning := GameDifficulty.section("naval")
#        var multiplier := float(tuning.get("enemy_accuracy_multiplier", 1.0))
#
# Always supply a default when reading a key. A system whose section has not
# been written yet gets an empty dictionary and must still work.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

const DEFAULT_LEVEL := "normal"


# The level chosen for this game. Falls back to `normal` outside a running game
# (tools, probes, headless tests) so nothing has to special-case its absence.
static func current_id() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var session := tree.root.get_node_or_null("GameSession")
		if session:
			var chosen := str(session.get("game_difficulty"))
			if not chosen.is_empty():
				return chosen
	return DEFAULT_LEVEL


static func current_level() -> Dictionary:
	return ContentCatalog.load_difficulty_level(current_id())


static func display_name() -> String:
	return str(current_level().get("name", DEFAULT_LEVEL.capitalize()))


# This system's tuning at the current difficulty.
static func section(system_id: String) -> Dictionary:
	return ContentCatalog.load_difficulty_section(current_id(), system_id)


# One tuning value, with the fallback the caller would use at normal difficulty.
static func value(system_id: String, key: String, default_value: float) -> float:
	var tuning := section(system_id)
	return float(tuning.get(key, default_value))
