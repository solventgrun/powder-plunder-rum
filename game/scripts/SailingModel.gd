extends Node
class_name SailingModel

@export_range(0.0, 40.0, 0.1) var max_speed: float = 9.0
@export_range(0.0, 30.0, 0.1) var acceleration: float = 3.8
@export_range(0.0, 30.0, 0.1) var deceleration: float = 2.6
@export_range(0.0, 180.0, 1.0, "degrees_per_second") var turn_rate: float = 70.0
@export_range(0.0, 90.0, 1.0, "degrees_per_second") var minimum_turn_rate: float = 18.0
@export_range(0.0, 1.0, 0.01) var headwind_efficiency: float = 0.04
@export_range(0.0, 1.5, 0.01) var crosswind_efficiency: float = 1.0
@export_range(0.0, 1.5, 0.01) var tailwind_efficiency: float = 0.82
@export_range(0.0, 1.0, 0.01) var minimum_turn_speed_factor: float = 0.22

var last_wind_angle_degrees: float = 0.0
var last_sail_efficiency: float = 0.0


func calculate_sail_efficiency(ship_forward: Vector3, wind_direction: Vector3, sail_trim: float) -> float:
	var forward := ship_forward.normalized()
	var wind := wind_direction.normalized()
	var wind_from_ahead_score := forward.dot(-wind)
	var angle := rad_to_deg(acos(clampf(wind_from_ahead_score, -1.0, 1.0)))
	last_wind_angle_degrees = angle

	if angle < 35.0:
		last_sail_efficiency = headwind_efficiency
	elif angle < 105.0:
		last_sail_efficiency = lerpf(headwind_efficiency, crosswind_efficiency, inverse_lerp(35.0, 105.0, angle))
	else:
		last_sail_efficiency = lerpf(crosswind_efficiency, tailwind_efficiency, inverse_lerp(105.0, 180.0, angle))

	return last_sail_efficiency * clampf(sail_trim, 0.0, 1.0)


func calculate_turn_degrees(current_speed: float, steering_input: float, delta: float) -> float:
	if is_zero_approx(steering_input):
		return 0.0

	var speed_factor := clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var effective_turn_factor := maxf(minimum_turn_speed_factor, speed_factor)
	var degrees := lerpf(minimum_turn_rate, turn_rate, effective_turn_factor)
	return -steering_input * degrees * delta


func calculate_velocity(current_velocity: Vector3, ship_forward: Vector3, wind_direction: Vector3, sail_trim: float, delta: float, wind_speed_factor: float = 1.0) -> Vector3:
	var efficiency := calculate_sail_efficiency(ship_forward, wind_direction, sail_trim)
	var target_speed := max_speed * efficiency * clampf(wind_speed_factor, 0.0, 1.6)
	var target_velocity := ship_forward.normalized() * target_speed
	var rate := acceleration if target_velocity.length() > current_velocity.length() else deceleration
	return current_velocity.move_toward(target_velocity, rate * delta)
