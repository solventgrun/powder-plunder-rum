extends CharacterBody3D
class_name OverworldNpcShip

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var speed: float = 8.0
@export var turn_speed: float = 3.5
@export_range(1.0, 4.0, 0.1) var overworld_visual_scale: float = 2.0
@export var faction_colors: Dictionary = {
	"spain": Color(0.9, 0.72, 0.18, 0.92),
	"dutch": Color(0.95, 0.36, 0.12, 0.92),
	"england": Color(0.82, 0.12, 0.12, 0.92),
	"france": Color(0.2, 0.36, 0.95, 0.92),
	"pirates": Color(0.05, 0.05, 0.05, 0.92)
}

var encounter_record: Dictionary = {}
var route: Array[Vector3] = []
var route_index: int = 0
var ship_stats: Resource


func configure(record: Dictionary) -> void:
	encounter_record = record.duplicate(true)
	ship_stats = ContentCatalog.build_ship_stats(encounter_record, ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	name = str(record.get("id", "OverworldNpcShip"))
	route.clear()
	for waypoint in record.get("route", []):
		route.append(Vector3(float(waypoint.get("x", 0.0)), 0.0, float(waypoint.get("z", 0.0))))
	if route.is_empty():
		route.append(Vector3(float(record.get("start_x", 0.0)), 0.0, float(record.get("start_z", 0.0))))
	global_position = Vector3(float(record.get("start_x", route[0].x)), 0.0, float(record.get("start_z", route[0].z)))
	route_index = 1 if route.size() > 1 else 0
	_apply_ship_stats()
	var ship_visuals := get_node_or_null("VisualRoot/ShipVisualBuilder")
	if ship_visuals:
		ship_visuals.call("apply_visuals", encounter_record, ship_stats)
		ship_visuals.call("update_sail_trim", 0.85)
	_apply_readability(record)


func _physics_process(delta: float) -> void:
	if route.size() <= 1:
		return
	var target := route[route_index]
	var to_target := target - global_position
	if to_target.length() < 1.2:
		route_index = (route_index + 1) % route.size()
		return

	var desired_direction := to_target.normalized()
	var desired_heading := atan2(-desired_direction.x, -desired_direction.z)
	var current_heading := atan2(-global_transform.basis.z.x, -global_transform.basis.z.z)
	var heading_delta := wrapf(desired_heading - current_heading, -PI, PI)
	rotate_y(clampf(heading_delta, -turn_speed * delta, turn_speed * delta))
	velocity = (-global_transform.basis.z).normalized() * speed
	move_and_slide()


func _apply_ship_stats() -> void:
	if ship_stats == null:
		return
	speed = maxf(4.5, float(ship_stats.get("max_speed")) * 1.8)
	turn_speed = deg_to_rad(clampf(float(ship_stats.get("turn_rate")), 24.0, 95.0))
	scale = Vector3.ONE * float(ship_stats.get("visual_scale")) * overworld_visual_scale


func _apply_readability(record: Dictionary) -> void:
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = str(record.get("name", "NPC Ship"))

	var color: Color = faction_colors.get(str(record.get("faction", "")), Color(0.95, 0.82, 0.26, 0.92))
	var material := StandardMaterial3D.new()
	material.albedo_color = color

	var marker := get_node_or_null("WaterMarker") as MeshInstance3D
	if marker:
		marker.material_override = material
	var flag := get_node_or_null("FactionFlag") as MeshInstance3D
	if flag:
		flag.material_override = material
