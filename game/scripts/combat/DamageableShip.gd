extends StaticBody3D
class_name DamageableShip

@export var max_hull: float = 60.0
@export var sunk_drop: float = 0.55
@export var sunk_roll_degrees: float = 11.0

var hull: float = 60.0
var is_sunk: bool = false


func _ready() -> void:
	hull = max_hull


func apply_hull_damage(amount: float) -> void:
	if is_sunk:
		return

	hull = maxf(0.0, hull - amount)
	print("Target hull: %.1f / %.1f" % [hull, max_hull])
	if hull <= 0.0:
		_sink()


func get_hull_fraction() -> float:
	if max_hull <= 0.0:
		return 0.0
	return hull / max_hull


func _sink() -> void:
	is_sunk = true
	position.y -= sunk_drop
	rotation_degrees.z = sunk_roll_degrees
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.disabled = true
	print("Target disabled.")
