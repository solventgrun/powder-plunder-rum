extends Node3D
class_name TemporaryVisual

@export var lifetime: float = 0.35
@export var start_scale: Vector3 = Vector3.ONE
@export var end_scale: Vector3 = Vector3.ONE

var age: float = 0.0


func _ready() -> void:
	scale = start_scale


func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / lifetime, 0.0, 1.0)
	scale = start_scale.lerp(end_scale, progress)
	if age >= lifetime:
		queue_free()
