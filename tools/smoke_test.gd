extends SceneTree

const NAVAL_BATTLE_SCENE_PATH := "res://game/scenes/NavalBattle.tscn"
const OVERWORLD_SCENE_PATH := "res://game/scenes/Overworld.tscn"
const SWORD_DUEL_SCENE_PATH := "res://game/scenes/SwordDuel.tscn"
const MAIN_MENU_SCENE_PATH := "res://game/scenes/MainMenu.tscn"
const PRACTICE_SETUP_SCENE_PATH := "res://game/scenes/PracticeSetup.tscn"
const AFTER_ACTION_SCENE_PATH := "res://game/scenes/AfterAction.tscn"
const FleetScript := preload("res://game/scripts/session/Fleet.gd")
const ShipCombatComponentScript := preload("res://game/scripts/combat/ShipCombatComponent.gd")
const SAILING_MODEL_PATH := "res://game/scripts/SailingModel.gd"
const DuelContextScript := preload("res://game/scripts/duel/DuelContext.gd")
const DuelControllerScript := preload("res://game/scripts/duel/DuelController.gd")
const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")
const GameDifficultyScript := preload("res://game/scripts/content/GameDifficulty.gd")
const ShipGeometryScript := preload("res://game/scripts/combat/ShipGeometry.gd")
const DUEL_STEP := 1.0 / 60.0
const ContentValidator := preload("res://game/scripts/content/ContentValidator.gd")
const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const WindSystem := preload("res://game/scripts/WindSystem.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	_test_content_validation(failures)
	_test_ship_stats(failures)
	_test_overworld_ship_records(failures)
	_test_sailing_model(failures)
	_test_wind_strength_factor(failures)
	_test_cargo_content(failures)
	_test_fleet_state(failures)
	await _test_battle_report(failures)
	await _test_after_action_prize(failures)
	_test_morale_consequences(failures)
	await _test_main_menu_offers_both_modes(failures)
	await _test_practice_setup_validates_loadouts(failures)
	await _test_practice_battle_uses_both_loadouts(failures)
	await _test_overworld_consorts(failures)
	await _test_overworld_scene_loads(failures)
	await _test_naval_battle_uses_overworld_encounter(failures)
	await _test_main_scene_moves_ship(failures)
	await _test_broadside_side_behavior(failures)
	await _test_asymmetric_ship_loadout(failures)
	await _test_ammo_switch_cooldown(failures)
	await _test_projectile_range_splash(failures)
	await _test_projectile_range_independent_of_ship_scale(failures)
	await _test_cannon_hits_target(failures)
	await _test_armament_damage(failures)
	await _test_sail_crew_morale_damage(failures)
	await _test_mast_break_and_crew_limits(failures)
	await _test_target_ai_test_toggles(failures)
	await _test_enemy_can_fire_at_player(failures)
	await _test_fire_status_effects(failures)
	await _test_magazine_explosion(failures)
	await _test_target_sinks_at_zero_hull(failures)
	_test_duel_content(failures)
	_test_game_difficulty(failures)
	_test_duel_pacing_is_readable(failures)
	_test_duel_opponent_always_answers(failures)
	_test_duel_exchange_rules(failures)
	_test_duel_pistol_rules(failures)
	_test_duel_support_melee(failures)
	_test_duel_result_contract(failures)
	await _test_duel_arena_overlay(failures)
	await _test_ship_collisions(failures)
	await _test_boarding_availability(failures)
	await _test_enemy_initiated_boarding(failures)
	await _test_boarding_consequences(failures)

	if failures.is_empty():
		print("Smoke test passed: consorts, cargo content, fleet state, battle report, after-action prize, morale consequences, main menu, practice loadout validation, practice battle handoff, overworld scene, overworld encounters, encounter battle handoff, sailing, content, ship stats/mods, target ship config, ship loadouts, broadside behavior, enemy fire, ammo cooldown, projectile splash, impact flash, armament damage, sail/crew/morale damage, mast break, crew firing limits, target AI test toggles, burning, self-ignition, magazine explosion, sinking, target damage, duel content, game difficulty, duel pacing, duel defence, duel exchanges, duel pistol, crew melee, duel result contract, duel arena overlay, ship collisions, boarding availability, enemy boarding, and boarding consequences.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_content_validation(failures: Array[String]) -> void:
	var result: Dictionary = ContentValidator.validate_all()
	var warnings: Array[String] = result.get("warnings", [])
	var errors: Array[String] = result.get("errors", [])

	for warning in warnings:
		push_warning(warning)
	for error in errors:
		failures.append(error)


func _test_sailing_model(failures: Array[String]) -> void:
	var model_script := load(SAILING_MODEL_PATH)
	if model_script == null:
		failures.append("Could not load SailingModel script.")
		return

	var model: Node = model_script.new()
	var forward := Vector3.FORWARD
	var tailwind: float = model.calculate_sail_efficiency(forward, Vector3.FORWARD, 1.0)
	var crosswind: float = model.calculate_sail_efficiency(forward, Vector3.RIGHT, 1.0)
	var headwind: float = model.calculate_sail_efficiency(forward, Vector3.BACK, 1.0)

	if not tailwind > headwind:
		failures.append("Tailwind should be more effective than headwind.")
	if not crosswind > headwind:
		failures.append("Crosswind should be more effective than headwind.")
	if not model.calculate_turn_degrees(5.0, 1.0, 0.25) < 0.0:
		failures.append("Starboard steering should produce a right turn.")
	model.free()


func _test_wind_strength_factor(failures: Array[String]) -> void:
	var wind := WindSystem.new()
	var conditions := ContentCatalog.load_environment_condition("default_battle")
	if conditions.is_empty():
		failures.append("Environment conditions should include default_battle.")
	else:
		var wind_record: Dictionary = conditions.get("wind", {})
		if float(wind_record.get("strength", -1.0)) < 0.0:
			failures.append("Default battle conditions should define non-negative wind strength.")
	wind.call("_apply_environment_conditions", conditions)
	if not is_equal_approx(wind.wind_strength, float(conditions.get("wind", {}).get("strength", wind.wind_strength))):
		failures.append("WindSystem should load wind strength from environment conditions.")
	wind.reference_wind_strength = 10.0
	wind.wind_strength = 5.0
	if not is_equal_approx(wind.get_wind_speed_factor(), 0.5):
		failures.append("Wind strength 5 against reference 10 should produce 0.5x speed factor.")
	wind.wind_strength = 20.0
	if not is_equal_approx(wind.get_wind_speed_factor(), 1.6):
		failures.append("Wind speed factor should clamp at the strong-wind cap.")
	wind.free()


func _test_ship_stats(failures: Array[String]) -> void:
	var ship_types := ContentCatalog.load_ship_types()
	var modifications := ContentCatalog.load_ship_modifications()
	var player_record := ContentCatalog.load_player_ship_record()
	var player_stats: Resource = ContentCatalog.build_ship_stats(player_record, ship_types, modifications)
	var base_record := player_record.duplicate(true)
	base_record["modifications"] = []
	var base_stats: Resource = ContentCatalog.build_ship_stats(base_record, ship_types, modifications)
	var player_ship_type_id := str(player_record.get("ship_type", ""))
	var player_ship_type: Dictionary = ship_types.get(player_ship_type_id, {})
	if player_stats.get("ship_type_id") != player_ship_type_id:
		failures.append("Player ship stats should match player_ship.yaml ship_type.")
	for modification_id in player_record.get("modifications", []):
		if not player_stats.get("modification_ids").has(str(modification_id)):
			failures.append("Player ship stats should include configured modification '%s'." % str(modification_id))
	if player_stats.get("modification_ids").has("copper_bottom"):
		if not float(player_stats.get("max_speed")) > float(base_stats.get("max_speed")):
			failures.append("Copper bottom should increase effective max speed above the same loaded ship without mods.")
	if not player_stats.get("modification_ids").has("reinforced_hull"):
		if not is_equal_approx(float(player_stats.get("max_hull")), float(base_stats.get("max_hull"))):
			failures.append("Player hull should match same loaded ship hull when reinforced_hull is not installed.")

	var reinforced_record := player_record.duplicate(true)
	reinforced_record["modifications"] = ["reinforced_hull"]
	var reinforced_stats: Resource = ContentCatalog.build_ship_stats(reinforced_record, ship_types, modifications)
	if not float(reinforced_stats.get("max_hull")) > float(base_stats.get("max_hull")):
		failures.append("Reinforced hull should increase effective max hull.")
	if not float(reinforced_stats.get("max_speed")) < float(base_stats.get("max_speed")):
		failures.append("Reinforced hull should reduce effective max speed.")

	var target_record := ContentCatalog.load_target_ship_record()
	var target_stats: Resource = ContentCatalog.load_target_ship_stats()
	var target_ship_type_id := str(target_record.get("ship_type", ""))
	if target_stats.get("ship_type_id") != target_ship_type_id:
		failures.append("Target ship stats should load from target_ship.yaml.")
	if player_record.has("crew") and not is_equal_approx(float(player_stats.get("starting_crew")), float(player_record.get("crew"))):
		failures.append("Player starting crew should load from player_ship.yaml crew.")
	if target_record.has("crew") and not is_equal_approx(float(target_stats.get("starting_crew")), float(target_record.get("crew"))):
		failures.append("Target starting crew should load from target_ship.yaml crew.")
	for modification_id in target_record.get("modifications", []):
		if not target_stats.get("modification_ids").has(str(modification_id)):
			failures.append("Target ship stats should include configured modification '%s'." % str(modification_id))

	var sloop: Dictionary = ship_types.get("sloop", {})
	var galleon: Dictionary = ship_types.get("galleon", {})
	var sloop_sailing: Dictionary = sloop.get("sailing", {})
	var sloop_combat: Dictionary = sloop.get("combat", {})
	var galleon_sailing: Dictionary = galleon.get("sailing", {})
	var galleon_combat: Dictionary = galleon.get("combat", {})
	if not float(sloop_sailing.get("max_speed", 0.0)) > float(galleon_sailing.get("max_speed", 999.0)):
		failures.append("Sloops should be faster than galleons.")
	if not float(sloop_sailing.get("turn_rate", 0.0)) > float(galleon_sailing.get("turn_rate", 999.0)):
		failures.append("Sloops should turn better than galleons.")
	var brig: Dictionary = ship_types.get("brig", {})
	var brig_sailing: Dictionary = brig.get("sailing", {})
	if not float(sloop_sailing.get("acceleration", 0.0)) > float(brig_sailing.get("acceleration", 999.0)):
		failures.append("Sloops should accelerate faster than brigs.")
	if not float(sloop_sailing.get("deceleration", 0.0)) > float(brig_sailing.get("deceleration", 999.0)):
		failures.append("Sloops should shed speed faster than brigs.")
	if not float(sloop_sailing.get("turn_rate", 0.0)) > float(brig_sailing.get("turn_rate", 999.0)) * 2.0:
		failures.append("Sloop turn rate should be more than double brig turn rate for a clear nimble feel.")
	if not float(sloop_sailing.get("minimum_turn_rate", 0.0)) > float(brig_sailing.get("minimum_turn_rate", 999.0)):
		failures.append("Sloops should retain better low-speed turning than brigs.")
	if not float(sloop_sailing.get("sail_trim_speed", 0.0)) > float(brig_sailing.get("sail_trim_speed", 999.0)):
		failures.append("Sloops should trim sails faster than brigs.")
	if not float(galleon_combat.get("max_hull", 0.0)) > float(sloop_combat.get("max_hull", 999.0)):
		failures.append("Galleons should have more hull than sloops.")

	var light_record := {
		"ship_type": "sloop",
		"cargo_weight": 0.0,
		"modifications": [],
		"broadsides": {
			"port": {"cannons": ["light_4_pounder"]},
			"starboard": {"cannons": ["light_4_pounder"]}
		}
	}
	var heavy_record := light_record.duplicate(true)
	heavy_record["cargo_weight"] = 24.0
	var overloaded_record := light_record.duplicate(true)
	overloaded_record["cargo_weight"] = 28.0
	var light_stats: Resource = ContentCatalog.build_ship_stats(light_record, ship_types, modifications)
	var heavy_stats: Resource = ContentCatalog.build_ship_stats(heavy_record, ship_types, modifications)
	var overloaded_stats: Resource = ContentCatalog.build_ship_stats(overloaded_record, ship_types, modifications)
	if not float(light_stats.get("load_speed_multiplier")) > 1.0:
		failures.append("Ships at 60% load or less should receive a small speed boost.")
	if not float(heavy_stats.get("load_speed_multiplier")) < 1.0:
		failures.append("Ships around 80% load should receive a speed penalty.")
	if not float(overloaded_stats.get("load_speed_multiplier")) < float(heavy_stats.get("load_speed_multiplier")):
		failures.append("Ships around 90% load should be significantly slower than heavy ships.")


func _test_overworld_ship_records(failures: Array[String]) -> void:
	var records := ContentCatalog.load_overworld_ship_records()
	if records.size() < 2:
		failures.append("Milestone 3 overworld should include multiple test NPC ships.")
	for record in records:
		if not record.has("route") or not record.route is Array or record.route.size() < 2:
			failures.append("Overworld ship '%s' should define a looping route with at least two waypoints." % str(record.get("id", "")))
		if not record.get("broadsides", {}) is Dictionary:
			failures.append("Overworld ship '%s' should carry battle-ready broadside data." % str(record.get("id", "")))


func _test_overworld_scene_loads(failures: Array[String]) -> void:
	var packed := load(OVERWORLD_SCENE_PATH)
	if packed == null:
		failures.append("Could not load overworld scene.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate overworld scene.")
		return

	root.add_child(scene)
	_disable_battle_auto_return(scene)
	await process_frame
	await physics_frame

	if scene.get_node_or_null("JamaicaIsland") == null:
		failures.append("Overworld should contain a JamaicaIsland landmass.")
	if scene.get_node_or_null("JamaicaIsland/LandCollision") == null:
		failures.append("JamaicaIsland should create a land collision shape.")
	if scene.get_node_or_null("PortRoyal") == null:
		failures.append("Overworld should include a Port Royal marker.")
	if scene.get_node_or_null("PlayerShip") == null:
		failures.append("Overworld should include a player ship.")
	else:
		var player := scene.get_node_or_null("PlayerShip") as Node3D
		var player_stats := ContentCatalog.load_player_ship_stats()
		if player.scale.x <= float(player_stats.get("visual_scale")):
			failures.append("Overworld player ship should be scaled up for map readability.")
		if player.get_node_or_null("VisualRoot/ShipVisualBuilder/GeneratedVisuals") == null:
			failures.append("Overworld player ship should use generated ship-type visuals.")
	if scene.get_node_or_null("Debug/Compass") == null:
		failures.append("Overworld should include a compass and wind indicator.")
	if scene.has_method("_get_intercept_range") and scene.get_node_or_null("PlayerShip"):
		var player_ship := scene.get_node_or_null("PlayerShip") as Node3D
		var sample_range: float = scene.call("_get_intercept_range", player_ship, player_ship)
		if sample_range <= float(scene.get("intercept_distance")):
			failures.append("Overworld intercept range should account for visible ship scale, not just center distance.")

	var npc_count := 0
	for child in scene.get_children():
		if child.has_method("configure") and child.get("encounter_record") is Dictionary:
			npc_count += 1
	if npc_count < 2:
		failures.append("Overworld should spawn multiple NPC ships from encounter records.")
	for child in scene.get_children():
		if child.has_method("configure") and child.get("encounter_record") is Dictionary:
			if child.get_node_or_null("VisualRoot/ShipVisualBuilder/GeneratedVisuals") == null:
				failures.append("Overworld NPC '%s' should use generated ship-type visuals." % child.name)

	_free_scene(scene)


func _test_overworld_consorts(failures: Array[String]) -> void:
	var session := root.get_node_or_null("GameSession")
	if session == null:
		failures.append("Consort test could not find GameSession autoload.")
		return

	var galleon := _find_encounter("spanish_treasure_galleon")
	var fleet: Array[Dictionary] = FleetScript.starting_fleet()
	var prize: Dictionary = galleon.duplicate(true)
	prize["faction"] = "pirates"
	prize.erase("route")
	fleet.append(FleetScript.make_ship(prize, "Prize", "prize_1"))
	session.set("fleet", fleet)
	session.set("flagship_index", 0)
	session.set("practice_mode", false)

	var packed := load(OVERWORLD_SCENE_PATH)
	var scene: Node = packed.instantiate() if packed else null
	if scene == null:
		failures.append("Could not instantiate the overworld for the consort test.")
		return
	root.add_child(scene)
	await process_frame
	await physics_frame

	var consorts: Array = scene.get("consorts")
	var player := scene.get("player") as Node3D
	if consorts.size() != 1:
		failures.append("A kept prize should sail as one consort, got %d." % consorts.size())
	else:
		var consort := consorts[0] as CharacterBody3D
		# She must not be an intercept candidate — you cannot board your own ship.
		if (scene.get("npc_ships") as Array).has(consort):
			failures.append("A consort must not be an interceptable NPC.")
		# Spawning on top of the flagship makes physics shove the two apart
		# vertically, and a hull riding high clears the island collision entirely.
		if not is_equal_approx(consort.global_position.y, 0.0) or not is_equal_approx(player.global_position.y, 0.0):
			failures.append("Overworld ships must sit on the water plane (player y %.2f, consort y %.2f)." % [player.global_position.y, consort.global_position.y])
		if consort.global_position.distance_to(player.global_position) < 2.0:
			failures.append("A consort should spawn on station, not on top of the flagship.")
		if consort.motion_mode != CharacterBody3D.MOTION_MODE_FLOATING:
			failures.append("Overworld ships need floating motion or they climb onto the island.")

		# Steering must aim AT the target: both headings measured off the same
		# vector. The old code was half a turn out and sailed away from it.
		consort.global_position = player.global_position + Vector3(0.0, 0.0, 40.0)
		var before := consort.global_position.distance_to(player.global_position)
		for _step in range(90):
			await physics_frame
		var after := consort.global_position.distance_to(player.global_position)
		if after >= before:
			failures.append("A consort left astern should close on the flagship, not fall further behind (%.1f -> %.1f)." % [before, after])

	# A fleet sails at the speed of its slowest ship, so a galleon consort must
	# hold a frigate flagship back.
	if player and player.has_method("_fleet_pace"):
		var flagship_stats := ContentCatalog.build_ship_stats(ContentCatalog.load_player_ship_record(), ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
		var pace: float = player.call("_fleet_pace", flagship_stats)
		if pace >= float(flagship_stats.get("max_speed")):
			failures.append("A slow consort should hold the fleet back (pace %.2f vs flagship %.2f)." % [pace, float(flagship_stats.get("max_speed"))])

	_free_scene(scene)
	session.set("fleet", FleetScript.starting_fleet())
	session.set("flagship_index", 0)


func _test_cargo_content(failures: Array[String]) -> void:
	var cargo_types := ContentCatalog.load_cargo_types()
	if cargo_types.size() < 6:
		failures.append("Cargo types should load from data/cargo/cargo_types.yaml, got %d." % cargo_types.size())
		return

	# The whole decision at the after-action screen is value per ton, so the
	# spread has to be real. If bulk and treasure are worth the same by weight
	# there is nothing to choose between them.
	var cheapest := INF
	var richest := 0.0
	for id in cargo_types:
		var record: Dictionary = cargo_types[id]
		var per_ton := float(record.get("value", 0.0)) / maxf(float(record.get("weight", 1.0)), 0.01)
		cheapest = minf(cheapest, per_ton)
		richest = maxf(richest, per_ton)
	if richest < cheapest * 10.0:
		failures.append("Cargo value-per-ton spread is too flat (%.1f to %.1f); the hold poses no decision." % [cheapest, richest])

	# The goods that DO something must keep the numbers their effect reads, or
	# they are silently inert.
	for id in ["naval_stores", "rum", "medicine", "small_arms"]:
		if not cargo_types.has(id):
			failures.append("Cargo type '%s' should exist; a system reads its effect." % id)
			continue
		if not cargo_types[id].get("effect", {}).has("kind"):
			failures.append("Cargo type '%s' should carry an effect." % id)

	# A manifest is a tally, and its weight has to reach the hull the same way
	# cannon weight does or the load model is lying.
	var manifest := {"sugar": 3, "gold": 2}
	var expected := 3.0 * float(cargo_types["sugar"].get("weight")) + 2.0 * float(cargo_types["gold"].get("weight"))
	if not is_equal_approx(ContentCatalog.calculate_cargo_weight(manifest, cargo_types), expected):
		failures.append("Cargo manifest weight should be units times per-unit weight.")

	var record := {"ship_type": "sloop", "cargo": manifest, "cargo_weight": 999.0, "broadsides": {}}
	if not is_equal_approx(ContentCatalog.resolve_cargo_weight(record, cargo_types), expected):
		failures.append("A manifest should override the legacy cargo_weight scalar.")

	# Ships written without a manifest still get a hold from their role, and the
	# roll is seeded so a plundered ship stays plundered.
	var rolled := ContentCatalog.generate_cargo_manifest("trader", 40.0, "test_ship")
	if rolled.is_empty():
		failures.append("A cargo role should fill an empty hold.")
	elif str(ContentCatalog.generate_cargo_manifest("trader", 40.0, "test_ship")) != str(rolled):
		failures.append("Cargo generation must be stable for a given ship id, or holds refill themselves.")


func _test_fleet_state(failures: Array[String]) -> void:
	var fleet := FleetScript.starting_fleet()
	if fleet.size() != 1:
		failures.append("A new game should start with exactly one ship, got %d." % fleet.size())
		return

	var ship: Dictionary = fleet[0]
	if not ship.has("loadout") or not ship.has("condition"):
		failures.append("A fleet ship needs both a loadout and a condition.")
		return
	if not is_equal_approx(float(ship["condition"].get("hull_fraction", 0.0)), 1.0):
		failures.append("A new game's ship should be undamaged.")

	FleetScript.set_manifest(ship, {"sugar": 2})
	if int(FleetScript.get_manifest(ship).get("sugar", 0)) != 2:
		failures.append("Setting a fleet ship's manifest should stick.")
	if float(ship["loadout"].get("cargo_weight", -1.0)) != 0.0:
		failures.append("Setting a manifest should clear the legacy scalar so weight is not counted twice.")

	# A prize you keep costs hands to sail, which is what stops a fleet being
	# free. Bigger hulls cost more.
	var sloop_crew := FleetScript.minimum_prize_crew({"ship_type": "sloop"})
	var galleon_crew := FleetScript.minimum_prize_crew({"ship_type": "galleon"})
	if galleon_crew <= sloop_crew:
		failures.append("A galleon should need more prize crew than a sloop (%d vs %d)." % [galleon_crew, sloop_crew])


func _test_battle_report(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "battle report")
	if scene == null:
		return

	var report: Dictionary = scene.call("build_report", "enemy_captured")
	for key in ["result", "player", "enemy", "enemy_loadout", "enemy_manifest", "enemy_name"]:
		if not report.has(key):
			failures.append("Battle report is missing '%s'." % key)
	if not report.get("player", {}).has("hull_fraction"):
		failures.append("Battle report should carry the player's hull condition out of the battle.")
	if not report.get("enemy_loadout", {}).has("broadsides"):
		failures.append("Battle report should carry the enemy's loadout so her guns can be taken.")

	# The condition round-trip is what makes damage persist: a ship must sail
	# into her next battle carrying what the last one did to her.
	var player := scene.get_node_or_null("PlayerShip")
	var combat := player.get_node_or_null("ShipCombatComponent") if player else null
	if combat:
		combat.call("apply_hull_damage", combat.get("max_hull") * 0.5)
		var exported: Dictionary = combat.call("export_condition")
		if exported.get("hull_fraction", 1.0) > 0.6:
			failures.append("A ship that took half her hull should export a halved hull fraction.")
		combat.call("apply_condition", {"hull_fraction": 0.25, "sail_fraction": 0.5, "morale": 30.0})
		if not is_equal_approx(float(combat.get("hull")), float(combat.get("max_hull")) * 0.25):
			failures.append("Seeding a condition should restore the hull it describes.")

	_free_scene(scene)


func _test_after_action_prize(failures: Array[String]) -> void:
	var session := root.get_node_or_null("GameSession")
	if session == null:
		failures.append("After-action test could not find GameSession autoload.")
		return

	var galleon := _find_encounter("spanish_treasure_galleon")
	if galleon.is_empty():
		failures.append("After-action test needs the treasure galleon encounter.")
		return

	session.set("practice_mode", false)
	session.set("fleet", FleetScript.starting_fleet())
	session.set("flagship_index", 0)
	session.set("battle_report", _capture_report(galleon))

	var packed := load(AFTER_ACTION_SCENE_PATH)
	if packed == null:
		failures.append("Could not load the after-action scene.")
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame

	if scene.call("is_capture") != true:
		failures.append("A struck ship should read as a capture.")
	if scene.get("_prize_manifest").is_empty():
		failures.append("A captured ship should offer her hold.")

	# The frigate's guns fill her allowance exactly, so there is no room for
	# plunder until some go over the side. That consequence is the point.
	var free_hold := ContentCatalog.get_free_hold(ContentCatalog.load_player_ship_record())
	if free_hold <= 0.0 and not scene.get("_take_sliders").is_empty():
		var taken := 0
		for cargo_id in scene.get("_take_sliders"):
			taken += int(scene.get("_take_sliders")[cargo_id].value)
		if taken > 0:
			failures.append("A ship with no free hold should not open with plunder already loaded.")

	# Taking her as your own puts two ships in the fleet and shifts the flag.
	scene.call("_on_fate_selected", "flagship")
	scene.call("_apply_outcome")
	var fleet: Array = session.get("fleet")
	if fleet.size() != 2:
		failures.append("Keeping a prize should add her to the fleet, got %d ships." % fleet.size())
	elif int(session.get("flagship_index")) != 1:
		failures.append("Taking a prize as your own should shift the flag to her.")
	elif FleetScript.get_crew(fleet[1]) <= 0.0:
		failures.append("A prize needs hands aboard to sail her.")

	_free_scene(scene)
	session.set("fleet", FleetScript.starting_fleet())
	session.set("flagship_index", 0)
	session.set("battle_report", {})


func _test_morale_consequences(failures: Array[String]) -> void:
	var component: Node = ShipCombatComponentScript.new()
	var stats := ContentCatalog.build_ship_stats(ContentCatalog.load_player_ship_record(), ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	component.call("configure", stats, ContentCatalog.load_player_ship_record(), null, "Test ship")

	var willing: float = component.call("get_gunnery_multiplier")
	var willing_guns: int = component.call("get_active_cannon_limit")
	if not is_equal_approx(willing, 1.0):
		failures.append("A fresh sober crew should work the guns at full rate, got %.2f." % willing)

	# Morale was decorative before this: it has to reach the guns.
	component.set("morale", 5.0)
	var broken: float = component.call("get_gunnery_multiplier")
	if broken >= willing:
		failures.append("A broken crew should work the guns more slowly than a willing one.")
	if int(component.call("get_active_cannon_limit")) >= willing_guns:
		failures.append("A broken crew should man fewer guns.")

	# And a crew at the rum should be worse still than a merely miserable one.
	component.set("morale", 100.0)
	component.set("drunkenness", 100.0)
	if component.call("get_gunnery_multiplier") >= willing:
		failures.append("A drunk crew should fumble the guns; rum has to cost something.")

	# Surrender: the crew gives up rather than dying at the guns.
	component.set("drunkenness", 0.0)
	component.set("morale", 100.0)
	component.set("has_struck_colors", false)
	var threshold := GameDifficultyScript.value("morale", "surrender_threshold", 8.0)
	if threshold > 0.0:
		component.call("apply_morale_damage", 100.0)
		if not bool(component.get("has_struck_colors")):
			failures.append("A crew with no morale left should strike her colours.")
	component.free()


func _find_encounter(id: String) -> Dictionary:
	for record in ContentCatalog.load_overworld_ship_records():
		if str(record.get("id", "")) == id:
			return record
	return {}


func _capture_report(enemy: Dictionary) -> Dictionary:
	return {
		"result": "enemy_captured",
		"player": {
			"hull_fraction": 0.5, "sail_fraction": 0.7, "crew": 40.0, "morale": 55.0,
			"drunkenness": 0.0, "mast_broken": false,
			"disabled_cannons": {"port": 0, "starboard": 0},
			"disabled_gun_ports": {"port": 0, "starboard": 0}
		},
		"enemy": {
			"hull_fraction": 0.1, "sail_fraction": 0.2, "crew": 50.0, "morale": 4.0,
			"drunkenness": 0.0, "mast_broken": true,
			"disabled_cannons": {"port": 0, "starboard": 0},
			"disabled_gun_ports": {"port": 0, "starboard": 0}
		},
		"enemy_loadout": enemy.duplicate(true),
		"enemy_manifest": enemy.get("cargo", {}).duplicate(),
		"enemy_name": str(enemy.get("name", "Prize"))
	}


func _test_main_menu_offers_both_modes(failures: Array[String]) -> void:
	var packed := load(MAIN_MENU_SCENE_PATH)
	if packed == null:
		failures.append("Could not load main menu scene.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate main menu scene.")
		return

	root.add_child(scene)
	await process_frame

	for button_name in ["StartGameButton", "PracticeButton", "QuitButton"]:
		var button := scene.find_child(button_name, true, false) as Button
		if button == null:
			failures.append("Main menu should offer a %s." % button_name)
		elif button.disabled:
			failures.append("Main menu %s should be usable." % button_name)

	_free_scene(scene)


func _test_practice_setup_validates_loadouts(failures: Array[String]) -> void:
	var packed := load(PRACTICE_SETUP_SCENE_PATH)
	if packed == null:
		failures.append("Could not load practice setup scene.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate practice setup scene.")
		return

	root.add_child(scene)
	await process_frame

	# A sloop can float four light 4-pounders a side: 32 tons against her 40, and
	# eight guns against her eight ports.
	var legal := _practice_loadout("sloop", "light_4_pounder", 4, 30)
	scene.player_editor.apply_record(legal)
	scene.enemy_editor.apply_record(legal)
	var legal_report: Dictionary = scene.validate()
	if not legal_report.get("errors", []).is_empty():
		failures.append("Practice setup rejected a legal sloop loadout: %s" % str(legal_report.get("errors")))
	if scene.begin_button.disabled:
		failures.append("Practice setup should allow a battle once both ships are legal.")

	# Same hull, twelve long 12-pounders a side: 240 tons on a 40-ton allowance.
	var overloaded := _practice_loadout("sloop", "long_12_pounder", 12, 30)
	scene.player_editor.apply_record(overloaded)
	var overload_report: Dictionary = scene.validate()
	var reported_overload := false
	for error in overload_report.get("errors", []):
		if "usable_load_capacity" in str(error):
			reported_overload = true
	if not reported_overload:
		failures.append("Practice setup should refuse a ship loaded past her capacity.")
	if not scene.begin_button.disabled:
		failures.append("Practice setup should block the battle while a loadout is invalid.")

	# More crew than the hull berths is the other way to break a ship on paper.
	var overcrewed := _practice_loadout("sloop", "light_4_pounder", 4, 400)
	scene.player_editor.apply_record(overcrewed)
	if int(scene.player_editor.build_record().get("crew", 0)) > 75:
		failures.append("Practice setup crew should be capped at the hull's max_crew.")

	# The built records must be the shape the rest of the game reads.
	scene.player_editor.apply_record(legal)
	var records: Dictionary = scene.build_records()
	for key in ["player", "enemy"]:
		var record: Dictionary = records.get(key, {})
		for field in ["ship_type", "faction", "visual_variant", "sail_set", "crew", "cargo_weight", "modifications", "broadsides"]:
			if not record.has(field):
				failures.append("Practice %s record is missing '%s'." % [key, field])

	_free_scene(scene)


func _test_practice_battle_uses_both_loadouts(failures: Array[String]) -> void:
	var session := root.get_node_or_null("GameSession")
	if session == null:
		failures.append("Practice battle test could not find GameSession autoload.")
		return

	var player_record := _practice_loadout("frigate", "long_12_pounder", 6, 70)
	var enemy_record := _practice_loadout("brig", "long_9_pounder", 5, 60)
	session.set("practice_mode", true)
	session.set("player_ship_override", player_record)
	session.set("selected_encounter", enemy_record)

	var packed := load(NAVAL_BATTLE_SCENE_PATH)
	if packed == null:
		failures.append("Could not load naval battle scene for the practice handoff.")
		_clear_practice_session(session)
		return

	var scene: Node = packed.instantiate()
	_disable_battle_auto_return(scene)
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null("PlayerShip")
	if player == null:
		failures.append("Practice battle should include PlayerShip.")
	elif str(player.get("ship_type_id")) != "frigate":
		failures.append("Practice battle player should sail the ship built on the setup screen, not player_ship.yaml.")

	var target := scene.get_node_or_null("TargetShip")
	if target == null:
		failures.append("Practice battle should include TargetShip.")
	elif str(target.get("ship_type_id")) != "brig":
		failures.append("Practice battle enemy should sail the ship built on the setup screen.")

	_free_scene(scene)
	_clear_practice_session(session)


func _practice_loadout(ship_type: String, cannon_id: String, per_side: int, crew: int) -> Dictionary:
	var cannons: Array = []
	for _index in range(per_side):
		cannons.append(cannon_id)
	return {
		"ship_type": ship_type,
		"faction": "pirates",
		"visual_variant": "worn",
		"sail_set": "full",
		"crew": crew,
		"cargo_weight": 0,
		"modifications": [],
		"broadsides": {
			"port": {"cannons": cannons.duplicate()},
			"starboard": {"cannons": cannons.duplicate()}
		}
	}


func _clear_practice_session(session: Node) -> void:
	session.set("practice_mode", false)
	session.set("player_ship_override", {})
	session.set("selected_encounter", {})


func _test_naval_battle_uses_overworld_encounter(failures: Array[String]) -> void:
	var records := ContentCatalog.load_overworld_ship_records()
	if records.is_empty():
		failures.append("Encounter handoff test needs at least one overworld ship record.")
		return
	var session := root.get_node_or_null("GameSession")
	if session == null:
		failures.append("Encounter handoff test could not find GameSession autoload.")
		return

	session.set("selected_encounter", records[0].duplicate(true))
	var packed := load(NAVAL_BATTLE_SCENE_PATH)
	if packed == null:
		failures.append("Could not load naval battle scene for encounter handoff.")
		session.set("selected_encounter", {})
		return

	var scene: Node = packed.instantiate()
	_disable_battle_auto_return(scene)
	root.add_child(scene)
	await process_frame
	await physics_frame

	var target := scene.get_node_or_null("TargetShip")
	if target == null:
		failures.append("Encounter handoff battle should include TargetShip.")
	else:
		if target.get("ship_type_id") != str(records[0].get("ship_type", "")):
			failures.append("TargetShip should use selected overworld encounter ship_type.")
		if str(target.get("ship_loadout").get("faction", "")) != str(records[0].get("faction", "")):
			failures.append("TargetShip should use selected overworld encounter faction.")

	session.set("selected_encounter", {})
	_free_scene(scene)


func _test_main_scene_moves_ship(failures: Array[String]) -> void:
	var packed := load(NAVAL_BATTLE_SCENE_PATH)
	if packed == null:
		failures.append("Could not load main scene.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate main scene.")
		return

	root.add_child(scene)
	_disable_battle_auto_return(scene)
	await process_frame
	await physics_frame
	_disable_target_ai(scene)

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var wind := scene.get_node_or_null("WindSystem")
	if ship == null:
		failures.append("Main scene does not contain PlayerShip.")
		scene.queue_free()
		return
	if wind == null:
		failures.append("Main scene does not contain WindSystem.")
		scene.queue_free()
		return
	var target := scene.get_node_or_null("TargetShip") as Node3D
	if target == null:
		failures.append("Main scene does not contain TargetShip.")
		scene.queue_free()
		return
	var ocean := scene.get_node_or_null("Ocean") as MeshInstance3D
	if ocean == null:
		failures.append("Main scene does not contain Ocean.")
	else:
		var player_hull_for_waterline := ship.get_node_or_null("VisualRoot/Hull") as MeshInstance3D
		if player_hull_for_waterline:
			var hull_top := player_hull_for_waterline.global_position.y + player_hull_for_waterline.mesh.get_aabb().size.y * ship.scale.y * 0.5
			if ocean.global_position.y >= hull_top:
				failures.append("Ocean surface should not cover the top of the player hull.")
	var player_stats: Resource = ContentCatalog.load_player_ship_stats()
	var target_stats: Resource = ContentCatalog.load_target_ship_stats()
	if not is_equal_approx(ship.scale.x, float(player_stats.get("visual_scale"))):
		failures.append("Player ship scale should match configured ship type visual_scale.")
	if not is_equal_approx(target.scale.x, float(target_stats.get("visual_scale"))):
		failures.append("Target ship scale should match configured ship type visual_scale.")
	var target_collision := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if target_collision and target.scale.x < float(target.get("minimum_cannon_hit_scale")):
		var hitbox_world_scale := target_collision.global_transform.basis.get_scale().x
		if not hitbox_world_scale > target.scale.x:
			failures.append("Small target ships should have a modest cannon-hit forgiveness collider.")
	var player_hull := ship.get_node_or_null("VisualRoot/Hull") as MeshInstance3D
	var target_hull := target.get_node_or_null("VisualRoot/Hull") as MeshInstance3D
	var player_bow := ship.get_node_or_null("VisualRoot/Bow") as MeshInstance3D
	var target_bow := target.get_node_or_null("VisualRoot/Bow") as MeshInstance3D
	var player_mast := ship.get_node_or_null("VisualRoot/Mast") as MeshInstance3D
	var target_mast := target.get_node_or_null("VisualRoot/Mast") as MeshInstance3D
	if player_hull == null or target_hull == null or player_bow == null or target_bow == null or player_mast == null or target_mast == null:
		failures.append("Player and target ships should share the same primitive hull, bow, and mast parts.")
	else:
		var player_hull_size: Vector3 = player_hull.mesh.get_aabb().size
		var target_hull_size: Vector3 = target_hull.mesh.get_aabb().size
		if player_stats.get("ship_type_id") == target_stats.get("ship_type_id") and not player_hull_size.is_equal_approx(target_hull_size):
			failures.append("Same-type player and target ships should start from matching base hull dimensions.")
		if player_bow.rotation_degrees.length() > 0.001 or target_bow.rotation_degrees.length() > 0.001:
			failures.append("Generated bow meshes should point forward without scene-level rotation hacks.")
	var player_visuals := ship.get_node_or_null("VisualRoot/ShipVisualBuilder/GeneratedVisuals")
	var target_visuals := target.get_node_or_null("VisualRoot/ShipVisualBuilder/GeneratedVisuals")
	if player_visuals == null or _count_children_with_prefix(player_visuals, "Flag_") <= 0:
		failures.append("Player generated visuals should include at least one visible flag node.")
	else:
		var player_flag := _get_child_with_prefix(player_visuals, "Flag_") as MeshInstance3D
		# Right-sized policy: profile size x1.3 (skull floor 0.6 x profile
		# scale) — readable at the battle camera without dwarfing the hull.
		if player_flag == null or player_flag.mesh.get_aabb().size.x < 0.55 or player_flag.mesh.get_aabb().size.x > 1.1:
			failures.append("Player flag should be right-sized: readable without dwarfing the mesh hull.")
		elif player_flag.material_override == null or player_flag.material_override.get("albedo_texture") == null:
			failures.append("Player flag should use a generated emblem texture.")
		elif not _mesh_has_uvs(player_flag.mesh):
			failures.append("Player flag mesh should include UVs so generated emblems render.")
	if target_visuals == null or _count_children_with_prefix(target_visuals, "Flag_") <= 0:
		failures.append("Target generated visuals should include at least one visible flag node.")
	else:
		var target_flag := _get_child_with_prefix(target_visuals, "Flag_") as MeshInstance3D
		if target_flag == null or target_flag.material_override == null or target_flag.material_override.get("albedo_texture") == null:
			failures.append("Target flag should use a generated emblem texture.")
		elif not _mesh_has_uvs(target_flag.mesh):
			failures.append("Target flag mesh should include UVs so generated emblems render.")

	wind.set("wind_direction_degrees", 180.0)
	var start_position := ship.global_position

	for index in range(90):
		await physics_frame

	var distance := start_position.distance_to(ship.global_position)
	if distance < 1.0:
		failures.append("PlayerShip did not move far enough under tailwind. Distance: %.3f" % distance)

	root.remove_child(scene)
	scene.free()
	await process_frame


func _test_cannon_hits_target(failures: Array[String]) -> void:
	var packed := load(NAVAL_BATTLE_SCENE_PATH)
	if packed == null:
		failures.append("Could not load main scene for cannon test.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate main scene for cannon test.")
		return

	root.add_child(scene)
	_disable_battle_auto_return(scene)
	await process_frame
	await physics_frame
	_disable_target_ai(scene)

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip")
	if ship == null:
		failures.append("Cannon test could not find PlayerShip.")
		_free_scene(scene)
		return
	if target == null:
		failures.append("Cannon test could not find TargetShip.")
		_free_scene(scene)
		return
	target.set("movement_enabled", false)
	target.global_position = Vector3(18.0, 0.0, 0.0)
	target.rotation_degrees = Vector3.ZERO

	var broadside := ship.get_node_or_null("BroadsideController")
	if broadside == null:
		failures.append("PlayerShip does not contain BroadsideController.")
		_free_scene(scene)
		return

	var starting_hull: float = target.get("hull")
	var fired: bool = broadside.call("fire_starboard")
	if not fired:
		failures.append("Starboard broadside did not fire.")
		_free_scene(scene)
		return

	var saw_impact := false
	for index in range(160):
		await physics_frame
		saw_impact = saw_impact or _scene_has_child_named(scene, "ImpactFlash")

	var ending_hull: float = target.get("hull")
	if ending_hull >= starting_hull:
		failures.append("Target hull did not decrease after starboard broadside. Start: %.2f End: %.2f" % [starting_hull, ending_hull])
	if not saw_impact:
		failures.append("Cannon hit should spawn an impact flash.")

	_free_scene(scene)


func _test_armament_damage(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "armament damage")
	if scene == null:
		return

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip")
	var broadside := _get_broadside(scene, failures)
	if ship == null or target == null or broadside == null:
		_free_scene(scene)
		return

	var forced_ordnance_damage := {
		"cannon_disable_chance": 1.0,
		"gun_port_disable_chance": 1.0
	}
	target.call("apply_projectile_hit", 0.0, {}, forced_ordnance_damage, target.to_global(Vector3(1.0, 0.4, 0.0)))
	await process_frame
	if int(target.call("get_disabled_cannon_count", 1)) != 1:
		failures.append("A forced starboard ordnance hit should disable one target cannon.")
	if int(target.call("get_disabled_gun_port_count", 1)) != 1:
		failures.append("A forced starboard ordnance hit should disable one target gun port.")

	var original_firing_count: int = broadside.call("_get_side_firing_cannons", 1).size()
	ship.set("disabled_cannons", {"port": 0, "starboard": 1})
	ship.set("disabled_gun_ports", {"port": 0, "starboard": 1})
	var reduced_firing_count: int = broadside.call("_get_side_firing_cannons", 1).size()
	if not reduced_firing_count < original_firing_count:
		failures.append("Disabled player cannons and gun ports should reduce starboard firing cannon count.")

	_free_scene(scene)


func _test_sail_crew_morale_damage(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "sail crew morale damage")
	if scene == null:
		return

	var target := scene.get_node_or_null("TargetShip")
	if target == null:
		failures.append("Sail/crew/morale damage test could not find TargetShip.")
		_free_scene(scene)
		return

	var starting_hull: float = target.get("hull")
	var starting_sail: float = target.get("sail")
	var starting_crew: float = target.get("crew")
	var starting_morale: float = target.get("morale")
	var forced_damage := {
		"sail_damage": 11.0,
		"crew_damage": 7.0,
		"morale_damage": 5.0
	}
	target.call("apply_projectile_hit", 0.0, {}, forced_damage, target.to_global(Vector3(1.0, 0.4, 0.0)))
	await process_frame

	if target.get("hull") != starting_hull:
		failures.append("Sail/crew/morale damage should not change hull when hull damage is zero.")
	if not is_equal_approx(float(target.get("sail")), starting_sail - 11.0):
		failures.append("Projectile context should apply sail damage.")
	if not is_equal_approx(float(target.get("crew")), starting_crew - 7.0):
		failures.append("Projectile context should apply crew damage.")
	if not is_equal_approx(float(target.get("morale")), starting_morale - 5.0):
		failures.append("Projectile context should apply morale damage.")

	target.call("apply_sail_damage", 9999.0)
	target.call("apply_crew_damage", 9999.0)
	target.call("apply_morale_damage", 9999.0)
	if target.get("sail") != 0.0 or target.get("crew") != 0.0 or target.get("morale") != 0.0:
		failures.append("Sail, crew, and morale damage should clamp at zero.")

	_free_scene(scene)


func _test_mast_break_and_crew_limits(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "mast break and crew limits")
	if scene == null:
		return

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	var broadside := _get_broadside(scene, failures)
	if ship == null or target == null or broadside == null:
		_free_scene(scene)
		return

	var starting_position := target.global_position
	target.call("apply_sail_damage", 9999.0)
	await process_frame
	if not bool(target.get("is_mast_broken")):
		failures.append("Reducing sail health to zero should break the target mast.")
	if target.get("sail") != 0.0:
		failures.append("Breaking the mast should clamp sail health to zero.")
	for index in range(45):
		await physics_frame
	if target.global_position.distance_to(starting_position) > 0.1:
		failures.append("A ship with a broken mast should not continue sailing under wind.")

	var full_count: int = broadside.call("_get_side_firing_cannons", 1).size()
	ship.set("crew", 5.0)
	var reduced_count: int = broadside.call("_get_side_firing_cannons", 1).size()
	if full_count <= 1:
		failures.append("Crew limit test needs a player broadside with more than one available cannon.")
	if reduced_count != 1:
		failures.append("Five crew should only support one active cannon at three crew per cannon. Saw %d." % reduced_count)

	_free_scene(scene)


func _test_target_ai_test_toggles(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "target AI test toggles")
	if scene == null:
		return

	var target := scene.get_node_or_null("TargetShip") as Node3D
	if target == null:
		failures.append("Target AI toggle test could not find TargetShip.")
		_free_scene(scene)
		return

	target.set("ai_enabled", false)
	target.set("movement_enabled", false)
	target.set("firing_enabled", false)
	var start_position := target.global_position
	for index in range(90):
		await physics_frame
	if target.global_position.distance_to(start_position) > 0.05:
		failures.append("Target should remain stationary when movement_enabled is false.")

	_free_scene(scene)


func _test_enemy_can_fire_at_player(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "enemy fire")
	if scene == null:
		return

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	if ship == null or target == null:
		failures.append("Enemy fire test needs PlayerShip and TargetShip.")
		_free_scene(scene)
		return

	var wind := scene.get_node_or_null("WindSystem")
	if wind:
		wind.set("wind_strength", 0.0)
	ship.global_position = Vector3.ZERO
	ship.set_physics_process(false)
	target.global_position = Vector3(18.0, 0.0, 0.0)
	target.rotation_degrees = Vector3.ZERO
	target.set("ai_enabled", true)
	target.set("movement_enabled", false)
	target.set("firing_enabled", true)
	target.set("initial_firing_delay", 0.0)
	target.set("aim_commit_time", 0.0)
	var starting_hull: float = ship.get("hull")
	for index in range(300):
		await physics_frame
	if float(ship.get("hull")) >= starting_hull:
		failures.append("Enemy AI should be able to fire a broadside that damages the player.")

	_free_scene(scene)


func _test_broadside_side_behavior(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "broadside side behavior")
	if scene == null:
		return

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var broadside := _get_broadside(scene, failures)
	if ship == null or broadside == null:
		_free_scene(scene)
		return

	var starting_children := scene.get_child_count()
	var port_fired: bool = broadside.call("fire_port")
	await process_frame
	var after_port_children := scene.get_child_count()
	if not port_fired:
		failures.append("Port broadside should fire when ready.")
	if broadside.get("port_cooldown") <= 0.0:
		failures.append("Port broadside should enter cooldown after firing.")
	if broadside.get("starboard_cooldown") != 0.0:
		failures.append("Port broadside should not put starboard broadside into cooldown.")
	if after_port_children <= starting_children:
		failures.append("Port broadside should spawn projectile or flash nodes.")

	var starboard_fired: bool = broadside.call("fire_starboard")
	await process_frame
	if not starboard_fired:
		failures.append("Starboard broadside should fire while port is cooling down.")
	if broadside.get("starboard_cooldown") <= 0.0:
		failures.append("Starboard broadside should enter cooldown after firing.")

	_free_scene(scene)


func _test_ammo_switch_cooldown(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "ammo switch cooldown")
	if scene == null:
		return

	var broadside := _get_broadside(scene, failures)
	if broadside == null:
		_free_scene(scene)
		return

	broadside.call("select_ammo_by_index", 1)
	if broadside.get("selected_ammo_id") != "chain":
		failures.append("Selecting ammo index 1 should switch to chain shot.")
	if broadside.get("port_cooldown") <= 0.0 or broadside.get("starboard_cooldown") <= 0.0:
		failures.append("Changing ammo should put both broadsides into cooldown.")

	_free_scene(scene)


func _test_asymmetric_ship_loadout(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "asymmetric ship loadout")
	if scene == null:
		return

	var broadside := _get_broadside(scene, failures)
	if broadside == null:
		_free_scene(scene)
		return
	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	if ship == null:
		failures.append("Asymmetric loadout test could not find PlayerShip.")
		_free_scene(scene)
		return

	var port_cannons: Array = broadside.call("_get_side_cannons", -1)
	var starboard_cannons: Array = broadside.call("_get_side_cannons", 1)
	var player_record := ContentCatalog.load_player_ship_record()
	var broadsides: Dictionary = player_record.get("broadsides", {})
	var expected_port: Array = broadsides.get("port", {}).get("cannons", [])
	var expected_starboard: Array = broadsides.get("starboard", {}).get("cannons", [])
	if port_cannons.size() != expected_port.size():
		failures.append("Port carried cannon count should match player_ship.yaml. Found %d expected %d." % [port_cannons.size(), expected_port.size()])
	if starboard_cannons.size() != expected_starboard.size():
		failures.append("Starboard carried cannon count should match player_ship.yaml. Found %d expected %d." % [starboard_cannons.size(), expected_starboard.size()])

	var live_port_weight: float = broadside.call("_get_side_weight", -1)
	var live_starboard_weight: float = broadside.call("_get_side_weight", 1)
	var total_weight: float = broadside.call("get_total_cannon_weight")
	if not is_equal_approx(total_weight, live_port_weight + live_starboard_weight):
		failures.append("Total cannon weight should equal port plus starboard cannon weight.")

	# Asymmetry math runs on an injected fixture, NOT the live player file:
	# player_ship.yaml is the player's own loadout (they edit it while playing,
	# 2026-08-17) and any symmetric loadout would fail these by construction.
	var original_loadout: Variant = broadside.get("ship_loadout")
	broadside.set("ship_loadout", {
		"broadsides": {
			"port": {"cannons": [
				"light_4_pounder",
				"light_4_pounder",
				"light_4_pounder",
				"light_4_pounder",
			]},
			"starboard": {"cannons": [
				"long_9_pounder",
				"long_9_pounder",
				"long_9_pounder",
			]}
		}
	})
	var port_range: float = broadside.call("_get_side_max_range", -1)
	var starboard_range: float = broadside.call("_get_side_max_range", 1)
	if not starboard_range > port_range:
		failures.append("Starboard mixed long-cannon fixture should outrange port.")

	var port_reload: float = broadside.call("_get_side_reload_time", -1)
	var starboard_reload: float = broadside.call("_get_side_reload_time", 1)
	if not starboard_reload > port_reload:
		failures.append("Starboard mixed long-cannon fixture should reload slower than port.")

	var port_weight: float = broadside.call("_get_side_weight", -1)
	var starboard_weight: float = broadside.call("_get_side_weight", 1)
	if not starboard_weight > port_weight:
		failures.append("Starboard mixed long-cannon fixture should weigh more than port.")
	broadside.set("ship_loadout", original_loadout)

	var sloop_stats: Resource = ContentCatalog.build_ship_stats({
		"ship_type": "sloop",
		"cargo_weight": 0.0,
		"modifications": [],
		"broadsides": {}
	}, ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	broadside.set("ship_stats", sloop_stats)
	broadside.set("ship_loadout", {
		"broadsides": {
			"port": {
				"cannons": [
					"light_4_pounder",
					"light_4_pounder",
					"light_4_pounder",
					"light_4_pounder",
					"long_12_pounder",
					"long_12_pounder"
				]
			},
			"starboard": {"cannons": []}
		}
	})
	var carried_port_cannons: Array = broadside.call("_get_side_cannons", -1)
	var firing_port_cannons: Array = broadside.call("_get_side_firing_cannons", -1)
	if carried_port_cannons.size() != 6:
		failures.append("Broadside loadout should be allowed to carry cannons beyond available gun ports.")
	if firing_port_cannons.size() != 4:
		failures.append("Sloop should only fire 4 cannons per side through its gun ports.")

	ship.scale = Vector3.ONE * 0.75
	var scaled_muzzle: Vector3 = broadside.call("_get_muzzle_global_position", ship, 1, 0, 1)
	var scaled_offset := scaled_muzzle.distance_to(ship.global_position)
	var unscaled_offset := Vector3(1.05, 0.45, 0.0).length()
	if not scaled_offset < unscaled_offset:
		failures.append("Muzzle positions should respect ship visual scale so sloop cannon shots stay attached to the hull.")

	ship.scale = Vector3.ONE * 1.65
	var first_muzzle: Vector3 = broadside.call("_get_muzzle_global_position", ship, 1, 0, 7)
	var last_muzzle: Vector3 = broadside.call("_get_muzzle_global_position", ship, 1, 6, 7)
	var first_direction: Vector3 = broadside.call("_get_converged_fire_direction", ship, first_muzzle, 1)
	var last_direction: Vector3 = broadside.call("_get_converged_fire_direction", ship, last_muzzle, 1)
	if not first_direction.z > 0.0 or not last_direction.z < 0.0:
		failures.append("Fore and aft guns should converge toward a shared broadside aim zone.")
	if first_direction.dot(Vector3.RIGHT) < 0.98 or last_direction.dot(Vector3.RIGHT) < 0.98:
		failures.append("Broadside convergence should stay limited and not turn cannons into sniper fire.")

	_free_scene(scene)


func _test_projectile_range_splash(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "projectile range splash")
	if scene == null:
		return

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var broadside := _get_broadside(scene, failures)
	if ship == null or broadside == null:
		_free_scene(scene)
		return

	var target := scene.get_node_or_null("TargetShip") as Node3D
	if target:
		target.global_position = Vector3(300.0, 0.0, 0.0)

	var fired: bool = broadside.call("fire_starboard")
	if not fired:
		failures.append("Starboard broadside should fire for splash test.")
		_free_scene(scene)
		return

	var saw_cannonball := false
	var saw_splash := false
	for index in range(260):
		await physics_frame
		saw_cannonball = saw_cannonball or _scene_has_child_named(scene, "Cannonball")
		saw_splash = saw_splash or _scene_has_child_named(scene, "Splash")

	if not saw_cannonball:
		failures.append("Splash test never observed a cannonball.")
	if _scene_has_child_named(scene, "Cannonball"):
		failures.append("Cannonball should despawn after reaching max range.")
	if not saw_splash:
		failures.append("Cannonball should spawn a splash at max range.")

	_free_scene(scene)


func _test_projectile_range_independent_of_ship_scale(failures: Array[String]) -> void:
	var packed := load("res://game/scenes/Cannonball.tscn") as PackedScene
	if packed == null:
		failures.append("Could not load Cannonball scene for range-scale test.")
		return

	var scene := Node3D.new()
	root.add_child(scene)
	var source := Node3D.new()
	source.scale = Vector3.ONE * 0.9
	scene.add_child(source)

	var cannonball := packed.instantiate() as Node3D
	if cannonball == null:
		failures.append("Could not instantiate Cannonball for range-scale test.")
		_free_scene(scene)
		return

	var cannon_types := ContentCatalog.load_cannon_types()
	var ammo_types := ContentCatalog.load_ammo_types()
	scene.add_child(cannonball)
	cannonball.global_position = source.to_global(Vector3(1.05, 0.45, 0.0))
	cannonball.call("configure", Vector3.RIGHT, cannon_types.get("long_12_pounder"), ammo_types.get("round"), source)
	var start_position := cannonball.global_position

	var splash_position := Vector3.ZERO
	for index in range(260):
		await physics_frame
		var splash := _get_child_named(scene, "Splash") as Node3D
		if splash:
			splash_position = splash.global_position
			break

	if splash_position == Vector3.ZERO:
		failures.append("Scaled-source projectile should splash after reaching max range.")
	else:
		var splash_distance := Vector2(start_position.x, start_position.z).distance_to(Vector2(splash_position.x, splash_position.z))
		if absf(splash_distance - 72.0) > 2.0:
			failures.append("Long 12-pounder round shot should travel about 72 units from a sloop-sized source. Saw %.2f." % splash_distance)

	_free_scene(scene)


func _free_scene(scene: Node) -> void:
	root.remove_child(scene)
	scene.free()


func _test_target_sinks_at_zero_hull(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "target sinking")
	if scene == null:
		return

	var target := scene.get_node_or_null("TargetShip")
	if target == null:
		failures.append("Sinking test could not find TargetShip.")
		_free_scene(scene)
		return

	target.call("apply_hull_damage", 999.0)
	await process_frame

	if not target.get("is_sunk"):
		failures.append("Target should be marked sunk when hull reaches zero.")
	if target.get("hull") != 0.0:
		failures.append("Target hull should clamp to zero when sunk.")

	_free_scene(scene)


func _test_fire_status_effects(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "fire status effects")
	if scene == null:
		return

	var ship := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip")
	var broadside := _get_broadside(scene, failures)
	if ship == null or target == null or broadside == null:
		_free_scene(scene)
		return

	broadside.call("select_ammo_by_index", 3)
	if broadside.get("selected_ammo_id") != "fire":
		failures.append("Selecting ammo index 3 should switch to fire shot.")

	var ammo = broadside.call("_get_ammo_type")
	var effects: Dictionary = ammo.get("status_effects")
	if not effects.has("burning"):
		failures.append("Fire shot should define a burning status effect.")
	else:
		var burning: Dictionary = effects.burning
		if float(burning.get("self_ignition_chance", 0.0)) <= 0.0:
			failures.append("Fire shot should define self_ignition_chance.")

	var forced_burning := {
		"burning": {
			"chance": 1.0,
			"duration": 0.4,
			"hull_damage_per_second": 10.0
		}
	}
	var starting_hull: float = target.get("hull")
	target.call("apply_status_effects", forced_burning)
	await process_frame
	if not target.get("is_burning"):
		failures.append("Target should enter burning state from burning status effect.")
	if target.get("burning_severity") != "small":
		failures.append("First burning status should apply small fire severity.")

	target.call("apply_status_effects", forced_burning)
	await process_frame
	if target.get("burning_severity") != "medium":
		failures.append("Second burning status should escalate fire to medium severity.")

	target.set("burning_growth_chance_per_second", 1.0)
	target.set("burning_magazine_explosion_chance_per_second", 0.0)
	target.set("burning_growth_tick", 1.0)
	await process_frame
	if target.get("burning_severity") != "large":
		failures.append("Burning status should be able to grow on its own over time.")

	# Fire growth re-reads the level config, re-arming the explosion chance
	# zeroed above; zero it again (and stop further growth) so the target
	# cannot randomly magazine-explode during the burn-damage window.
	target.set("burning_growth_chance_per_second", 0.0)
	target.set("burning_magazine_explosion_chance_per_second", 0.0)

	for index in range(30):
		await process_frame

	if target.get("hull") >= starting_hull:
		failures.append("Burning status should deal hull damage over time.")

	var self_effects := {
		"burning": {
			"self_ignition_chance": 1.0,
			"duration": 0.4,
			"hull_damage_per_second": 1.0
		}
	}
	var rolled: Dictionary = broadside.call("_roll_self_status_effects", self_effects)
	if not rolled.has("burning"):
		failures.append("Self ignition roll with 100% chance should produce burning effect.")

	ship.call("apply_status_effects", rolled)
	# Burning arms a per-second magazine-explosion chance; zero it before the
	# frame ticks so the player cannot randomly explode and sink mid-check.
	# Growth must go too: one hitch frame can grow the fire and re-arm the
	# explosion chance within the same update_status call.
	ship.set("burning_magazine_explosion_chance_per_second", 0.0)
	ship.set("burning_growth_chance_per_second", 0.0)
	await process_frame
	if not ship.get("is_burning"):
		failures.append("Player ship should be able to catch fire from self ignition.")

	_free_scene(scene)


func _test_magazine_explosion(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "magazine explosion")
	if scene == null:
		return

	var target := scene.get_node_or_null("TargetShip")
	if target == null:
		failures.append("Magazine explosion test could not find TargetShip.")
		_free_scene(scene)
		return

	target.set("magazine_explosion_multiplier", 1.0)
	var forced_explosion := {
		"magazine_explosion": {
			"chance": 1.0
		}
	}
	target.call("apply_status_effects", forced_explosion)
	if not target.get("is_sunk"):
		failures.append("Magazine explosion should sink/disable target immediately when forced.")
	if not _scene_has_child_named(scene, "MagazineExplosion"):
		failures.append("Magazine explosion should spawn primitive explosion visual.")

	_free_scene(scene)


func _instantiate_main_scene(failures: Array[String], test_name: String) -> Node:
	var packed := load(NAVAL_BATTLE_SCENE_PATH)
	if packed == null:
		failures.append("Could not load main scene for %s test." % test_name)
		return null

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate main scene for %s test." % test_name)
		return null

	root.add_child(scene)
	await process_frame
	await physics_frame
	_disable_target_ai(scene)
	# A randomly sunk ship must never trigger GameSession's battle-end scene
	# change mid-suite: autoloads ARE instanced in --script mode, and a live
	# current_scene would leak state across tests.
	_disable_battle_auto_return(scene)
	# Likewise a boarding: the enemy will now come for the player on its own, and
	# a grapple firing mid-test would rewrite the battle a gunnery test is
	# measuring. Boarding tests turn it back on deliberately.
	_disable_boarding(scene)
	return scene


func _get_broadside(scene: Node, failures: Array[String]) -> Node:
	var ship := scene.get_node_or_null("PlayerShip")
	if ship == null:
		failures.append("Could not find PlayerShip for broadside test.")
		return null

	var broadside := ship.get_node_or_null("BroadsideController")
	if broadside == null:
		failures.append("Could not find BroadsideController for broadside test.")
		return null
	return broadside


func _scene_has_child_named(scene: Node, child_name: String) -> bool:
	return _get_child_named(scene, child_name) != null


func _get_child_named(scene: Node, child_name: String) -> Node:
	for child in scene.get_children():
		if child.name == child_name or child.name.begins_with("%s@" % child_name):
			return child
	return null


func _count_children_with_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child in node.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


func _get_child_with_prefix(node: Node, prefix: String) -> Node:
	for child in node.get_children():
		if child.name.begins_with(prefix):
			return child
	return null


func _mesh_has_uvs(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	return uvs.size() > 0


func _test_duel_content(failures: Array[String]) -> void:
	var weapons := ContentCatalog.load_duel_weapons()
	for required in ["cutlass", "longsword", "broadsword"]:
		if not weapons.has(required):
			failures.append("Duel weapons should include '%s'." % required)
	if weapons.has("cutlass") and weapons.has("broadsword"):
		# The user-requested tradeoff: choosing a blade must change how fast you
		# fight, not just how hard you hit.
		if not float(weapons["cutlass"].get("windup_multiplier")) < float(weapons["broadsword"].get("windup_multiplier")):
			failures.append("A cutlass should wind up faster than a broadsword.")
		if not float(weapons["cutlass"].get("damage_multiplier")) < float(weapons["broadsword"].get("damage_multiplier")):
			failures.append("A broadsword should hit harder than a cutlass.")

	var profiles := ContentCatalog.load_duel_profiles()
	if profiles.is_empty():
		failures.append("Duel profiles should define at least one opponent archetype.")
	# Faction outranks ship type, and an unknown pairing must still find a captain.
	if DuelContextScript.captain_profile_id("pirates", "galleon") != "pirate_captain":
		failures.append("A pirate crew should field a pirate captain even on a galleon.")
	if DuelContextScript.captain_profile_id("spain", "galleon") != "galleon_master":
		failures.append("A galleon with no faction-specific captain should field the galleon archetype.")
	if DuelContextScript.captain_profile_id("nowhere", "raft").is_empty():
		failures.append("Captain assignment should always fall back to a default archetype.")

	# The weapon table must actually reach the fight.
	for weapon_id in ["cutlass", "broadsword"]:
		var controller: Node = _make_duel(weapon_id)
		_settle_duel(controller)
		controller.submit_player_action(DuelActionScript.CHOP)
		var windup := float(controller.get_fighter("player").get("state_duration"))
		var expected := float(controller.timing.get("attack_windup")) * float(weapons[weapon_id].get("windup_multiplier"))
		if not is_equal_approx(windup, expected):
			failures.append("Duel wind-up should follow the chosen weapon (%s)." % weapon_id)
		controller.free()


func _test_game_difficulty(failures: Array[String]) -> void:
	var levels := ContentCatalog.load_difficulty_levels()
	for required in ["easy", "normal", "hard", "brutal"]:
		if not levels.has(required):
			failures.append("Difficulty levels should include '%s'." % required)
	if not levels.has("easy") or not levels.has("hard"):
		return

	# Difficulty is a game-wide setting with a section per consuming system, so
	# that naval combat, land battles, and overworld spawning can join without
	# reshaping it (user call 2026-08-17).
	for level_id in levels:
		if not levels[level_id].get("duel") is Dictionary:
			failures.append("Difficulty level '%s' should carry a duel section." % level_id)
	if ContentCatalog.load_difficulty_section("normal", "duel").is_empty():
		failures.append("The normal level should expose duel tuning.")
	if not ContentCatalog.load_difficulty_section("normal", "not_a_system").is_empty():
		failures.append("An unwritten difficulty section should come back empty, not fail.")
	if GameDifficultyScript.current_id().is_empty():
		failures.append("GameDifficulty should always resolve a level, defaulting to normal.")
	if GameDifficultyScript.section("duel").is_empty():
		failures.append("GameDifficulty should expose the current level's duel tuning.")
	if not is_equal_approx(GameDifficultyScript.value("not_a_system", "whatever", 3.5), 3.5):
		failures.append("Reading an unwritten difficulty value should return the caller's default.")

	var easy: Dictionary = levels["easy"].get("duel", {})
	var hard: Dictionary = levels["hard"].get("duel", {})
	if not float(easy.get("attack_pause_slow")) > float(hard.get("attack_pause_slow")):
		failures.append("Easier levels should leave longer gaps between attacks.")
	if not float(easy.get("punish_chance")) < float(hard.get("punish_chance")):
		failures.append("Easier levels should take fewer free openings.")
	if not float(easy.get("punish_delay")) > float(hard.get("punish_delay")):
		failures.append("Easier levels should wait longer before punishing an opening.")
	if not float(easy.get("read_accuracy_multiplier")) < float(hard.get("read_accuracy_multiplier")):
		failures.append("Easier levels should read attacks less well.")

	# The level must actually reach the fighter, and only the opponent.
	var gentle: Node = _make_duel("longsword", {}, {"difficulty_id": "easy"})
	var fierce: Node = _make_duel("longsword", {}, {"difficulty_id": "brutal"})
	var gentle_opponent: Dictionary = gentle.get_fighter("opponent").get("data", {})
	var fierce_opponent: Dictionary = fierce.get_fighter("opponent").get("data", {})
	if not float(gentle_opponent.get("vigor")) < float(fierce_opponent.get("vigor")):
		failures.append("A harder level should field a captain with more vigor.")
	if not float(gentle_opponent.get("reaction_time")) > float(fierce_opponent.get("reaction_time")):
		failures.append("A harder level should field a captain who reacts faster.")
	if not float(gentle_opponent.get("read_accuracy")) < float(fierce_opponent.get("read_accuracy")):
		failures.append("A harder level should field a captain who reads attacks better.")
	if not is_equal_approx(float(gentle.get_fighter("player").get("max_vigor")), float(fierce.get_fighter("player").get("max_vigor"))):
		failures.append("Difficulty must scale the opponent only, never the player.")
	gentle.free()
	fierce.free()


# The complaint that produced the difficulty pass (playtest 2026-08-17): the
# opponent attacked again the moment you were hit, so the next wind-up played
# out while you were still staggered and could not answer it. Normal difficulty
# must always let you back on your feet before it begins a tell.
func _test_duel_pacing_is_readable(failures: Array[String]) -> void:
	var controller: Node = DuelControllerScript.new()
	controller.configure(DuelContextScript.create({
		"rng_seed": 90210,
		"difficulty_id": "normal",
		# A punching bag with enough vigor to survive the whole sample.
		"player": {"name": "You", "vigor": 100000.0, "weapon": "longsword"},
		"opponent": DuelContextScript.fighter_from_profile("naval_officer", {"pistol": false})
	}))
	controller.start("longsword")

	var attack_starts: Array[float] = []
	var unreadable := 0
	var elapsed := 0.0
	var was_winding_up := false
	for index in range(60 * 60):
		controller.advance(DUEL_STEP)
		elapsed += DUEL_STEP
		var opponent: Dictionary = controller.get_fighter("opponent")
		var winding_up: bool = str(opponent.get("state")) == controller.STATE_WINDUP
		if winding_up and not was_winding_up:
			attack_starts.append(elapsed)
			if str(controller.get_fighter("player").get("state")) == controller.STATE_STAGGER:
				unreadable += 1
		was_winding_up = winding_up
	controller.free()

	if attack_starts.size() < 2:
		failures.append("The duel opponent should press the attack on its own.")
		return
	if unreadable > 0:
		failures.append("On normal, no attack should begin while the player is still staggered (%d did)." % unreadable)

	var total_gap := 0.0
	for index in range(1, attack_starts.size()):
		total_gap += attack_starts[index] - attack_starts[index - 1]
	var average_gap := total_gap / float(attack_starts.size() - 1)
	if average_gap < 1.6:
		failures.append("Normal difficulty attacks too rapidly in succession (average gap %.2fs)." % average_gap)


# Playtest 2026-08-17: the opponent stopped defending entirely — you could hit
# him repeatedly without trying. His reaction time was measured against the
# player's wind-up, and nothing kept it inside one, so a fast weapon or a weary
# captain meant the reaction never fired and no answer was ever attempted.
# Softening a crew switched their captain's defence off instead of weakening it.
func _test_duel_opponent_always_answers(failures: Array[String]) -> void:
	var cases := [
		{"weapon": "cutlass", "reaction": 0.35, "label": "a fast blade"},
		{"weapon": "cutlass", "reaction": 0.9, "label": "a fast blade against a weary captain"},
		{"weapon": "longsword", "reaction": 0.9, "label": "a weary captain"},
		{"weapon": "broadsword", "reaction": 1.4, "label": "an exhausted captain"}
	]
	for case in cases:
		var controller: Node = DuelControllerScript.new()
		controller.configure(DuelContextScript.create({
			"rng_seed": 5150,
			"difficulty_id": "normal",
			"player": {"name": "You", "vigor": 100000.0, "weapon": str(case["weapon"])},
			"opponent": {
				"name": "Captain",
				"vigor": 100000.0,
				"weapon": "longsword",
				"reaction_time": float(case["reaction"]),
				"read_accuracy": 0.5,
				"aggression": 0.1
			}
		}))
		controller.start(str(case["weapon"]))

		var evades := 0
		var was_state := ""
		for index in range(60 * 30):
			controller.advance(DUEL_STEP)
			var opponent_state := str(controller.get_fighter("opponent").get("state"))
			if opponent_state != was_state:
				if opponent_state == controller.STATE_EVADE:
					evades += 1
				was_state = opponent_state
			if str(controller.get_fighter("player").get("state")) == controller.STATE_READY:
				controller.submit_player_action(DuelActionScript.THRUST)
		controller.free()

		if evades <= 0:
			failures.append("The duel opponent never attempted a defence against %s; a tell must always be answerable." % str(case["label"]))


func _test_duel_exchange_rules(failures: Array[String]) -> void:
	for attack in DuelActionScript.ATTACKS:
		var correct := DuelActionScript.counter_for(attack)
		for evasion in DuelActionScript.EVASIONS:
			var controller: Node = _make_duel("longsword")
			_settle_duel(controller)
			controller.submit_opponent_action(attack)
			# Answer a beat after the tell, the way a player reacting to it would.
			_advance_duel(controller, 0.2)
			controller.submit_player_action(evasion)
			_advance_duel(controller, 1.5)
			var unhurt: bool = is_equal_approx(controller.get_vigor_fraction("player"), 1.0)
			if evasion == correct and not unhurt:
				failures.append("%s should be turned aside by %s." % [attack, evasion])
			if evasion != correct and unhurt:
				failures.append("%s should land against a fighter who guessed %s." % [attack, evasion])
			controller.free()

	# Being wrong-footed must cost more than simply standing still, or guessing
	# would be strictly better than not guessing.
	var flat_footed: Node = _make_duel("longsword")
	_settle_duel(flat_footed)
	flat_footed.submit_opponent_action(DuelActionScript.CHOP)
	_advance_duel(flat_footed, 1.5)
	var clean_damage: float = 1.0 - flat_footed.get_vigor_fraction("player")
	flat_footed.free()

	var wrong_guard: Node = _make_duel("longsword")
	_settle_duel(wrong_guard)
	wrong_guard.submit_opponent_action(DuelActionScript.CHOP)
	_advance_duel(wrong_guard, 0.2)
	wrong_guard.submit_player_action(DuelActionScript.JUMP)
	_advance_duel(wrong_guard, 1.5)
	var wrong_damage: float = 1.0 - wrong_guard.get_vigor_fraction("player")
	wrong_guard.free()

	if not wrong_damage > clean_damage:
		failures.append("A wrong evasion should hurt more than no evasion at all.")


func _test_duel_pistol_rules(failures: Array[String]) -> void:
	var controller: Node = _make_duel("longsword")
	_settle_duel(controller)
	if not controller.can_use_pistol("player"):
		failures.append("A fighter given a pistol should start the duel able to fire it.")
	controller.submit_player_action(DuelActionScript.PISTOL)
	_advance_duel(controller, 2.0)
	if is_equal_approx(controller.get_vigor_fraction("opponent"), 1.0):
		failures.append("An unopposed pistol shot should wound the opponent.")
	if controller.can_use_pistol("player"):
		failures.append("The pistol is a single shot and must be spent after firing.")
	controller.free()

	# Taking a hit mid-draw spoils the shot: that risk is the whole reason the
	# timing of the shot is a decision.
	var spoiled: Node = _make_duel("longsword")
	_settle_duel(spoiled)
	spoiled.submit_player_action(DuelActionScript.PISTOL)
	spoiled.advance(DUEL_STEP)
	spoiled.submit_opponent_action(DuelActionScript.THRUST)
	_advance_duel(spoiled, 2.0)
	if not is_equal_approx(spoiled.get_vigor_fraction("opponent"), 1.0):
		failures.append("A pistol spoiled by a hit during the draw should do no damage.")
	if spoiled.can_use_pistol("player"):
		failures.append("A spoiled pistol shot should still be spent.")
	spoiled.free()

	var unarmed: Node = _make_duel("longsword", {"pistol": false})
	_settle_duel(unarmed)
	if unarmed.can_use_pistol("player"):
		failures.append("A fighter whose context gives no pistol must not have one.")
	unarmed.free()


# The crews fight while their captains do, either can be wiped out, and a wipe
# decides the action (user call 2026-08-17). The duel itself stays ignorant of
# what these forces are — it only knows two sides have people fighting for them.
func _test_duel_support_melee(failures: Array[String]) -> void:
	# A straight duel with nobody else on the floor must behave exactly as
	# before, so tavern brawls and story duels are unaffected.
	var solo: Node = _make_duel("longsword")
	if solo.has_support():
		failures.append("A duel given no supporting forces should have none.")
	solo.free()

	# Numbers decide the melee when the captains are evenly matched.
	var melee: Node = _make_melee_duel(70.0, 30.0)
	_advance_duel(melee, 12.0)
	if not melee.get_support_count("opponent") < melee.get_support_count("player"):
		failures.append("The outnumbered side should be losing the melee.")
	if not melee.get_support_count("player") < 70.0:
		failures.append("Both sides should take losses in a melee.")
	melee.free()

	# A landed blow costs the other side men on the spot: the coupling that
	# keeps the duel and the melee one fight rather than two.
	var coupled: Node = _make_melee_duel(50.0, 50.0)
	_settle_duel(coupled)
	var before: float = coupled.get_support_count("opponent")
	coupled.submit_player_action(DuelActionScript.THRUST)
	var windup := float(coupled.timing.get("attack_windup", 0.58))
	_advance_duel(coupled, windup + 0.05)
	var after: float = coupled.get_support_count("opponent")
	# Attrition alone over that span is far smaller than the burst from a hit.
	if not before - after > float(coupled.support_rules.get("hit_burst", 1.2)) * 0.8:
		failures.append("A landed blow should cost the losing side men immediately.")
	coupled.free()

	# A wipe ends the action, and says so.
	var rout: Node = _make_melee_duel(90.0, 6.0)
	var finished := {"result": {}}
	rout.duel_finished.connect(func(result): finished["result"] = result)
	_advance_duel(rout, 40.0)
	var result: Dictionary = finished["result"]
	if result.is_empty():
		failures.append("Wiping out a supporting force should end the duel.")
	else:
		if str(result.get("reason")) != DuelContextScript.REASON_SUPPORT_LOST:
			failures.append("A duel decided by the melee should report why.")
		if str(result.get("outcome")) != DuelContextScript.OUTCOME_PLAYER_WIN:
			failures.append("Wiping out the enemy's force should be a player win.")
		var support: Dictionary = result.get("support", {})
		if not float(support.get("opponent", {}).get("remaining", 1.0)) <= 0.0:
			failures.append("A broken force should report nobody left standing.")
		if not float(support.get("player", {}).get("losses", 0.0)) > 0.0:
			failures.append("The winning side should still report its own losses.")
	rout.free()

	# And the same in reverse: your own force being wiped loses the action.
	var overrun: Node = _make_melee_duel(6.0, 90.0)
	var lost := {"result": {}}
	overrun.duel_finished.connect(func(result): lost["result"] = result)
	_advance_duel(overrun, 40.0)
	if str(lost["result"].get("outcome", "")) != DuelContextScript.OUTCOME_PLAYER_LOSS:
		failures.append("Losing your own supporting force should lose the duel.")
	overrun.free()


func _make_melee_duel(player_count: float, opponent_count: float) -> Node:
	var controller: Node = DuelControllerScript.new()
	controller.configure(DuelContextScript.create({
		"rng_seed": 24601,
		"difficulty_id": "normal",
		# Captains who cannot finish each other, so the melee is what is measured.
		"player": {"name": "You", "vigor": 100000.0, "weapon": "longsword"},
		"opponent": {"name": "Captain", "vigor": 100000.0, "weapon": "longsword", "aggression": 0.0, "reaction_time": 9.0},
		"support": {
			"player": {"label": "Ours", "count": player_count, "strength": 1.0},
			"opponent": {"label": "Theirs", "count": opponent_count, "strength": 1.0}
		}
	}))
	controller.opponent_brain_enabled = false
	controller.start("longsword")
	return controller


func _test_duel_result_contract(failures: Array[String]) -> void:
	var payload := {"kind": "smoke_test", "token": 4321}
	var controller: Node = _make_duel("longsword", {}, {"caller_payload": payload})
	var finished := {"result": {}}
	controller.duel_finished.connect(func(result): finished["result"] = result)
	_settle_duel(controller)

	var opponent: Dictionary = controller.get_fighter("opponent")
	opponent["vigor"] = 1.0
	controller.submit_player_action(DuelActionScript.THRUST)
	_advance_duel(controller, 4.0)

	var result: Dictionary = finished["result"]
	if result.is_empty():
		failures.append("A duel that reaches zero vigor should report a result.")
		controller.free()
		return
	for key in DuelContextScript.RESULT_KEYS:
		if not result.has(key):
			failures.append("Duel result is missing contract key '%s'." % key)
	if str(result.get("outcome")) != DuelContextScript.OUTCOME_PLAYER_WIN:
		failures.append("Beating the opponent to zero vigor should be a player win.")
	# The opaque payload is how callers route a result without the duel knowing
	# anything about them; it must come back untouched.
	if result.get("caller_payload") != payload:
		failures.append("Duel result should echo the caller payload verbatim.")
	controller.free()


func _test_duel_arena_overlay(failures: Array[String]) -> void:
	var packed := load(SWORD_DUEL_SCENE_PATH)
	if packed == null:
		failures.append("Could not load the sword duel scene.")
		return
	var arena: Node = packed.instantiate()
	arena.set("autostart_demo", false)
	arena.set("result_hold", 0.0)
	root.add_child(arena)
	await process_frame

	var was_paused := root.get_tree().paused
	arena.call("begin", DuelContextScript.create({
		"weapon_choices": ["longsword"],
		"opponent": DuelContextScript.fighter_from_profile("naval_officer")
	}))
	await process_frame

	if arena.get_node_or_null("PlayerFighter") == null or arena.get_node_or_null("OpponentFighter") == null:
		failures.append("The duel arena should build both fighters.")
	if arena.get_node_or_null("DuelCamera") == null:
		failures.append("The duel arena should bring its own camera.")
	if arena.get_node_or_null("DuelHudLayer/DuelHud") == null:
		failures.append("The duel arena should build its HUD.")
	if arena.get_node_or_null("Stage") == null:
		failures.append("The duel arena should build its deck stage.")
	if not root.get_tree().paused:
		failures.append("The duel overlay should pause the caller's world while it runs.")

	# Abandoning is the caller's escape hatch, and it must hand the world back.
	arena.get("controller").call("abandon")
	await process_frame
	await process_frame
	if root.get_tree().paused != was_paused:
		failures.append("The duel overlay must restore the caller's pause state when it ends.")
		root.get_tree().paused = was_paused
	if is_instance_valid(arena):
		arena.free()


# Ships stopped each other physically but nothing came of it (playtest
# 2026-08-17). Running into someone should hurt — and coming gently alongside
# to board should not, or boarding would be impossible.
func _test_ship_collisions(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "ship collisions")
	if scene == null:
		return
	var collisions := scene.get_node_or_null("ShipCollisionSystem")
	var player := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	if collisions == null:
		failures.append("The naval battle should resolve ship-on-ship collisions.")
		_free_scene(scene)
		return
	if player == null or target == null:
		failures.append("Collision test needs both ships.")
		_free_scene(scene)
		return

	target.set("movement_enabled", false)
	# Hull to hull, both dead in the water: a touch, not a ram.
	target.global_position = player.global_position + _hull_contact_offset(player, target)
	player.set("velocity", Vector3.ZERO)
	target.set("velocity", Vector3.ZERO)
	var hull_before := float(player.get("hull"))
	await physics_frame
	await physics_frame
	if not is_equal_approx(float(player.get("hull")), hull_before):
		failures.append("Touching hulls at matched speed should not damage a ship, or boarding would be impossible.")

	# Now drive into her.
	var enemy_hull_before := float(target.get("hull"))
	var player_hull_before := float(player.get("hull"))
	var camera := scene.get_node_or_null("Camera3D")
	var trauma_before := float(camera.get("trauma")) if camera else 0.0
	var debris_before := player.get_parent().get_children().size()
	var damage: Dictionary = collisions.call("resolve_impact", 4.0)
	# A crash the player can feel: the camera shakes and timber flies.
	if camera and not float(camera.get("trauma")) > trauma_before:
		failures.append("A hull collision should shake the camera.")
	if not player.get_parent().get_children().size() > debris_before:
		failures.append("A hull collision should throw splinters.")
	if not float(target.get("hull")) < enemy_hull_before:
		failures.append("Ramming should damage the ship being rammed.")
	if not float(player.get("hull")) < player_hull_before:
		failures.append("Ramming should damage the ship doing the ramming too.")

	# The smaller ship always comes off worse, so ramming a galleon in a sloop
	# is a mistake rather than a tactic.
	var player_scale := player.scale.x
	var target_scale := target.scale.x
	if not is_equal_approx(player_scale, target_scale):
		var smaller_took_more: bool = float(damage["player"]) > float(damage["target"]) if player_scale < target_scale else float(damage["target"]) > float(damage["player"])
		if not smaller_took_more:
			failures.append("The smaller ship should take the worse of a collision.")

	_free_scene(scene)


func _hull_contact_offset(player: Node3D, target: Node3D) -> Vector3:
	var direction := Vector3.RIGHT
	return direction * (ShipGeometryScript.hull_radius(player, direction) + ShipGeometryScript.hull_radius(target, -direction) - 0.05)


func _test_boarding_availability(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "boarding availability")
	if scene == null:
		return
	var boarding := scene.get_node_or_null("BoardingController")
	var player := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	if boarding == null:
		failures.append("The naval battle should include a BoardingController.")
		_free_scene(scene)
		return
	if scene.get_node_or_null("Debug/BoardingPrompt") == null:
		failures.append("The naval battle should show a boarding prompt.")
	# This test is about when the PLAYER may board; the enemy taking the
	# initiative is covered separately.
	boarding.set("enabled", true)
	boarding.set("enemy_boarding_enabled", false)
	if player == null or target == null:
		failures.append("Boarding test needs both ships.")
		_free_scene(scene)
		return

	target.set("movement_enabled", false)
	target.global_position = player.global_position + Vector3(90.0, 0.0, 0.0)
	target.set("velocity", Vector3.ZERO)
	player.set("velocity", Vector3.ZERO)
	await process_frame
	if bool(boarding.get("is_available")):
		failures.append("Boarding should not be offered from across the battle.")
	if str(boarding.get("block_reason")) != boarding.BLOCK_DISTANCE:
		failures.append("A distant enemy should report a distance block reason.")

	# Alongside and matching her speed: boarding is offered regardless of how
	# fresh their crew is (user call 2026-08-17).
	target.global_position = player.global_position + _alongside_offset(boarding, player, target)
	player.set("velocity", Vector3.ZERO)
	target.set("velocity", Vector3.ZERO)
	await process_frame
	if not bool(boarding.get("is_available")):
		failures.append("Boarding should be offered alongside a stationary enemy, got '%s'." % str(boarding.get("block_reason")))

	# Ranging past her at speed is not a boarding.
	player.set("velocity", Vector3(0.0, 0.0, 40.0))
	await process_frame
	if bool(boarding.get("is_available")):
		failures.append("Boarding should not be offered while closing far too fast.")

	_free_scene(scene)


# The enemy can come for you too (user call 2026-08-17), and when they do the
# crews swap roles: you defend your own deck with everyone aboard.
func _test_enemy_initiated_boarding(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "enemy boarding")
	if scene == null:
		return
	var boarding := scene.get_node_or_null("BoardingController")
	var player := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	if boarding == null or player == null or target == null:
		failures.append("Enemy boarding test needs the battle scene wired up.")
		_free_scene(scene)
		return

	var session := root.get_node_or_null("GameSession")
	var previous_difficulty := str(session.get("game_difficulty")) if session else "normal"
	# Brutal always takes the opportunity, so the test does not ride on a roll.
	if session:
		session.set("game_difficulty", "brutal")
	boarding.set("enabled", true)
	boarding.set("enemy_boarding_enabled", true)
	target.set("movement_enabled", false)
	target.global_position = player.global_position + _alongside_offset(boarding, player, target)
	player.set("velocity", Vector3.ZERO)
	target.set("velocity", Vector3.ZERO)
	await process_frame
	await process_frame

	if not bool(boarding.get("is_boarding")):
		failures.append("An enemy that wants to board should grapple when alongside.")
	elif str(boarding.get("initiator")) != "enemy":
		failures.append("A boarding the enemy started should record them as the initiator.")

	var context: Dictionary = boarding.call("build_duel_context")
	var support: Dictionary = context.get("support", {})
	if str(context.get("title", "")) == "BOARDING ACTION":
		failures.append("Being boarded should not be framed as boarding them.")
	if not float(support.get("player", {}).get("strength", 0.0)) > float(support.get("opponent", {}).get("strength", 99.0)):
		failures.append("Defending your own deck should be the stronger side of the melee.")
	if not is_equal_approx(float(support.get("player", {}).get("count", 0.0)), float(player.get("crew"))):
		failures.append("Defending your own ship should field the whole crew, not a boarding party.")
	if not float(support.get("opponent", {}).get("count", 0.0)) < float(target.get("crew")):
		failures.append("Enemy boarders should be a party, leaving hands aboard their ship.")

	if session:
		session.set("game_difficulty", previous_difficulty)
	_free_scene(scene)


func _test_boarding_consequences(failures: Array[String]) -> void:
	var scene := await _instantiate_main_scene(failures, "boarding consequences")
	if scene == null:
		return
	var boarding := scene.get_node_or_null("BoardingController")
	var player := scene.get_node_or_null("PlayerShip")
	var target := scene.get_node_or_null("TargetShip")
	if boarding == null or player == null or target == null:
		failures.append("Boarding consequence test needs the battle scene wired up.")
		_free_scene(scene)
		return

	# A battered crew must field a weaker captain than a fresh one: this is the
	# entire payoff for softening them with grape shot first.
	var fresh_context: Dictionary = boarding.call("build_duel_context")
	# Soften them hard, but leave hands aboard: a crew already at zero cannot
	# show that a boarding costs the loser more of them.
	target.call("apply_crew_damage", float(target.get("crew")) * 0.75)
	target.call("apply_morale_damage", float(target.get("morale")) * 0.7)
	var battered_context: Dictionary = boarding.call("build_duel_context")
	var fresh: Dictionary = fresh_context.get("opponent", {})
	var battered: Dictionary = battered_context.get("opponent", {})
	if not float(battered.get("vigor")) < float(fresh.get("vigor")):
		failures.append("A battered crew should field a captain with less vigor.")
	if not float(battered.get("reaction_time")) > float(fresh.get("reaction_time")):
		failures.append("A weary captain should react more slowly.")
	if not float(battered.get("read_accuracy")) < float(fresh.get("read_accuracy")):
		failures.append("A weary captain should read attacks less well.")
	if str(fresh_context.get("caller_payload", {}).get("kind", "")) != "naval_boarding":
		failures.append("Boarding should tag its duel context so results can be routed.")

	# Crews fight alongside their captains, so the duel context must carry them.
	var support: Dictionary = battered_context.get("support", {})
	if support.is_empty():
		failures.append("A boarding should send both crews into the duel as supporting forces.")
	else:
		var party := float(support.get("player", {}).get("count", 0.0))
		var crew := float(player.get("crew"))
		if not (party > 0.0 and party < crew):
			failures.append("The boarding party should be part of the crew, not all of it (got %.1f of %.1f)." % [party, crew])
		if not float(support.get("opponent", {}).get("count", 0.0)) > 0.0:
			failures.append("The defending crew should be sent into the duel.")
		if not float(support.get("opponent", {}).get("strength", 0.0)) > float(support.get("player", {}).get("strength", 0.0)):
			failures.append("Defenders should fight slightly better on their own deck.")

	# Winning takes the ship without sinking her, and both crews pay what the
	# melee actually cost them rather than a flat percentage.
	var enemy_crew_before := float(target.get("crew"))
	var player_crew_before := float(player.get("crew"))
	boarding.call("_on_duel_finished", {
		"outcome": DuelContextScript.OUTCOME_PLAYER_WIN,
		"reason": DuelContextScript.REASON_CAPTAIN_YIELDED,
		"support": {
			"player": {"starting": 40.0, "remaining": 31.0, "losses": 9.0},
			"opponent": {"starting": 30.0, "remaining": 12.0, "losses": 18.0}
		},
		"caller_payload": {}
	})
	if not is_equal_approx(player_crew_before - float(player.get("crew")), 9.0):
		failures.append("The winner should lose exactly the hands the melee cost them.")
	if not bool(target.get("has_struck_colors")):
		failures.append("Winning the boarding duel should make the enemy strike her colours.")
	if bool(target.get("is_sunk")):
		failures.append("A captured ship should not be sunk.")
	if not float(target.get("crew")) < enemy_crew_before:
		failures.append("A boarding should cost the losing side crew.")
	scene.call("_check_result")
	if str(scene.get("pending_result")) != "enemy_captured":
		failures.append("A won boarding should end the battle as a capture, got '%s'." % str(scene.get("pending_result")))
	_free_scene(scene)

	# Losing the duel is losing the battle (user call 2026-08-17).
	var lost_scene := await _instantiate_main_scene(failures, "boarding defeat")
	if lost_scene == null:
		return
	var lost_boarding := lost_scene.get_node_or_null("BoardingController")
	var lost_player := lost_scene.get_node_or_null("PlayerShip")
	if lost_boarding == null or lost_player == null:
		failures.append("Boarding defeat test needs the battle scene wired up.")
		_free_scene(lost_scene)
		return
	lost_boarding.call("_on_duel_finished", {
		"outcome": DuelContextScript.OUTCOME_PLAYER_LOSS,
		"reason": DuelContextScript.REASON_SUPPORT_LOST,
		"support": {
			"player": {"starting": 40.0, "remaining": 0.0, "losses": 40.0},
			"opponent": {"starting": 30.0, "remaining": 14.0, "losses": 16.0}
		},
		"caller_payload": {}
	})
	if not bool(lost_player.get("has_struck_colors")):
		failures.append("Losing the boarding duel should strike the player's colours.")
	lost_scene.call("_check_result")
	if str(lost_scene.get("pending_result")) != "player_defeated":
		failures.append("Losing a boarding duel should end the battle in defeat, got '%s'." % str(lost_scene.get("pending_result")))
	_free_scene(lost_scene)


# Duel helpers. The controller is deliberately drivable outside the scene tree,
# so these fights run deterministically with no frames and no visuals.
func _make_duel(weapon_id: String, player_overrides: Dictionary = {}, context_overrides: Dictionary = {}) -> Node:
	var controller: Node = DuelControllerScript.new()
	var player := {"name": "You", "vigor": 100.0, "weapon": weapon_id, "pistol": true}
	player.merge(player_overrides, true)
	var context := {
		"rng_seed": 20260817,
		"weapon_choices": [weapon_id],
		"player": player,
		"opponent": {"name": "Captain", "vigor": 100.0, "weapon": "longsword"}
	}
	context.merge(context_overrides, true)
	controller.configure(DuelContextScript.create(context))
	# Scripted opponent only: these tests are about the rules, not the brain.
	controller.opponent_brain_enabled = false
	controller.start(weapon_id)
	return controller


func _settle_duel(controller: Node) -> void:
	for index in range(240):
		controller.advance(DUEL_STEP)
		if str(controller.get_fighter("player").get("state")) == controller.STATE_READY:
			return


func _advance_duel(controller: Node, seconds: float) -> void:
	for index in range(int(seconds / DUEL_STEP)):
		controller.advance(DUEL_STEP)


func _disable_target_ai(scene: Node) -> void:
	var target := scene.get_node_or_null("TargetShip")
	if target:
		target.set("ai_enabled", false)
		target.set("firing_enabled", false)


# Lay the enemy alongside at half the boarding gap, measured off the actual
# hulls so the test does not depend on either ship's size.
func _alongside_offset(boarding: Node, player: Node3D, target: Node3D) -> Vector3:
	var direction := Vector3.RIGHT
	var separation: float = ShipGeometryScript.hull_radius(player, direction) \
		+ ShipGeometryScript.hull_radius(target, -direction) \
		+ float(boarding.call("get_alongside_gap")) * 0.5
	return direction * separation


func _disable_boarding(scene: Node) -> void:
	var boarding := scene.get_node_or_null("BoardingController")
	if boarding:
		boarding.set("enabled", false)


func _disable_battle_auto_return(scene: Node) -> void:
	if scene.has_method("_check_result") or scene.get("auto_return_to_overworld") != null:
		scene.set("auto_return_to_overworld", false)
