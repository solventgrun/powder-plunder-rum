extends SceneTree

const MAIN_SCENE_PATH := "res://game/scenes/Main.tscn"
const SAILING_MODEL_PATH := "res://game/scripts/SailingModel.gd"
const ContentValidator := preload("res://game/scripts/content/ContentValidator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	_test_content_validation(failures)
	_test_sailing_model(failures)
	await _test_main_scene_moves_ship(failures)
	await _test_broadside_side_behavior(failures)
	await _test_ammo_switch_cooldown(failures)
	await _test_projectile_range_splash(failures)
	await _test_cannon_hits_target(failures)
	await _test_fire_status_effects(failures)
	await _test_target_sinks_at_zero_hull(failures)

	if failures.is_empty():
		print("Smoke test passed: sailing, content, broadside behavior, ammo cooldown, projectile splash, impact flash, burning, self-ignition, sinking, and target damage.")
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
