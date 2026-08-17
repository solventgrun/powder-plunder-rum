extends SceneTree

# Disposable data probe: prints the battle target's speed and wake ribbon
# state so wake tuning rests on numbers, not screenshots alone.
#   godot --headless --path . --script res://tools/_wake_check.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://game/scenes/NavalBattle.tscn")
	var scene := packed.instantiate()
	scene.set("auto_return_to_overworld", false)
	root.add_child(scene)
	for _i in range(3):
		await process_frame
	var target := scene.get_node_or_null("TargetShip") as Node3D
	var wake := target.get_node_or_null("ShipWake")
	print("wake stern_point=", wake.get("stern_point"), " bow_point=", wake.get("bow_point"))
	for step in range(6):
		await create_timer(1.0).timeout
		var velocity: Vector3 = target.get("velocity") if target.get("velocity") is Vector3 else Vector3.ZERO
		var points: Array = wake.get("points")
		var strengths := []
		for point in points:
			strengths.append(snappedf(float(point.get("strength", 0.0)), 0.01))
		print("t=%d speed=%.2f points=%d strengths=%s" % [step + 1, velocity.length(), points.size(), str(strengths)])
		var ribbon: MeshInstance3D = wake.get("ribbon")
		var mesh: ImmediateMesh = wake.get("ribbon_mesh")
		print("   ribbon visible=%s in_tree=%s global=%s surfaces=%d aabb=%s ship=%s" % [
			ribbon.visible, ribbon.is_inside_tree(), ribbon.global_position,
			mesh.get_surface_count(), ribbon.get_aabb(), target.global_position])
	scene.queue_free()
	await process_frame
	quit(0)
