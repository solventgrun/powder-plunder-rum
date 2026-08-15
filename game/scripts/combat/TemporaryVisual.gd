extends Node3D
class_name TemporaryVisual

@export var lifetime: float = 0.35
@export var start_scale: Vector3 = Vector3.ONE
@export var end_scale: Vector3 = Vector3.ONE
# Fade child geometry out over the lifetime (GeometryInstance3D.transparency,
# so no material duplication is needed).
@export var fade_alpha: bool = false

var age: float = 0.0
var geometry_children: Array[GeometryInstance3D] = []


func _ready() -> void:
	scale = start_scale
	if fade_alpha:
		for child in get_children():
			if child is GeometryInstance3D:
				geometry_children.append(child)


func _process(delta: float) -> void:
	# Clamp hitch frames so a single long frame (load stall, headless test
	# frame) cannot expire a short-lived effect before it is ever seen.
	age += minf(delta, 0.1)
	var progress := clampf(age / lifetime, 0.0, 1.0)
	scale = start_scale.lerp(end_scale, progress)
	for geometry in geometry_children:
		geometry.transparency = progress
	if age >= lifetime:
		queue_free()
