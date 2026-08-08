extends StaticBody3D
class_name DamageableShip

@export var max_hull: float = 60.0

var hull: float = 60.0


func _ready() -> void:
	hull = max_hull


func apply_hull_damage(amount: float) -> void:
	hull = maxf(0.0, hull - amount)
	print("Target hull: %.1f / %.1f" % [hull, max_hull])


func get_hull_fraction() -> float:
	if max_hull <= 0.0:
		return 0.0
	return hull / max_hull
