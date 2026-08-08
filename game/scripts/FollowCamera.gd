extends Camera3D
class_name FollowCamera

@export var target_path: NodePath
@export var follow_offset: Vector3 = Vector3(0.0, 18.0, 16.0)
@export_range(1.0, 20.0, 0.1) var follow_smoothing: float = 8.0

var target: Node3D


func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	if target:
		global_position = target.global_position + follow_offset
		look_at(target.global_position, Vector3.UP)


func _process(delta: float) -> void:
	if not target:
		return

	var desired_position := target.global_position + follow_offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_smoothing * delta))
	look_at(target.global_position, Vector3.UP)
