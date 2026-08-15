extends Control
class_name OverworldCompass

@export var player_path: NodePath
@export var wind_system_path: NodePath

var player: Node3D
var wind_system: Node


func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D
	wind_system = get_node_or_null(wind_system_path)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var wind_degrees := float(wind_system.wind_direction_degrees) if wind_system else 0.0

	draw_circle(center, radius + 14.0, HudStyle.WOOD)
	draw_arc(center, radius + 14.0, 0.0, TAU, 72, HudStyle.GOLD, 2.5)
	draw_arc(center, radius + 4.0, 0.0, TAU, 72, HudStyle.GOLD_DIM, 1.0)
	_draw_ticks(center, radius + 8.0)
	_draw_cardinal(center, radius, "N", Vector2(0.0, -1.0))
	_draw_cardinal(center, radius, "E", Vector2(1.0, 0.0))
	_draw_cardinal(center, radius, "S", Vector2(0.0, 1.0))
	_draw_cardinal(center, radius, "W", Vector2(-1.0, 0.0))
	_draw_wind_band(center, radius, wind_degrees)
	draw_string(get_theme_default_font(), Vector2(14.0, size.y - 10.0), "WIND %03d" % int(roundi(wind_degrees)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, HudStyle.PARCHMENT)


func _draw_ticks(center: Vector2, radius: float) -> void:
	for index in range(16):
		var radians := TAU * float(index) / 16.0
		var direction := Vector2(sin(radians), -cos(radians))
		var length := 8.0 if index % 4 == 0 else 4.0
		var color := HudStyle.GOLD if index % 4 == 0 else HudStyle.GOLD_DIM
		draw_line(center + direction * (radius - length), center + direction * radius, color, 1.5, true)


func _draw_wind_band(center: Vector2, radius: float, degrees: float) -> void:
	var start := deg_to_rad(degrees - 12.0) - PI * 0.5
	var end := deg_to_rad(degrees + 12.0) - PI * 0.5
	draw_arc(center, radius + 10.0, start, end, 12, HudStyle.PARCHMENT, 5.0)


func _draw_cardinal(center: Vector2, radius: float, text: String, direction: Vector2) -> void:
	var font := get_theme_default_font()
	var font_size := 19 if text == "N" else 16
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var color := HudStyle.GOLD if text == "N" else HudStyle.PARCHMENT
	draw_string(font, center + direction * radius - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
