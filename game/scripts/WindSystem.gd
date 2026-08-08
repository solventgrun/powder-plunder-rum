extends Node
class_name WindSystem

@export_range(0.0, 30.0, 0.1) var wind_strength: float = 10.0
@export_range(0.0, 360.0, 1.0, "degrees") var wind_direction_degrees: float = 155.0


func get_wind_vector() -> Vector3:
	var radians := deg_to_rad(wind_direction_degrees)
	return Vector3(sin(radians), 0.0, cos(radians)).normalized() * wind_strength


func get_wind_direction() -> Vector3:
	return get_wind_vector().normalized()
