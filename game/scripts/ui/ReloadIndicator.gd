extends Control
class_name ReloadIndicator

@export var broadside_path: NodePath

var broadside: Node


func _ready() -> void:
	broadside = get_node_or_null(broadside_path)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if broadside == null:
		return

	var port: float = broadside.get("port_cooldown")
	var starboard: float = broadside.get("starboard_cooldown")
	var cannon = broadside.call("_get_cannon_type")
	var reload_time := maxf(0.01, float(cannon.get("reload_time")))

	_draw_bar(Vector2(20.0, size.y - 58.0), Vector2(180.0, 16.0), "PORT", port, reload_time)
	_draw_bar(Vector2(size.x - 200.0, size.y - 58.0), Vector2(180.0, 16.0), "STARBOARD", starboard, reload_time)


func _draw_bar(position: Vector2, bar_size: Vector2, label: String, cooldown: float, reload_time: float) -> void:
	var ready := cooldown <= 0.0
	var fill := 1.0 if ready else 1.0 - clampf(cooldown / reload_time, 0.0, 1.0)
	var frame_color := Color(0.05, 0.06, 0.07, 0.82)
	var fill_color := Color(0.95, 0.78, 0.18, 0.95) if ready else Color(0.75, 0.26, 0.16, 0.9)
	var text := "%s READY" % label if ready else "%s %.1fs" % [label, cooldown]

	draw_rect(Rect2(position, bar_size), frame_color, true)
	draw_rect(Rect2(position + Vector2(2.0, 2.0), Vector2((bar_size.x - 4.0) * fill, bar_size.y - 4.0)), fill_color, true)
	draw_string(get_theme_default_font(), position + Vector2(0.0, -6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.96, 0.98, 1.0, 0.95))
