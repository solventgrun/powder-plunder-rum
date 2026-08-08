extends Node
class_name BroadsideController

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const MuzzleFlashScene := preload("res://game/scenes/MuzzleFlash.tscn")

@export var projectile_scene: PackedScene
@export var default_ammo_id: String = "round"
@export_range(0.1, 3.0, 0.05) var muzzle_spacing: float = 0.75
@export_range(0.0, 15.0, 0.5, "degrees") var spread_degrees: float = 4.0

var cannon_types: Dictionary = {}
var ammo_types: Dictionary = {}
var ship_loadout: Dictionary = {}
var ammo_order: Array[String] = ["round", "chain", "grape", "fire"]
var selected_ammo_id: String = "round"
var port_cooldown: float = 0.0
var starboard_cooldown: float = 0.0


func _ready() -> void:
	cannon_types = ContentCatalog.load_cannon_types()
	ammo_types = ContentCatalog.load_ammo_types()
	ship_loadout = ContentCatalog.load_player_ship_loadout()
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

	var fire_port_pressed := Input.is_action_just_pressed("fire_port_broadside")
	var fire_starboard_pressed := Input.is_action_just_pressed("fire_starboard_broadside")
	if fire_port_pressed:
		fire_port()
	if fire_starboard_pressed:
		fire_starboard()


func select_ammo_by_index(index: int) -> void:
	if index < 0 or index >= ammo_order.size():
		return

	var next_ammo_id := ammo_order[index]
	if next_ammo_id == selected_ammo_id or not ammo_types.has(next_ammo_id):
		return

	selected_ammo_id = next_ammo_id
	port_cooldown = maxf(port_cooldown, _get_side_reload_time(-1))
	starboard_cooldown = maxf(starboard_cooldown, _get_side_reload_time(1))


func fire_port() -> bool:
	return _fire_side(-1)


func fire_starboard() -> bool:
	return _fire_side(1)


func get_debug_values() -> Dictionary:
	var ammo := _get_ammo_type()
	return {
		"ammo_name": ammo.get("display_name") if ammo else "No Ammo",
		"port_cooldown": port_cooldown,
		"starboard_cooldown": starboard_cooldown,
		"port_count": _get_side_cannons(-1).size(),
		"starboard_count": _get_side_cannons(1).size(),
		"port_weight": _get_side_weight(-1),
		"starboard_weight": _get_side_weight(1),
		"total_weight": get_total_cannon_weight(),
		"port_reload_time": _get_side_reload_time(-1),
		"starboard_reload_time": _get_side_reload_time(1),
		"port_range": _get_side_max_range(-1),
		"starboard_range": _get_side_max_range(1),
		"port_label": _get_side_label(-1),
		"starboard_label": _get_side_label(1)
	}


func _fire_side(side: int) -> bool:
	if projectile_scene == null:
		return false
	if side < 0 and port_cooldown > 0.0:
		return false
	if side > 0 and starboard_cooldown > 0.0:
		return false

	var side_cannons := _get_side_cannons(side)
	if side_cannons.is_empty():
		return false

	var ammo := _get_ammo_type()
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return false
	var fired_any := false
	var self_status_effects: Dictionary = {}

	for index in range(side_cannons.size()):
		var cannon: Resource = side_cannons[index]
		var projectile := projectile_scene.instantiate()
		var projectile_3d := projectile as Node3D
		if projectile_3d == null:
			projectile.queue_free()
			continue

		var center_offset := float(index) - float(side_cannons.size() - 1) * 0.5
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
		_spawn_muzzle_flash(spawn_parent, projectile_3d.global_position)
		fired_any = true

	if fired_any:
		self_status_effects = _roll_self_status_effects(ammo.get("status_effects"))
		if not self_status_effects.is_empty() and parent_3d.has_method("apply_status_effects"):
			parent_3d.call("apply_status_effects", self_status_effects)

		var boom_player := get_node_or_null("CannonBoomPlayer")
		if boom_player and boom_player.has_method("play_boom"):
			boom_player.call("play_boom")
	var reload_time: float = _get_side_reload_time(side)
	if side < 0:
		port_cooldown = reload_time
	else:
		starboard_cooldown = reload_time
	return fired_any


func _roll_self_status_effects(status_effects: Dictionary) -> Dictionary:
	if status_effects.is_empty():
		return {}

	var rolled := {}
	for effect_id in status_effects.keys():
		var effect: Dictionary = status_effects[effect_id]
		var chance := float(effect.get("self_ignition_chance", 0.0))
		if chance > 0.0 and randf() <= chance:
			var self_effect := effect.duplicate(true)
			self_effect.erase("chance")
			self_effect.erase("self_ignition_chance")
			self_effect["chance"] = 1.0
			rolled[effect_id] = self_effect
	return rolled


func _spawn_muzzle_flash(spawn_parent: Node, position: Vector3) -> void:
	var flash := MuzzleFlashScene.instantiate() as Node3D
	if flash == null:
		return
	spawn_parent.add_child(flash)
	flash.global_position = position


func _get_ammo_type() -> Resource:
	if ammo_types.has(selected_ammo_id):
		return ammo_types[selected_ammo_id]
	if not ammo_types.is_empty():
		return ammo_types.values()[0]
	return null


func _get_side_cannons(side: int) -> Array[Resource]:
	var ids := _get_side_cannon_ids(side)
	var cannons: Array[Resource] = []
	for cannon_id in ids:
		if cannon_types.has(cannon_id):
			cannons.append(cannon_types[cannon_id])
	return cannons


func _get_side_cannon_ids(side: int) -> Array:
	var side_name := "port" if side < 0 else "starboard"
	var broadsides: Dictionary = ship_loadout.get("broadsides", {})
	var broadside: Dictionary = broadsides.get(side_name, {})
	return broadside.get("cannons", [])


func _get_side_reload_time(side: int) -> float:
	var reload_time := 0.0
	for cannon in _get_side_cannons(side):
		reload_time = maxf(reload_time, float(cannon.get("reload_time")))
	return reload_time


func _get_side_weight(side: int) -> float:
	var weight := 0.0
	for cannon in _get_side_cannons(side):
		weight += float(cannon.get("weight"))
	return weight


func get_total_cannon_weight() -> float:
	return _get_side_weight(-1) + _get_side_weight(1)


func _get_side_max_range(side: int) -> float:
	var range := 0.0
	for cannon in _get_side_cannons(side):
		range = maxf(range, float(cannon.get("range")))
	var ammo := _get_ammo_type()
	if ammo == null:
		return range
	return range * float(ammo.get("range_multiplier"))


func _get_side_label(side: int) -> String:
	var counts := {}
	for cannon in _get_side_cannons(side):
		var name := str(cannon.get("display_name"))
		counts[name] = int(counts.get(name, 0)) + 1

	var parts: Array[String] = []
	for name in counts.keys():
		parts.append("%dx %s" % [counts[name], name])
	return ", ".join(parts)
