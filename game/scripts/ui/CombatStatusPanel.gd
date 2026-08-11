extends Control
class_name CombatStatusPanel

@export var player_path: NodePath
@export var target_path: NodePath

var player: Node
var target: Node


func _ready() -> void:
	player = get_node_or_null(player_path)
	target = get_node_or_null(target_path)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or target == null:
		return

	var panel_position := Vector2(size.x - 258.0, 166.0)
	var bar_size := Vector2(220.0, 14.0)
	var target_name := str(target.get("ship_display_name"))
	if target_name.is_empty():
		target_name = "Enemy Ship"
	draw_string(get_theme_default_font(), panel_position, target_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.96, 0.93, 0.78, 0.98))
	_draw_fraction_bar(panel_position + Vector2(0.0, 18.0), bar_size, "HULL", target.call("get_hull_fraction"), Color(0.74, 0.16, 0.12, 0.95))
	_draw_fraction_bar(panel_position + Vector2(0.0, 40.0), bar_size, "SAIL", target.call("get_sail_fraction"), Color(0.22, 0.62, 0.9, 0.95))
	_draw_fraction_bar(panel_position + Vector2(0.0, 62.0), bar_size, "CREW", target.call("get_crew_fraction"), Color(0.9, 0.72, 0.24, 0.95))

	var notice := ""
	var notice_color := Color(0.96, 0.9, 0.68, 0.98)
	if bool(player.get("is_sunk")):
		notice = "YOUR VESSEL WAS SUNK"
		notice_color = Color(0.9, 0.16, 0.12, 0.98)
	elif bool(target.get("is_sunk")):
		notice = "ENEMY VESSEL SUNK"
		notice_color = Color(0.92, 0.78, 0.22, 0.98)
	elif bool(player.get("is_mast_broken")):
		notice = "MAST BROKEN"
		notice_color = Color(0.9, 0.72, 0.22, 0.98)

	if not notice.is_empty():
		var font := get_theme_default_font()
		var font_size := 30
		var text_size := font.get_string_size(notice, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		var center := size * 0.5
		var rect := Rect2(center - text_size * 0.5 - Vector2(22.0, 16.0), text_size + Vector2(44.0, 32.0))
		draw_rect(rect, Color(0.02, 0.025, 0.03, 0.82), true)
		draw_rect(rect, notice_color.darkened(0.35), false, 2.0)
		draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.25), notice, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, notice_color)


func _draw_fraction_bar(position: Vector2, bar_size: Vector2, label: String, fraction: float, fill_color: Color) -> void:
	var clamped := clampf(fraction, 0.0, 1.0)
	draw_rect(Rect2(position, bar_size), Color(0.03, 0.035, 0.04, 0.82), true)
	draw_rect(Rect2(position + Vector2(2.0, 2.0), Vector2((bar_size.x - 4.0) * clamped, bar_size.y - 4.0)), fill_color, true)
	draw_string(get_theme_default_font(), position + Vector2(0.0, -3.0), "%s %.0f%%" % [label, clamped * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.96, 0.98, 1.0, 0.95))
