extends Node

# Disposable beauty-shot probe: loads the battle scene with the HUD hidden,
# then frames the target galleon for a hero three-quarter and a top-down.
# Run windowed (rendering required):
#   godot --path . res://tools/_HeroProbe.tscn ++ --out=C:/some/dir

var out_dir := "res://assets/temporary"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var packed: PackedScene = load("res://game/scenes/NavalBattle.tscn")
	var scene := packed.instantiate()
	scene.set("auto_return_to_overworld", false)
	add_child(scene)
	for child in scene.get_children():
		if child is CanvasLayer or child is Control:
			child.set("visible", false)
	await get_tree().create_timer(2.5).timeout

	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var ship: Node3D = scene.get_node_or_null("TargetShip")
	if ship == null:
		get_tree().quit(1)
		return

	for index in range(3):
		var bow: Vector3 = -ship.global_transform.basis.z.normalized()
		var right: Vector3 = ship.global_transform.basis.x.normalized()
		camera.global_position = ship.global_position + bow * 9.0 + right * 6.5 + Vector3.UP * 3.8
		camera.look_at(ship.global_position + Vector3.UP * 2.6)
		await _snap("galleon_hero_%d" % (index + 1))

	for index in range(3):
		var bow: Vector3 = -ship.global_transform.basis.z.normalized()
		camera.global_position = ship.global_position + Vector3.UP * 18.0
		camera.look_at(ship.global_position, bow)
		await _snap("galleon_topdown_%d" % (index + 1))

	# Transom inspection: straight astern and a stern quarter, framing the
	# sterncastle's aft face (2026-08-17 playtest: overlapping windows).
	var stern_right_offsets: Array[float] = [0.0, 3.5]
	for index in range(stern_right_offsets.size()):
		var stern_direction: Vector3 = ship.global_transform.basis.z.normalized()
		var right: Vector3 = ship.global_transform.basis.x.normalized()
		camera.global_position = ship.global_position + stern_direction * 8.5 + right * stern_right_offsets[index] + Vector3.UP * 4.6
		camera.look_at(ship.global_position + Vector3.UP * 3.2)
		await _snap("galleon_stern_%d" % (index + 1))
	get_tree().quit()


func _snap(prefix: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, prefix]
	print("HeroProbe saved %s (error=%d)" % [path, image.save_png(path)])
