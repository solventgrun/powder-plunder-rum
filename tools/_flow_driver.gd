extends Node

# Disposable end-to-end driver for the front-end flow. Lives on the tree root
# rather than in the current scene, so it survives the scene changes it drives:
# main menu -> practice setup -> naval battle -> back to practice setup.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

var out_dir := "res://assets/temporary"
var failures: Array[String] = []


func _ready() -> void:
	run()


func run() -> void:
	get_tree().change_scene_to_file("res://game/scenes/MainMenu.tscn")
	await _settle()
	_expect(_scene_is("MainMenu"), "Boot should land on the main menu, got %s." % _scene_name())

	var practice_button := get_tree().current_scene.find_child("PracticeButton", true, false) as Button
	if practice_button == null:
		_expect(false, "Main menu is missing the practice button.")
		_finish()
		return
	practice_button.pressed.emit()
	await _settle()
	_expect(_scene_is("PracticeSetup"), "Practice button should open the setup screen, got %s." % _scene_name())

	var setup := get_tree().current_scene
	setup.player_editor.apply_record(_loadout("frigate", "long_12_pounder", 8, 120))
	setup.enemy_editor.apply_record(_loadout("brig", "long_9_pounder", 6, 80))
	await get_tree().process_frame
	_expect(not setup.begin_button.disabled, "A legal matchup should let the battle begin.")

	setup.begin_button.pressed.emit()
	await _settle(2.5)
	_expect(_scene_is("NavalBattle"), "Begin Battle should sail, got %s." % _scene_name())
	var player := get_tree().current_scene.get_node_or_null("PlayerShip")
	var enemy := get_tree().current_scene.get_node_or_null("TargetShip")
	_expect(player != null and str(player.get("ship_type_id")) == "frigate", "Player should sail the frigate built on the setup screen.")
	_expect(enemy != null and str(enemy.get("ship_type_id")) == "brig", "Enemy should sail the brig built on the setup screen.")
	await _snap("flow_1_practice_battle")

	# Escape breaks off a practice battle and hands the loadout back intact.
	var session := get_node_or_null("/root/GameSession")
	session.abandon_battle()
	await _settle()
	_expect(_scene_is("PracticeSetup"), "Breaking off a practice battle should return to the setup screen, got %s." % _scene_name())
	var restored: Dictionary = get_tree().current_scene.build_records()
	_expect(str(restored["player"].get("ship_type")) == "frigate", "The setup screen should still hold the loadout that just sailed.")
	await _snap("flow_2_back_at_setup")

	# And the campaign route still works from the same menu.
	session.return_to_main_menu()
	await _settle()
	get_tree().current_scene.find_child("StartGameButton", true, false).pressed.emit()
	await _settle(2.0)
	_expect(_scene_is("Overworld"), "Start Game should open the overworld, got %s." % _scene_name())

	# The campaign loop: a won battle reports to the after-action screen, and
	# what is decided there sails out onto the map with you.
	var galleon := _encounter("spanish_treasure_galleon")
	session.set("selected_encounter", galleon)
	session.finish_battle("enemy_captured", _capture_report(galleon))
	await _settle()
	_expect(_scene_is("AfterAction"), "A finished battle should report to the after-action screen, got %s." % _scene_name())
	await _snap("flow_3_after_action")

	var after := get_tree().current_scene
	after._on_fate_selected(after.FATE_CONSORT)
	await get_tree().process_frame
	after._on_confirm()
	await _settle(2.0)
	_expect(_scene_is("Overworld"), "Making sail should return to the overworld, got %s." % _scene_name())
	_expect((session.get("fleet") as Array).size() == 2, "The prize kept as a consort should be in the fleet.")
	var consorts: Array = get_tree().current_scene.get("consorts")
	_expect(consorts.size() == 1, "A consort should be sailing in company on the map, got %d." % consorts.size())
	await _settle(2.0)
	await _snap("flow_4_overworld_with_consort")
	_finish()


func _encounter(id: String) -> Dictionary:
	for record in ContentCatalog.load_overworld_ship_records():
		if str(record.get("id", "")) == id:
			return record
	return {}


func _capture_report(enemy: Dictionary) -> Dictionary:
	return {
		"result": "enemy_captured",
		"player": {
			"hull_fraction": 0.55, "sail_fraction": 0.72, "crew": 120.0, "morale": 48.0,
			"drunkenness": 0.0, "mast_broken": false,
			"disabled_cannons": {"port": 1, "starboard": 0},
			"disabled_gun_ports": {"port": 0, "starboard": 0}
		},
		"enemy": {
			"hull_fraction": 0.12, "sail_fraction": 0.3, "crew": 70.0, "morale": 3.0,
			"drunkenness": 0.0, "mast_broken": true,
			"disabled_cannons": {"port": 0, "starboard": 0},
			"disabled_gun_ports": {"port": 0, "starboard": 0}
		},
		"enemy_loadout": enemy.duplicate(true),
		"enemy_manifest": enemy.get("cargo", {}).duplicate(),
		"enemy_name": str(enemy.get("name", "Prize"))
	}


func _loadout(ship_type: String, cannon_id: String, per_side: int, crew: int) -> Dictionary:
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
		"broadsides": {"port": {"cannons": cannons}, "starboard": {"cannons": cannons.duplicate()}}
	}


func _settle(seconds: float = 0.6) -> void:
	await get_tree().create_timer(seconds).timeout


func _scene_name() -> String:
	var scene := get_tree().current_scene
	return scene.name if scene else "<none>"


func _scene_is(expected: String) -> bool:
	return _scene_name() == expected


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _snap(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("FlowProbe saved %s/%s.png (error=%d)" % [out_dir, prefix, image.save_png("%s/%s.png" % [out_dir, prefix])])


func _finish() -> void:
	if failures.is_empty():
		print("FlowProbe passed: menu -> practice setup -> battle -> setup -> menu -> overworld.")
	else:
		for failure in failures:
			print("FlowProbe FAILED: %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)
