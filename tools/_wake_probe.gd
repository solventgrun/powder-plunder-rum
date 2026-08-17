extends Node

# Disposable wake probe: sails the PLAYER ship under programmatic input (the
# practice target only drifts at ~1 u/s and lays a stub trail hidden by its
# own hull) and photographs the wake on a straight run and mid-turn, framing
# off the velocity vector so model axis conventions can't lie to the camera.
# Run windowed (rendering required):
#   godot --path . res://tools/_WakeProbe.tscn ++ --out=C:/some/dir

var out_dir := "res://assets/temporary"
var camera: Camera3D
var ship: Node3D


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
	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	ship = scene.get_node_or_null("PlayerShip")
	if ship == null:
		get_tree().quit(1)
		return

	Input.action_press("trim_sails")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("trim_sails")
	# Straight run long enough for a full-lifetime trail.
	await get_tree().create_timer(6.0).timeout
	await _shot("wake_1_straight_astern", 16.0, 8.0)
	await _shot("wake_2_straight_topdown", 4.0, 26.0)
	Input.action_press("steer_starboard")
	await get_tree().create_timer(2.5).timeout
	Input.action_release("steer_starboard")
	await _shot("wake_3_turn_astern", 16.0, 8.0)
	await _shot("wake_4_turn_topdown", 4.0, 26.0)
	# Enemy wake: the AI galleon has been sailing this whole time; its trail
	# must read too (2026-08-17 playtest: "wakes should appear for all
	# vessels").
	var target: Node3D = get_node_or_null("NavalBattle/TargetShip")
	if target == null:
		target = ship.get_parent().get_node_or_null("TargetShip")
	if target:
		var keep := ship
		ship = target
		await _shot("wake_5_enemy_astern", 22.0, 10.0)
		await _shot("wake_6_enemy_topdown", 4.0, 30.0)
		ship = keep
	get_tree().quit()


func _shot(prefix: String, back: float, up: float) -> void:
	var velocity: Vector3 = ship.get("velocity") if ship.get("velocity") is Vector3 else Vector3.ZERO
	var forward := velocity.normalized() if velocity.length() > 0.1 else Vector3.FORWARD
	camera.global_position = ship.global_position - forward * back + Vector3.UP * up
	camera.look_at(ship.global_position - forward * minf(back * 0.5, 6.0))
	print("WakeProbe speed=%.2f at %s" % [velocity.length(), prefix])
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, prefix]
	print("WakeProbe saved %s (error=%d)" % [path, image.save_png(path)])
