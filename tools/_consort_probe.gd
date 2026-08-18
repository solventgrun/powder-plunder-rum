extends Node

# Disposable diagnostic for consorts on the overworld: does a kept prize keep
# station on the flagship, and does she stop at the beach like everyone else?
# Sails the PLAYER under programmatic input straight at Jamaica and logs both
# ships every half second.
#   godot --path . res://tools/_ConsortProbe.tscn ++ --out=C:/some/dir

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var out_dir := "res://assets/temporary"
var overworld: Node
var player: Node3D
var consort: Node3D
var island_outline: PackedVector2Array
var max_gap := 0.0
var frames_on_land := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var session := get_node_or_null("/root/GameSession")
	var galleon := _encounter("spanish_treasure_galleon")
	var fleet: Array[Dictionary] = FleetScript.starting_fleet()
	var prize: Dictionary = galleon.duplicate(true)
	prize["faction"] = "pirates"
	prize.erase("route")
	fleet.append(FleetScript.make_ship(prize, "Nuestra Senora del Oro", "prize_1"))
	session.set("fleet", fleet)
	session.set("flagship_index", 0)
	session.set("practice_mode", false)

	overworld = (load("res://game/scenes/Overworld.tscn") as PackedScene).instantiate()
	add_child(overworld)
	await get_tree().process_frame
	await get_tree().physics_frame

	player = overworld.get("player")
	var consorts: Array = overworld.get("consorts")
	if consorts.is_empty():
		print("ConsortProbe FAILED: no consort spawned.")
		get_tree().quit(1)
		return
	consort = consorts[0]
	var island := overworld.get_node_or_null("JamaicaIsland")
	island_outline = island.call("get_outline_points") if island else PackedVector2Array()

	print("player scale %.2f, consort scale %.2f" % [player.scale.x, consort.scale.x])
	print("consort follow_offset %s -> station offset in world %s (motion_mode %d, expect 1=floating)" % [
		str(consort.get("follow_offset")),
		str(player.global_transform.basis.orthonormalized() * (consort.get("follow_offset") as Vector3)),
		consort.motion_mode])
	_diagnose_collision()
	print("")
	print("  t   player pos            consort pos           gap   on land")


# Decisive check on the island: are the layers even talking to each other, and
# does the physics server report a blocking hit for each ship?
func _diagnose_collision() -> void:
	var island := overworld.get_node_or_null("JamaicaIsland") as StaticBody3D
	print("island layer %d | player layer %d mask %d | consort layer %d mask %d" % [
		island.collision_layer, player.collision_layer, player.collision_mask,
		consort.collision_layer, consort.collision_mask])

	for ship in [player, consort] + (overworld.get("npc_ships") as Array):
		var shape_node := ship.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node == null:
			print("  %s has NO CollisionShape3D" % ship.name)
			continue
		print("  %s shape=%s disabled=%s local_scale=%s node_scale=%.2f world_y=%.2f half_h=%.2f" % [
			ship.name, shape_node.shape.get_class(), str(shape_node.disabled),
			str(shape_node.scale), ship.scale.y,
			shape_node.global_position.y,
			(shape_node.shape as BoxShape3D).size.y * 0.5 * shape_node.global_transform.basis.get_scale().y])

	# Park each ship just south of the island and push north into it.
	var probe_point := Vector3(10.0, 0.0, 40.0)
	for ship in [player, consort] + (overworld.get("npc_ships") as Array):
		var body := ship as CharacterBody3D
		var saved := body.global_transform
		var transform := saved
		transform.origin = probe_point
		var collision := KinematicCollision3D.new()
		var blocked := body.test_move(transform, Vector3(0.0, 0.0, -30.0), collision)
		print("  %s pushed 30 north from %s: %s" % [
			body.name, str(probe_point),
			("BLOCKED by %s" % collision.get_collider().name) if blocked else "PASSES THROUGH"])
		body.global_transform = saved

	# Sail north-west, straight at Jamaica.
	Input.action_press("trim_sails")
	await _sample(1.0)
	Input.action_release("trim_sails")
	Input.action_press("steer_port")
	await _sample(2.0)
	Input.action_release("steer_port")
	await _sample(14.0)
	await _snap("consort_1_after_chase")

	print("")
	print("worst gap %.1f, consort frames inside the island outline: %d" % [max_gap, frames_on_land])
	if frames_on_land > 0:
		print("ConsortProbe: SHE SAILS THROUGH THE ISLAND")
	if max_gap > 40.0:
		print("ConsortProbe: SHE IS NOT KEEPING STATION")
	get_tree().quit(0)


func _sample(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
		var gap := player.global_position.distance_to(consort.global_position)
		max_gap = maxf(max_gap, gap)
		var on_land := _inside_outline(Vector2(consort.global_position.x, consort.global_position.z))
		if on_land:
			frames_on_land += 1
		print("%5.1f  %-21s %-21s %5.1f  %s" % [
			elapsed, _pos(player), _pos(consort), gap, "YES" if on_land else "-"])


func _pos(node: Node3D) -> String:
	return "(%.1f,%.1f,y%.2f)" % [node.global_position.x, node.global_position.z, node.global_position.y]


func _inside_outline(point: Vector2) -> bool:
	if island_outline.size() < 3:
		return false
	var inside := false
	var count := island_outline.size()
	for index in range(count):
		var a := island_outline[index]
		var b := island_outline[(index + 1) % count]
		if ((a.y > point.y) != (b.y > point.y)) and (point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
	return inside


func _encounter(id: String) -> Dictionary:
	for record in ContentCatalog.load_overworld_ship_records():
		if str(record.get("id", "")) == id:
			return record
	return {}


func _snap(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("ConsortProbe saved %s/%s.png (error=%d)" % [out_dir, prefix, image.save_png("%s/%s.png" % [out_dir, prefix])])
