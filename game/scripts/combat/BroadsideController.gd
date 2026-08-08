extends Node
class_name BroadsideController

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var projectile_scene: PackedScene
@export var cannon_type_id: String = "light_4_pounder"
@export var default_ammo_id: String = "round"
@export_range(1, 8, 1) var cannonballs_per_broadside: int = 3
@export_range(0.1, 3.0, 0.05) var muzzle_spacing: float = 0.75
@export_range(0.0, 15.0, 0.5, "degrees") var spread_degrees: float = 4.0

var cannon_types: Dictionary = {}
var ammo_types: Dictionary = {}
var ammo_order: Array[String] = ["round", "chain", "grape", "fire"]
var selected_ammo_id: String = "round"
var port_cooldown: float = 0.0
var starboard_cooldown: float = 0.0


func _ready() -> void:
	cannon_types = ContentCatalog.load_cannon_types()
	ammo_types = ContentCatalog.load_ammo_types()
	selected_ammo_id = default_ammo_id
	if not ammo_types.has(selected_ammo_id) and not ammo_types.is_empty():
		selected_ammo_id = ammo_types.keys()[0]


func _process(delta: float) -> void:
	port_cooldown = maxf(0.0, port_cooldown - delta)
	starboard_cooldown = maxf(0.0, starboard_cooldown - delta)

	if Input.is_action_just_pressed("select_ammo_1"):
		select_ammo_by_index(0)
	if Input.is_action_just_pressed("select_ammo_2"):
		select_ammo_by_index(1)
	if Input.is_action_just_pressed("select_ammo_3"):
		select_ammo_by_index(2)
	if Input.is_action_just_pressed("select_ammo_4"):
		select_ammo_by_index(3)

	if Input.is_action_just_pressed("fire_port_broadside"):
		fire_port()
	if Input.is_action_just_pressed("fire_starboard_broadside"):
		fire_starboard()


func select_ammo_by_index(index: int) -> void:
	if index < 0 or index >= ammo_order.size():
		return

	var next_ammo_id := ammo_order[index]
	if next_ammo_id == selected_ammo_id or not ammo_types.has(next_ammo_id):
		return

	selected_ammo_id = next_ammo_id
	var reload_time: float = _get_cannon_type().get("reload_time")
	port_cooldown = maxf(port_cooldown, reload_time)
	starboard_cooldown = maxf(starboard_cooldown, reload_time)


func fire_port() -> bool:
	return _fire_side(-1)


func fire_starboard() -> bool:
	return _fire_side(1)


func get_debug_values() -> Dictionary:
	var cannon := _get_cannon_type()
	var ammo := _get_ammo_type()
	return {
		"cannon_name": cannon.get("display_name"),
		"ammo_name": ammo.get("display_name"),
		"port_cooldown": port_cooldown,
		"starboard_cooldown": starboard_cooldown
	}


func _fire_side(side: int) -> bool:
	if projectile_scene == null:
		return false
	if side < 0 and port_cooldown > 0.0:
		return false
	if side > 0 and starboard_cooldown > 0.0:
		return false

	var cannon := _get_cannon_type()
	var ammo := _get_ammo_type()
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return false

	for index in range(cannonballs_per_broadside):
		var projectile := projectile_scene.instantiate()
		var projectile_3d := projectile as Node3D
		if projectile_3d == null:
			projectile.queue_free()
			continue

		var center_offset := float(index) - float(cannonballs_per_broadside - 1) * 0.5
		var local_offset := Vector3(side * 1.05, 0.45, center_offset * muzzle_spacing)
		var basis := parent_3d.global_transform.basis
		var direction := (basis.x * side).normalized()
		var yaw := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
		direction = direction.rotated(Vector3.UP, yaw).normalized()

		var spawn_parent := get_tree().current_scene
		if spawn_parent == null:
			spawn_parent = parent_3d.get_parent()
		spawn_parent.add_child(projectile_3d)
		projectile_3d.global_position = parent_3d.global_position + basis * local_offset
		projectile_3d.call("configure", direction, cannon, ammo, parent_3d)

	var reload_time: float = cannon.get("reload_time")
	if side < 0:
		port_cooldown = reload_time
	else:
		starboard_cooldown = reload_time
	return true


func _get_cannon_type() -> Resource:
	if cannon_types.has(cannon_type_id):
		return cannon_types[cannon_type_id]
	return cannon_types.values()[0]


func _get_ammo_type() -> Resource:
	if ammo_types.has(selected_ammo_id):
		return ammo_types[selected_ammo_id]
	return ammo_types.values()[0]
