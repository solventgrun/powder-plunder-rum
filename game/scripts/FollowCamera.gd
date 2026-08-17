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
# Trauma shake: events add trauma, shake strength is trauma squared so small
# hits barely stir the frame while broadsides and explosions rattle it.
# Sized up 2026-08-17 (playtest: neither firing nor being hit read on screen).
@export_range(0.0, 2.0, 0.05) var max_shake_offset: float = 0.75
@export_range(0.0, 10.0, 0.1, "degrees") var max_shake_roll_degrees: float = 3.2
@export_range(0.2, 5.0, 0.1) var trauma_decay: float = 1.5

var target: Node3D
var focus_target: Node3D
var smoothed_anchor: Vector3 = Vector3.ZERO
var trauma: float = 0.0
var shake_time: float = 0.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


# Convenience for effect spawn sites: shakes whatever camera is current,
# scaled down with distance from the event. Duck-typed so probe/tool cameras
# without shake are silently skipped.
static func add_trauma_at(context: Node, world_position: Vector3, amount: float, falloff_distance: float = 70.0) -> void:
	var viewport := context.get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null or not camera.has_method("add_trauma"):
		return
	var falloff := 1.0 - clampf(world_position.distance_to(camera.global_position) / falloff_distance, 0.0, 1.0)
	if falloff > 0.0:
		camera.call("add_trauma", amount * falloff)


# Shot impacts shake the camera only when the camera's own ship takes the
# hit: incoming fire rattles the player; their shots landing on the enemy do
# not (2026-08-16 playtest). Duck-typed like add_trauma_at.
static func add_trauma_for_ship_hit(context: Node, ship: Node, amount: float) -> void:
	var viewport := context.get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null or not camera.has_method("add_trauma"):
		return
	var followed: Variant = camera.get("target")
	if followed is Node and is_instance_valid(followed):
		var followed_node := followed as Node
		if followed_node == ship or followed_node.is_ancestor_of(ship) or ship.is_ancestor_of(followed_node):
			camera.call("add_trauma", amount)


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
	_apply_shake(delta)


# Two incommensurate sine pairs per axis stand in for noise; applied after
# look_at so the shake perturbs the settled frame instead of feeding back
# into the follow smoothing.
func _apply_shake(delta: float) -> void:
	if trauma <= 0.0:
		return
	shake_time += delta
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	var intensity := trauma * trauma
	var sway_x := sin(shake_time * 39.0) * 0.55 + sin(shake_time * 71.0 + 1.3) * 0.45
	var sway_y := sin(shake_time * 47.0 + 2.1) * 0.55 + sin(shake_time * 83.0 + 0.7) * 0.45
	global_position += global_transform.basis.x * (max_shake_offset * intensity * sway_x) \
		+ global_transform.basis.y * (max_shake_offset * intensity * sway_y)
	rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(max_shake_roll_degrees) * intensity * sin(shake_time * 53.0 + 3.9))


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
