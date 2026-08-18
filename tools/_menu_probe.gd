extends Node

# Disposable front-end layout probe: screenshots the main menu and the practice
# setup screen, including the setup screen carrying an invalid loadout so the
# fault report can be eyeballed. Run windowed:
#   godot --path . res://tools/_MenuProbe.tscn ++ --out=C:/some/dir

var out_dir := "res://assets/temporary"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")

	var menu := (load("res://game/scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await _snap("menu_1_main")
	menu.queue_free()
	await get_tree().process_frame

	var setup := (load("res://game/scenes/PracticeSetup.tscn") as PackedScene).instantiate()
	add_child(setup)
	await get_tree().process_frame
	await _snap("menu_2_practice_defaults")

	# Four light 4-pounders a side: inside a sloop's eight ports and 40 tons.
	setup.player_editor.apply_record(_sloop_with("light_4_pounder", 4))
	await get_tree().process_frame
	await _snap("menu_3_practice_legal")

	# Twelve long 12-pounders a side: 240 tons on a 40-ton hull, and three times
	# the gun ports she has.
	setup.player_editor.apply_record(_sloop_with("long_12_pounder", 12))
	await get_tree().process_frame
	await _snap("menu_4_practice_overloaded")
	get_tree().quit()


func _sloop_with(cannon_id: String, per_side: int) -> Dictionary:
	var cannons: Array = []
	for _index in range(per_side):
		cannons.append(cannon_id)
	return {
		"ship_type": "sloop",
		"faction": "pirates",
		"visual_variant": "worn",
		"sail_set": "full",
		"crew": 40,
		"cargo_weight": 0,
		"modifications": [],
		"broadsides": {"port": {"cannons": cannons}, "starboard": {"cannons": cannons.duplicate()}}
	}


func _snap(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, prefix]
	print("MenuProbe saved %s (error=%d)" % [path, image.save_png(path)])
