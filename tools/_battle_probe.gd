extends Node

# Dev tool: stages the real naval battle at close quarters and captures the two
# things that are hard to judge from numbers — a broadside going off, and two
# hulls actually colliding. Run windowed (rendering required):
#   godot --path . res://tools/_BattleProbe.tscn ++ --out=C:/some/dir

const ShipGeometryScript := preload("res://game/scripts/combat/ShipGeometry.gd")

var out_dir := "res://assets/temporary"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")

	var scene: Node = load("res://game/scenes/NavalBattle.tscn").instantiate()
	add_child(scene)
	scene.set("auto_return_to_overworld", false)
	await get_tree().create_timer(1.5).timeout

	var player := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	var broadside := player.get_node_or_null("BroadsideController")
	var boarding := scene.get_node_or_null("BoardingController")
	if boarding:
		boarding.set("enemy_boarding_enabled", false)
	target.set("ai_enabled", false)
	target.set("movement_enabled", false)
	target.set("firing_enabled", false)

	# Broadside range: close enough for both ships to fill the frame.
	target.global_position = player.global_position + Vector3(15.0, 0.0, -2.0)
	target.rotation.y = deg_to_rad(8.0)
	await get_tree().create_timer(1.2).timeout
	broadside.call("fire_starboard")
	await get_tree().create_timer(0.22).timeout
	await _snap("battle_broadside")
	await get_tree().create_timer(0.5).timeout
	await _snap("battle_smoke")

	# Again from a low cinematic angle with the HUD out of the way — the fixed
	# battle camera is too high and far for a shot worth looking at.
	for child in scene.get_children():
		if child is CanvasLayer or child is Control:
			child.set("visible", false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 55.0
	camera.make_current()
	var midpoint := (player.global_position + target.global_position) * 0.5
	camera.global_position = midpoint + Vector3(0.0, 4.2, 15.0)
	camera.look_at(midpoint + Vector3(0.0, 1.4, 0.0))
	await get_tree().create_timer(1.6).timeout
	broadside.call("fire_starboard")
	await get_tree().create_timer(0.26).timeout
	await _snap("battle_cinematic")

	# Now run into her, which until now did nothing at all.
	var direction := Vector3.RIGHT
	var contact: float = ShipGeometryScript.hull_radius(player, direction) + ShipGeometryScript.hull_radius(target, -direction)
	target.global_position = player.global_position + direction * (contact - 0.1)
	var impact := (player.global_position + target.global_position) * 0.5
	camera.global_position = impact + Vector3(0.0, 6.5, 19.0)
	camera.look_at(impact + Vector3(0.0, 1.0, 0.0))
	player.set("velocity", direction * 7.0)
	var hull_before := float(target.get("hull"))
	await get_tree().create_timer(0.18).timeout
	await _snap("battle_ram")
	print("Ram: enemy hull %.1f -> %.1f, player hull %.1f" % [hull_before, float(target.get("hull")), float(player.get("hull"))])

	get_tree().quit()


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, label]
	print("BattleProbe saved %s (error=%d)" % [path, image.save_png(path)])
