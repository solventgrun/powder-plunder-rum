extends CharacterBody3D
class_name OverworldPlayerShip

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var wind_system_path: NodePath
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.1, 2.0, 0.05) var sail_trim_speed: float = 0.75
@export_range(1.0, 4.0, 0.1) var overworld_visual_scale: float = 2.15

@onready var sailing_model: SailingModel = $SailingModel
@onready var ship_visuals: Node = $VisualRoot/ShipVisualBuilder

var wind_system: Node
var steering_input: float = 0.0
var ship_stats: Resource


func _ready() -> void:
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)
	var ship_record := ContentCatalog.load_player_ship_record()
	ship_stats = ContentCatalog.load_player_ship_stats()
	_apply_ship_stats(ship_stats)
	if ship_visuals:
		ship_visuals.apply_visuals(ship_record, ship_stats)
		ship_visuals.update_sail_trim(sail_trim)


func _physics_process(delta: float) -> void:
	steering_input = Input.get_axis("steer_port", "steer_starboard")
	_update_sail_trim(delta)

	var wind_direction := Vector3.FORWARD
	var wind_speed_factor := 1.0
	if wind_system:
		wind_direction = wind_system.get_wind_direction()
		if wind_system.has_method("get_wind_speed_factor"):
			wind_speed_factor = float(wind_system.call("get_wind_speed_factor"))

	var turn_degrees := sailing_model.calculate_turn_degrees(velocity.length(), steering_input, delta)
	rotate_y(deg_to_rad(turn_degrees))

	var forward := -global_transform.basis.z
	velocity = sailing_model.calculate_velocity(velocity, forward, wind_direction, sail_trim, delta, wind_speed_factor)
	move_and_slide()


func get_debug_values() -> Dictionary:
	var heading := rad_to_deg(atan2(-global_transform.basis.z.x, -global_transform.basis.z.z))
	var wind_heading := 0.0
	if wind_system:
		var wind: Vector3 = wind_system.get_wind_direction()
		wind_heading = rad_to_deg(atan2(wind.x, wind.z))
	return {
		"speed": velocity.length(),
		"heading": wrapf(heading, 0.0, 360.0),
		"wind_heading": wrapf(wind_heading, 0.0, 360.0),
		"wind_angle": sailing_model.last_wind_angle_degrees,
		"sail_efficiency": sailing_model.last_sail_efficiency,
		"sail_trim": sail_trim
	}


func _update_sail_trim(delta: float) -> void:
	var trim_input := Input.get_axis("ease_sails", "trim_sails")
	if not is_zero_approx(trim_input):
		sail_trim = clampf(sail_trim + trim_input * sail_trim_speed * delta, 0.15, 1.0)
		if ship_visuals:
			ship_visuals.update_sail_trim(sail_trim)


func _apply_ship_stats(stats: Resource) -> void:
	if stats == null:
		return
	sailing_model.max_speed = float(stats.get("max_speed")) * 2.4
	sailing_model.acceleration = float(stats.get("acceleration")) * 2.8
	sailing_model.deceleration = float(stats.get("deceleration")) * 2.4
	sailing_model.turn_rate = float(stats.get("turn_rate"))
	sailing_model.minimum_turn_rate = float(stats.get("minimum_turn_rate"))
	sail_trim_speed = float(stats.get("sail_trim_speed"))
	scale = Vector3.ONE * float(stats.get("visual_scale")) * overworld_visual_scale
