extends Node

# Disposable close-up probe for flag work: loads the battle scene, parks a
# camera near the player sloop's stern, then the target galleon's stern,
# saving frames of each. Run windowed (rendering required):
#   godot --path . res://tools/_FlagProbe.tscn ++ --out=C:/some/dir

var out_dir := "res://assets/temporary"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var packed: PackedScene = load("res://game/scenes/NavalBattle.tscn")
	var scene := packed.instantiate()
	scene.set("auto_return_to_overworld", false)
	add_child(scene)
	await get_tree().create_timer(2.0).timeout

	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()

	await _shoot_ship(camera, scene.get_node_or_null("PlayerShip"), "flagclose_player", 2.0, 6.0)
	var target: Node3D = scene.get_node_or_null("TargetShip")
	await _shoot_ship(camera, target, "flagclose_target", 5.0, 11.0)

	# Reuse the target hull to probe the classes no default scene spawns.
	var visuals := target.get_node_or_null("VisualRoot/ShipVisualBuilder")
	var catalog := preload("res://game/scripts/content/ContentCatalog.gd")
	for combo in [["frigate", "england", "flagclose_frigate"], ["brig", "dutch", "flagclose_brig"]]:
		var record := {"ship_type": combo[0], "faction": combo[1], "modifications": []}
		var stats: Resource = catalog.build_ship_stats(record, catalog.load_ship_types(), catalog.load_ship_modifications())
		visuals.call("apply_visuals", record, stats)
		await _shoot_ship(camera, target, combo[2], 3.5, 9.0)
	get_tree().quit()


func _shoot_ship(camera: Camera3D, ship: Node3D, prefix: String, aim_height: float, distance: float) -> void:
	if ship == null:
		push_error("_flag_probe: ship not found for %s" % prefix)
		return
	for index in range(3):
		# Re-aim every shot; the ship sails on between frames.
		var stern: Vector3 = ship.global_position + ship.global_transform.basis.z * 6.0
		camera.global_position = stern + Vector3(distance, distance * 0.9, distance)
		camera.look_at(ship.global_position + Vector3(0.0, aim_height, 0.0))
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s_%d.png" % [out_dir, prefix, index + 1]
		print("FlagProbe saved %s (error=%d)" % [path, image.save_png(path)])
