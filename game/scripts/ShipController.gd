extends CharacterBody3D
class_name ShipController

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const BurningFlameScene := preload("res://game/scenes/BurningFlame.tscn")
const MagazineExplosionScene := preload("res://game/scenes/MagazineExplosion.tscn")

@export var wind_system_path: NodePath
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.1, 2.0, 0.05) var sail_trim_speed: float = 0.65
@export var max_hull: float = 80.0
@export var ship_type_id: String = "brig"

@onready var sailing_model: Node = $SailingModel

var wind_system: Node
var steering_input: float = 0.0
var hull: float = 80.0
var magazine_explosion_multiplier: float = 1.0
var is_sunk: bool = false
var is_burning: bool = false
var burning_time_remaining: float = 0.0
var burning_hull_damage_per_second: float = 0.0
var burning_magazine_explosion_chance_per_second: float = 0.0
var burning_explosion_tick: float = 0.0
var burning_growth_chance_per_second: float = 0.0
var burning_growth_tick: float = 0.0
var burning_severity: String = ""
var fire_levels: Dictionary = {}
var flame_visual: Node3D
var ship_stats: Resource


func _ready() -> void:
	fire_levels = ContentCatalog.load_fire_levels()
	_apply_ship_stats(ContentCatalog.load_player_ship_stats())
	hull = max_hull
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)


func _physics_process(delta: float) -> void:
	if is_sunk:
		return
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
		"sail_trim": sail_trim,
		"ship_type": ship_stats.get("display_name") if ship_stats else ship_type_id,
		"ship_mods": ", ".join(ship_stats.get("modification_names")) if ship_stats else "",
		"max_hull": max_hull,
		"load_weight": float(ship_stats.get("total_load_weight")) if ship_stats else 0.0,
		"load_capacity": float(ship_stats.get("usable_load_capacity")) if ship_stats else 0.0,
		"load_fraction": float(ship_stats.get("load_fraction")) if ship_stats else 0.0,
		"load_speed_multiplier": float(ship_stats.get("load_speed_multiplier")) if ship_stats else 1.0,
		"load_turn_multiplier": float(ship_stats.get("load_turn_multiplier")) if ship_stats else 1.0
	}


func apply_status_effects(status_effects: Dictionary) -> void:
	if status_effects.is_empty():
		return

	if status_effects.has("burning"):
		var burning: Dictionary = status_effects.get("burning")
		var chance := float(burning.get("chance", 1.0))
		if randf() <= chance:
			_apply_burning(str(burning.get("severity", "small")))
	if status_effects.has("magazine_explosion"):
		var explosion: Dictionary = status_effects.get("magazine_explosion")
		var chance := float(explosion.get("chance", 0.0)) * magazine_explosion_multiplier
		if randf() <= chance:
			_explode()


func apply_hull_damage(amount: float) -> void:
	if is_sunk:
		return
	hull = maxf(0.0, hull - amount)
	if hull <= 0.0:
		_sink()


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
	burning_explosion_tick += delta
	burning_growth_tick += delta
	if burning_growth_chance_per_second > 0.0 and burning_growth_tick >= 1.0:
		burning_growth_tick = 0.0
		if randf() <= burning_growth_chance_per_second:
			_apply_burning(_next_fire_severity(burning_severity))
	if burning_magazine_explosion_chance_per_second > 0.0 and burning_explosion_tick >= 1.0:
		burning_explosion_tick = 0.0
		if randf() <= burning_magazine_explosion_chance_per_second * magazine_explosion_multiplier:
			_explode()
	if burning_time_remaining <= 0.0:
		_stop_burning()


func _apply_burning(severity: String) -> void:
	var next_severity := _escalate_fire_severity(severity)
	var level: Dictionary = fire_levels.get(next_severity, fire_levels.get("small", {}))
	is_burning = true
	burning_severity = next_severity
	burning_time_remaining = maxf(burning_time_remaining, float(level.get("duration", 5.0)))
	burning_hull_damage_per_second = float(level.get("hull_damage_per_second", 1.0))
	burning_growth_chance_per_second = float(level.get("growth_chance_per_second", 0.0))
	burning_magazine_explosion_chance_per_second = float(level.get("magazine_explosion_chance_per_second", 0.0))
	if flame_visual == null:
		flame_visual = BurningFlameScene.instantiate() as Node3D
		if flame_visual:
			add_child(flame_visual)
			flame_visual.position = Vector3(0.0, 0.65, 0.0)
	if flame_visual:
		var visual_scale := float(level.get("visual_scale", 1.0))
		flame_visual.scale = Vector3.ONE * visual_scale


func _stop_burning() -> void:
	is_burning = false
	burning_severity = ""
	burning_time_remaining = 0.0
	burning_hull_damage_per_second = 0.0
	burning_growth_chance_per_second = 0.0
	burning_magazine_explosion_chance_per_second = 0.0
	burning_explosion_tick = 0.0
	burning_growth_tick = 0.0
	if flame_visual:
		flame_visual.queue_free()
		flame_visual = null


func _apply_ship_stats(stats: Resource) -> void:
	if stats == null:
		return
	ship_stats = stats
	ship_type_id = stats.get("ship_type_id")
	max_hull = float(stats.get("max_hull"))
	magazine_explosion_multiplier = float(stats.get("magazine_explosion_multiplier"))
	sailing_model.set("max_speed", float(stats.get("max_speed")))
	sailing_model.set("acceleration", float(stats.get("acceleration")))
	sailing_model.set("deceleration", float(stats.get("deceleration")))
	sailing_model.set("turn_rate", float(stats.get("turn_rate")))
	scale = Vector3.ONE * float(stats.get("visual_scale"))


func _escalate_fire_severity(incoming_severity: String) -> String:
	if not is_burning:
		return incoming_severity
	if _fire_severity_rank(incoming_severity) > _fire_severity_rank(burning_severity):
		return incoming_severity
	return _next_fire_severity(burning_severity)


func _next_fire_severity(severity: String) -> String:
	if severity == "small":
		return "medium"
	if severity == "medium":
		return "large"
	return "large"


func _fire_severity_rank(severity: String) -> int:
	if severity == "large":
		return 3
	if severity == "medium":
		return 2
	if severity == "small":
		return 1
	return 0


func _sink() -> void:
	is_sunk = true
	_stop_burning()
	velocity = Vector3.ZERO
	position.y -= 0.4
	rotation_degrees.z = 8.0


func _explode() -> void:
	if is_sunk:
		return
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent:
		var explosion := MagazineExplosionScene.instantiate() as Node3D
		if explosion:
			spawn_parent.add_child(explosion)
			explosion.global_position = global_position
	hull = 0.0
	_sink()
