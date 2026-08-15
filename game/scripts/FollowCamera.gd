extends Camera3D
class_name FollowCamera

@export var target_path: NodePath
@export var follow_offset: Vector3 = Vector3(0.0, 18.0, 16.0)
@export_range(1.0, 20.0, 0.1) var follow_smoothing: float = 8.0
# Combat framing: pull the view anchor toward a second ship (the engaged
# enemy) so both ships — and shots landing around them — stay on screen.
# The clamp keeps the player near the middle of the frame. Optional; scenes
# without a focus target follow exactly as before.
@export var focus_target_path: NodePath
@export_range(0.0, 1.0, 0.05) var focus_bias: float = 0.4
@export_range(0.0, 40.0, 0.5) var focus_max_offset: float = 15.0

var target: Node3D
var focus_target: Node3D
var smoothed_anchor: Vector3 = Vector3.ZERO


func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	focus_target = get_node_or_null(focus_target_path) as Node3D
	if target:
		smoothed_anchor = target.global_position
		global_position = smoothed_anchor + follow_offset
		look_at(smoothed_anchor, Vector3.UP)


func _process(delta: float) -> void:
	if not target:
		return

	# One smoothing pass on the anchor keeps position and look direction in
	# lockstep, so anchor jumps (focus ship sinking) ease instead of snapping.
	smoothed_anchor = smoothed_anchor.lerp(_anchor_position(), 1.0 - exp(-follow_smoothing * delta))
	global_position = smoothed_anchor + follow_offset
	look_at(smoothed_anchor, Vector3.UP)


func _anchor_position() -> Vector3:
	var anchor := target.global_position
	if _focus_is_active():
		var pull := (focus_target.global_position - anchor) * focus_bias
		pull.y = 0.0
		if pull.length() > focus_max_offset:
			pull = pull.normalized() * focus_max_offset
		anchor += pull
	return anchor


func _focus_is_active() -> bool:
	if focus_target == null or not is_instance_valid(focus_target):
		return false
	var combat: Variant = focus_target.get("combat")
	if combat is Object and bool((combat as Object).get("is_sunk")):
		return false
	return true
