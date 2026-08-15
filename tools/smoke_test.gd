extends SceneTree

const NAVAL_BATTLE_SCENE_PATH := "res://game/scenes/NavalBattle.tscn"
const OVERWORLD_SCENE_PATH := "res://game/scenes/Overworld.tscn"
const SAILING_MODEL_PATH := "res://game/scripts/SailingModel.gd"
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

	if failures.is_empty():
		print("Smoke test passed: overworld scene, overworld encounters, encounter battle handoff, sailing, content, ship stats/mods, target ship config, ship loadouts, broadside behavior, enemy fire, ammo cooldown, projectile splash, impact flash, armament damage, sail/crew/morale damage, mast break, crew firing limits, target AI test toggles, burning, self-ignition, magazine explosion, sinking, and target damage.")
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
		if player_flag == null or player_flag.mesh.get_aabb().size.x < 1.0:
			failures.append("Player flag should be large enough to read from the battle camera.")
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

	var port_range: float = broadside.call("_get_side_max_range", -1)
	var starboard_range: float = broadside.call("_get_side_max_range", 1)
	if not starboard_range > port_range:
		failures.append("Starboard mixed long-cannon loadout should outrange port.")

	var port_reload: float = broadside.call("_get_side_reload_time", -1)
	var starboard_reload: float = broadside.call("_get_side_reload_time", 1)
	if not starboard_reload > port_reload:
		failures.append("Starboard mixed long-cannon loadout should reload slower than port.")

	var port_weight: float = broadside.call("_get_side_weight", -1)
	var starboard_weight: float = broadside.call("_get_side_weight", 1)
	if not starboard_weight > port_weight:
		failures.append("Starboard mixed long-cannon loadout should weigh more than port.")

	var total_weight: float = broadside.call("get_total_cannon_weight")
	if not is_equal_approx(total_weight, port_weight + starboard_weight):
		failures.append("Total cannon weight should equal port plus starboard cannon weight.")

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


func _disable_target_ai(scene: Node) -> void:
	var target := scene.get_node_or_null("TargetShip")
	if target:
		target.set("ai_enabled", false)
		target.set("firing_enabled", false)


func _disable_battle_auto_return(scene: Node) -> void:
	if scene.has_method("_check_result") or scene.get("auto_return_to_overworld") != null:
		scene.set("auto_return_to_overworld", false)
