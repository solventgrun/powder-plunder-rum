extends Area3D
class_name Cannonball

@export var fallback_speed: float = 30.0
@export var fallback_range: float = 30.0
@export var fallback_damage: float = 4.0

var direction: Vector3 = Vector3.RIGHT
var speed: float = 30.0
var remaining_range: float = 30.0
var damage: float = 4.0
var source: Node


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func configure(fire_direction: Vector3, cannon: Resource, ammo: Resource, projectile_source: Node) -> void:
	direction = fire_direction.normalized()
	source = projectile_source
	speed = float(cannon.get("projectile_speed"))
	remaining_range = float(cannon.get("range")) * float(ammo.get("range_multiplier"))
	damage = float(ammo.get("hull_damage"))


func _physics_process(delta: float) -> void:
	var travel := speed * delta
	global_position += direction * travel
	remaining_range -= travel
	if remaining_range <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if body.has_method("apply_hull_damage"):
		body.call("apply_hull_damage", damage)
	queue_free()
