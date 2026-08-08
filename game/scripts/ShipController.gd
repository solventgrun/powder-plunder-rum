extends CharacterBody3D
class_name ShipController

const BurningFlameScene := preload("res://game/scenes/BurningFlame.tscn")

@export var wind_system_path: NodePath
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.1, 2.0, 0.05) var sail_trim_speed: float = 0.65
@export var max_hull: float = 80.0

@onready var sailing_model: Node = $SailingModel

var wind_system: Node
var steering_input: float = 0.0
var hull: float = 80.0
var is_burning: bool = false
var burning_time_remaining: float = 0.0
var burning_hull_damage_per_second: float = 0.0
var flame_visual: Node3D


func _ready() -> void:
	hull = max_hull
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)


func _physics_process(delta: float) -> void:
	_update_burning(delta)
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


func apply_status_effects(status_effects: Dictionary) -> void:
	if status_effects.is_empty():
		return

	if status_effects.has("burning"):
		var burning: Dictionary = status_effects.get("burning")
		var chance := float(burning.get("chance", 1.0))
		if randf() <= chance:
			_apply_burning(float(burning.get("duration", 4.0)), float(burning.get("hull_damage_per_second", 1.0)))


func apply_hull_damage(amount: float) -> void:
	hull = maxf(0.0, hull - amount)


func get_hull_fraction() -> float:
	if max_hull <= 0.0:
		return 0.0
	return hull / max_hull


func _update_burning(delta: float) -> void:
	if not is_burning:
		return

	burning_time_remaining = maxf(0.0, burning_time_remaining - delta)
	if burning_hull_damage_per_second > 0.0:
		apply_hull_damage(burning_hull_damage_per_second * delta)
	if burning_time_remaining <= 0.0:
		_stop_burning()


func _apply_burning(duration: float, hull_damage_per_second: float) -> void:
	is_burning = true
	burning_time_remaining = maxf(burning_time_remaining, duration)
	burning_hull_damage_per_second = maxf(burning_hull_damage_per_second, hull_damage_per_second)
	if flame_visual == null:
		flame_visual = BurningFlameScene.instantiate() as Node3D
		if flame_visual:
			add_child(flame_visual)
			flame_visual.position = Vector3(0.0, 0.65, 0.0)


func _stop_burning() -> void:
	is_burning = false
	burning_time_remaining = 0.0
	burning_hull_damage_per_second = 0.0
	if flame_visual:
		flame_visual.queue_free()
		flame_visual = null
