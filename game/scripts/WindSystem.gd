extends Node
class_name WindSystem

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var environment_condition_id: String = "default_battle"
@export_range(0.0, 30.0, 0.1) var wind_strength: float = 10.0
@export_range(0.0, 360.0, 1.0, "degrees") var wind_direction_degrees: float = 155.0
@export_range(0.1, 30.0, 0.1) var reference_wind_strength: float = 10.0
@export_range(0.1, 5.0, 0.1) var wind_strength_step: float = 1.0
@export_range(1.0, 45.0, 1.0, "degrees") var wind_direction_step_degrees: float = 15.0
@export var allow_debug_wind_controls: bool = true


func _ready() -> void:
	_apply_environment_conditions(ContentCatalog.load_environment_condition(environment_condition_id))


func get_wind_vector() -> Vector3:
	var radians := deg_to_rad(wind_direction_degrees)
	return Vector3(sin(radians), 0.0, cos(radians)).normalized() * wind_strength


func get_wind_direction() -> Vector3:
	var radians := deg_to_rad(wind_direction_degrees)
	return Vector3(sin(radians), 0.0, cos(radians)).normalized()


func get_wind_speed_factor() -> float:
	if reference_wind_strength <= 0.0:
		return 1.0
	return clampf(wind_strength / reference_wind_strength, 0.0, 1.6)


func _process(_delta: float) -> void:
	if not allow_debug_wind_controls:
		return
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		wind_strength = maxf(0.0, wind_strength - wind_strength_step * 0.05)
	if Input.is_key_pressed(KEY_BRACKETRIGHT):
		wind_strength = minf(30.0, wind_strength + wind_strength_step * 0.05)
	if Input.is_key_pressed(KEY_COMMA):
		wind_direction_degrees = wrapf(wind_direction_degrees - wind_direction_step_degrees * 0.05, 0.0, 360.0)
	if Input.is_key_pressed(KEY_PERIOD):
		wind_direction_degrees = wrapf(wind_direction_degrees + wind_direction_step_degrees * 0.05, 0.0, 360.0)


func _apply_environment_conditions(conditions: Dictionary) -> void:
	var wind: Dictionary = conditions.get("wind", {})
	wind_direction_degrees = float(wind.get("direction_degrees", wind_direction_degrees))
	wind_strength = float(wind.get("strength", wind_strength))
	reference_wind_strength = float(wind.get("reference_strength", reference_wind_strength))
