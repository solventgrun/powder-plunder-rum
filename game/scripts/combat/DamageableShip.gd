extends StaticBody3D
class_name DamageableShip

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const BurningFlameScene := preload("res://game/scenes/BurningFlame.tscn")
const MagazineExplosionScene := preload("res://game/scenes/MagazineExplosion.tscn")

@export var max_hull: float = 60.0
@export var ship_type_id: String = "sloop"
@export var sunk_drop: float = 0.55
@export var sunk_roll_degrees: float = 11.0

var hull: float = 60.0
var magazine_explosion_multiplier: float = 1.0
var is_sunk: bool = false
var is_burning: bool = false
var burning_severity: String = ""
var burning_time_remaining: float = 0.0
var burning_hull_damage_per_second: float = 0.0
var burning_magazine_explosion_chance_per_second: float = 0.0
var burning_explosion_tick: float = 0.0
var fire_levels: Dictionary = {}

var flame_visual: Node3D


func _ready() -> void:
	fire_levels = ContentCatalog.load_fire_levels()
	_apply_ship_type()
	hull = max_hull


func _process(delta: float) -> void:
	if is_sunk or not is_burning:
		return

	burning_time_remaining = maxf(0.0, burning_time_remaining - delta)
	if burning_hull_damage_per_second > 0.0:
		apply_hull_damage(burning_hull_damage_per_second * delta)
	burning_explosion_tick += delta
	if burning_magazine_explosion_chance_per_second > 0.0 and burning_explosion_tick >= 1.0:
		burning_explosion_tick = 0.0
		if randf() <= burning_magazine_explosion_chance_per_second * magazine_explosion_multiplier:
			_explode()
	if burning_time_remaining <= 0.0:
		_stop_burning()


func apply_hull_damage(amount: float) -> void:
	if is_sunk:
		return

	hull = maxf(0.0, hull - amount)
	if amount >= 0.5 or hull <= 0.0:
		print("Target hull: %.1f / %.1f" % [hull, max_hull])
	if hull <= 0.0:
		_sink()


func apply_status_effects(status_effects: Dictionary) -> void:
	if is_sunk or status_effects.is_empty():
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


func get_hull_fraction() -> float:
	if max_hull <= 0.0:
		return 0.0
	return hull / max_hull


func _sink() -> void:
	is_sunk = true
	_stop_burning()
	position.y -= sunk_drop
	rotation_degrees.z = sunk_roll_degrees
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.disabled = true
	print("Target disabled.")


func _apply_burning(severity: String) -> void:
	var next_severity := _escalate_fire_severity(severity)
	var level: Dictionary = fire_levels.get(next_severity, fire_levels.get("small", {}))
	is_burning = true
	burning_severity = next_severity
	burning_time_remaining = maxf(burning_time_remaining, float(level.get("duration", 5.0)))
	burning_hull_damage_per_second = float(level.get("hull_damage_per_second", 1.0))
	burning_magazine_explosion_chance_per_second = float(level.get("magazine_explosion_chance_per_second", 0.0))
	if flame_visual == null:
		flame_visual = BurningFlameScene.instantiate() as Node3D
		if flame_visual:
			add_child(flame_visual)
			flame_visual.position = Vector3(0.0, 0.45, 0.0)
	if flame_visual:
		flame_visual.scale = Vector3.ONE * float(level.get("visual_scale", 1.0))


func _stop_burning() -> void:
	is_burning = false
	burning_severity = ""
	burning_time_remaining = 0.0
	burning_hull_damage_per_second = 0.0
	burning_magazine_explosion_chance_per_second = 0.0
	burning_explosion_tick = 0.0
	if flame_visual:
		flame_visual.queue_free()
		flame_visual = null


func _apply_ship_type() -> void:
	var ship_types := ContentCatalog.load_ship_types()
	if not ship_types.has(ship_type_id):
		return
	var ship_type: Dictionary = ship_types[ship_type_id]
	var combat: Dictionary = ship_type.get("combat", {})
	max_hull = float(combat.get("max_hull", max_hull))
	magazine_explosion_multiplier = float(combat.get("magazine_explosion_multiplier", 1.0))
	scale = Vector3.ONE * float(ship_type.get("visual_scale", 1.0))


func _escalate_fire_severity(incoming_severity: String) -> String:
	if not is_burning:
		return incoming_severity
	if burning_severity == "small":
		return "medium"
	if burning_severity == "medium":
		return "large"
	return "large"


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
