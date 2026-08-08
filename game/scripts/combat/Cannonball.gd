extends Area3D
class_name Cannonball

const SplashScene := preload("res://game/scenes/Splash.tscn")
const ImpactFlashScene := preload("res://game/scenes/ImpactFlash.tscn")

@export var fallback_speed: float = 30.0
@export var fallback_range: float = 30.0
@export var fallback_damage: float = 4.0

var direction: Vector3 = Vector3.RIGHT
var speed: float = 30.0
var remaining_range: float = 30.0
var damage: float = 4.0
var status_effects: Dictionary = {}
var source: Node


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func configure(fire_direction: Vector3, cannon: Resource, ammo: Resource, projectile_source: Node) -> void:
	direction = fire_direction.normalized()
	source = projectile_source
	speed = float(cannon.get("projectile_speed"))
	remaining_range = float(cannon.get("range")) * float(ammo.get("range_multiplier"))
	damage = float(ammo.get("hull_damage"))
	status_effects = ammo.get("status_effects")


func _physics_process(delta: float) -> void:
	var travel := speed * delta
	global_position += direction * travel
	remaining_range -= travel
	if remaining_range <= 0.0:
		_spawn_splash()
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if body.has_method("apply_hull_damage"):
		body.call("apply_hull_damage", damage)
		_spawn_impact()
		if body.has_method("apply_status_effects"):
			body.call("apply_status_effects", status_effects)
	queue_free()


func _spawn_splash() -> void:
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent == null:
		return

	var splash := SplashScene.instantiate() as Node3D
	if splash == null:
		return
	spawn_parent.add_child(splash)
	splash.global_position = Vector3(global_position.x, 0.04, global_position.z)


func _spawn_impact() -> void:
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent == null:
		return

	var impact := ImpactFlashScene.instantiate() as Node3D
	if impact == null:
		return
	spawn_parent.add_child(impact)
	impact.global_position = global_position
