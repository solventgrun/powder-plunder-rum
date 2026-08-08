extends Control
class_name TargetIndicator

@export var ship_path: NodePath
@export var target_path: NodePath
@export var edge_padding: float = 34.0

var ship: Node3D
var target: Node3D


func _ready() -> void:
	ship = get_node_or_null(ship_path) as Node3D
	target = get_node_or_null(target_path) as Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ship == null or target == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var target_world := target.global_position + Vector3.UP * 0.9
	var target_screen := camera.unproject_position(target_world)
	var viewport_size := get_viewport_rect().size
	var is_on_screen := not camera.is_position_behind(target_world) \
		and target_screen.x >= 0.0 \
		and target_screen.y >= 0.0 \
		and target_screen.x <= viewport_size.x \
		and target_screen.y <= viewport_size.y

	var center := viewport_size * 0.5
	var draw_position := target_screen
	if not is_on_screen:
		var world_direction := target.global_position - ship.global_position
		var screen_direction := Vector2(world_direction.x, world_direction.z).normalized()
		if screen_direction.is_zero_approx():
			screen_direction = Vector2.RIGHT
		draw_position = center + screen_direction * minf(viewport_size.x, viewport_size.y) * 0.42
		draw_position.x = clampf(draw_position.x, edge_padding, viewport_size.x - edge_padding)
		draw_position.y = clampf(draw_position.y, edge_padding, viewport_size.y - edge_padding)

	var to_target := (target.global_position - ship.global_position)
	var distance := to_target.length()
	var angle := Vector2(to_target.x, to_target.z).angle()
	var color := Color(1.0, 0.86, 0.28, 0.95)
	var size := 16.0 if is_on_screen else 22.0
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		draw_position + forward * size,
		draw_position - forward * size * 0.65 + side * size * 0.45,
		draw_position - forward * size * 0.65 - side * size * 0.45
	])

	draw_colored_polygon(points, color)
	draw_arc(draw_position, size + 6.0, 0.0, TAU, 24, Color(0.02, 0.03, 0.04, 0.75), 2.0)
	draw_string(get_theme_default_font(), draw_position + Vector2(18.0, 5.0), "%.0fm" % distance, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
