extends SceneTree

const MAIN_SCENE_PATH := "res://game/scenes/Main.tscn"
const SAILING_MODEL_PATH := "res://game/scripts/SailingModel.gd"
const ContentValidator := preload("res://game/scripts/content/ContentValidator.gd")
const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	_test_content_validation(failures)
	_test_ship_stats(failures)
	_test_sailing_model(failures)
	await _test_main_scene_moves_ship(failures)
	await _test_broadside_side_behavior(failures)
	await _test_asymmetric_ship_loadout(failures)
	await _test_ammo_switch_cooldown(failures)
	await _test_projectile_range_splash(failures)
	await _test_cannon_hits_target(failures)
	await _test_fire_status_effects(failures)
	await _test_magazine_explosion(failures)
	await _test_target_sinks_at_zero_hull(failures)

	if failures.is_empty():
		print("Smoke test passed: sailing, content, ship stats/mods, target ship config, ship loadouts, broadside behavior, ammo cooldown, projectile splash, impact flash, burning, self-ignition, magazine explosion, sinking, and target damage.")
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


func _test_main_scene_moves_ship(failures: Array[String]) -> void:
	var packed := load(MAIN_SCENE_PATH)
	if packed == null:
		failures.append("Could not load main scene.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate main scene.")
		return

	root.add_child(scene)
	await process_frame
	await physics_frame

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
	var player_stats: Resource = ContentCatalog.load_player_ship_stats()
	var target_stats: Resource = ContentCatalog.load_target_ship_stats()
	if not is_equal_approx(ship.scale.x, float(player_stats.get("visual_scale"))):
		failures.append("Player ship scale should match configured ship type visual_scale.")
	if not is_equal_approx(target.scale.x, float(target_stats.get("visual_scale"))):
		failures.append("Target ship scale should match configured ship type visual_scale.")
	var player_hull := ship.get_node_or_null("Hull") as MeshInstance3D
	var target_hull := target.get_node_or_null("Hull") as MeshInstance3D
	var player_bow := ship.get_node_or_null("Bow") as MeshInstance3D
	var target_bow := target.get_node_or_null("Bow") as MeshInstance3D
	var player_mast := ship.get_node_or_null("Mast") as MeshInstance3D
	var target_mast := target.get_node_or_null("Mast") as MeshInstance3D
	if player_hull == null or target_hull == null or player_bow == null or target_bow == null or player_mast == null or target_mast == null:
		failures.append("Player and target ships should share the same primitive hull, bow, and mast parts.")
	else:
		var player_hull_size: Vector3 = player_hull.mesh.get_aabb().size
		var target_hull_size: Vector3 = target_hull.mesh.get_aabb().size
		if not player_hull_size.is_equal_approx(target_hull_size):
			failures.append("Same-type player and target ships should start from matching base hull dimensions.")

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
	var packed := load(MAIN_SCENE_PATH)
	if packed == null:
		failures.append("Could not load main scene for cannon test.")
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		failures.append("Could not instantiate main scene for cannon test.")
		return

	root.add_child(scene)
	await process_frame
	await physics_frame

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
	await process_frame
	if not target.get("is_sunk"):
		failures.append("Magazine explosion should sink/disable target immediately when forced.")
	if not _scene_has_child_named(scene, "MagazineExplosion"):
		failures.append("Magazine explosion should spawn primitive explosion visual.")

	_free_scene(scene)


func _instantiate_main_scene(failures: Array[String], test_name: String) -> Node:
	var packed := load(MAIN_SCENE_PATH)
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
	for child in scene.get_children():
		if child.name == child_name or child.name.begins_with("%s@" % child_name):
			return true
	return false
