extends CharacterBody3D
class_name ShipController

@export var wind_system_path: NodePath
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.1, 2.0, 0.05) var sail_trim_speed: float = 0.65

@onready var sailing_model: Node = $SailingModel

var wind_system: Node
var steering_input: float = 0.0


func _ready() -> void:
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)


func _physics_process(delta: float) -> void:
	steering_input = Input.get_axis("steer_port", "steer_starboard")
	_update_sail_trim(delta)

	var ship_forward := -global_transform.basis.z
	var wind_direction := Vector3.FORWARD
	if wind_system:
		wind_direction = wind_system.get_wind_direction()

	var turn_degrees: float = sailing_model.calculate_turn_degrees(velocity.length(), steering_input, delta)
	rotate_y(deg_to_rad(turn_degrees))

	ship_forward = -global_transform.basis.z
	velocity = sailing_model.calculate_velocity(velocity, ship_forward, wind_direction, sail_trim, delta)
	move_and_slide()


func _update_sail_trim(delta: float) -> void:
	var trim_input := Input.get_axis("ease_sails", "trim_sails")
	if not is_zero_approx(trim_input):
		sail_trim = clampf(sail_trim + trim_input * sail_trim_speed * delta, 0.15, 1.0)


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
