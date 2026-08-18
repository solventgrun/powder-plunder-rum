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

	# Player status only: enemy strength stays a mystery (user call 2026-08-14).
	# Left side under the compass with clear air between them (compass box ends
	# at y 146); the debug column owns the right (2026-08-17).
	var panel_position := Vector2(38.0, 192.0)
	var ship_name := "Your Ship"
	var stats: Resource = player.get("ship_stats")
	if stats:
		ship_name = str(stats.get("display_name"))
	HudStyle.draw_panel(self, Rect2(panel_position + Vector2(-14.0, -26.0), Vector2(248.0, 118.0)))
	draw_string(get_theme_default_font(), panel_position, ship_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, HudStyle.GOLD)
	_draw_fraction_bar(panel_position + Vector2(0.0, 20.0), "HULL", player.call("get_hull_fraction"), Color(0.74, 0.16, 0.12, 0.95))
	_draw_fraction_bar(panel_position + Vector2(0.0, 44.0), "SAIL", player.call("get_sail_fraction"), Color(0.22, 0.62, 0.9, 0.95))
	_draw_fraction_bar(panel_position + Vector2(0.0, 68.0), "CREW", player.call("get_crew_fraction"), Color(0.9, 0.72, 0.24, 0.95))

	var notice := ""
	var notice_color := HudStyle.PARCHMENT
	if bool(player.get("is_sunk")):
		notice = "YOUR VESSEL WAS SUNK"
		notice_color = Color(0.9, 0.2, 0.14, 0.98)
	elif bool(player.get("has_struck_colors")):
		notice = "YOU ARE CUT DOWN - SHE IS THEIRS"
		notice_color = Color(0.9, 0.2, 0.14, 0.98)
	elif bool(target.get("is_sunk")):
		notice = "ENEMY VESSEL SUNK"
		notice_color = Color(0.95, 0.8, 0.3, 0.98)
	elif bool(target.get("has_struck_colors")):
		notice = "SHE STRIKES HER COLOURS"
		notice_color = Color(0.95, 0.8, 0.3, 0.98)
	elif bool(player.get("is_mast_broken")):
		notice = "MAST BROKEN"
		notice_color = Color(0.92, 0.74, 0.26, 0.98)

	if not notice.is_empty():
		var font := get_theme_default_font()
		var font_size := 30
		var text_size := font.get_string_size(notice, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		var center := size * 0.5
		var rect := Rect2(center - text_size * 0.5 - Vector2(26.0, 18.0), text_size + Vector2(52.0, 36.0))
		HudStyle.draw_panel(self, rect)
		draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.25), notice, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, notice_color)


# Label column left of the bar (playtest: labels drawn over the bars were
# hard to read), percent inside the bar with a drop shadow.
func _draw_fraction_bar(row_position: Vector2, label: String, fraction: float, fill_color: Color) -> void:
	var font := get_theme_default_font()
	var clamped := clampf(fraction, 0.0, 1.0)
	var bar_rect := Rect2(row_position + Vector2(52.0, 0.0), Vector2(168.0, 15.0))
	draw_string(font, row_position + Vector2(0.0, 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, HudStyle.PARCHMENT)
	HudStyle.draw_bar(self, bar_rect, clamped, fill_color)
	var percent := "%.0f%%" % (clamped * 100.0)
	var text_size := font.get_string_size(percent, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10)
	var text_position := Vector2(bar_rect.position.x + bar_rect.size.x - text_size.x - 5.0, bar_rect.position.y + 11.5)
	draw_string(font, text_position + Vector2(1.0, 1.0), percent, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.0, 0.0, 0.0, 0.7))
	draw_string(font, text_position, percent, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, HudStyle.PARCHMENT)
