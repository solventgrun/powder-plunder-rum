extends Control
class_name WindIndicator

# Compass rose: cardinals + gold heading needle + parchment wind arrow, so
# wind-vs-heading (the core sailing decision) is one glance. Both values are
# pushed each frame by DebugPanel.

@export_range(0.0, 360.0, 1.0, "degrees") var wind_direction_degrees: float = 0.0:
	set(value):
		wind_direction_degrees = value
		queue_redraw()

@export_range(0.0, 360.0, 1.0, "degrees") var heading_degrees: float = 0.0:
	set(value):
		heading_degrees = value
		queue_redraw()


# Compass bearing to screen direction (0 = north = up; screen y grows down).
static func _bearing_to_screen(degrees: float) -> Vector2:
	var radians := deg_to_rad(degrees)
	return Vector2(sin(radians), -cos(radians))


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var wind_direction := _bearing_to_screen(wind_direction_degrees)
	var tip := center + wind_direction * radius
	var tail := center - wind_direction * radius * 0.55
	var side := Vector2(-wind_direction.y, wind_direction.x)

	draw_circle(center, radius + 10.0, HudStyle.WOOD)
	draw_arc(center, radius + 10.0, 0.0, TAU, 48, HudStyle.GOLD, 2.5)
	draw_arc(center, radius + 4.0, 0.0, TAU, 48, HudStyle.GOLD_DIM, 1.0)
	for index in range(16):
		var tick_radians := TAU * float(index) / 16.0
		var tick_direction := Vector2(sin(tick_radians), -cos(tick_radians))
		var is_cardinal := index % 4 == 0
		var tick_color := HudStyle.GOLD if is_cardinal else HudStyle.GOLD_DIM
		draw_line(center + tick_direction * (radius - (4.0 if is_cardinal else 1.0)), center + tick_direction * (radius + 4.0), tick_color, 1.5, true)
	_draw_cardinal(center, radius * 0.62, "N", Vector2(0.0, -1.0))
	_draw_cardinal(center, radius * 0.62, "E", Vector2(1.0, 0.0))
	_draw_cardinal(center, radius * 0.62, "S", Vector2(0.0, 1.0))
	_draw_cardinal(center, radius * 0.62, "W", Vector2(-1.0, 0.0))

	# Heading needle: slim gold, under the wind arrow.
	var heading_direction := _bearing_to_screen(heading_degrees)
	var heading_tip := center + heading_direction * (radius - 3.0)
	var heading_side := Vector2(-heading_direction.y, heading_direction.x)
	draw_line(center - heading_direction * radius * 0.3, heading_tip, HudStyle.GOLD, 2.5, true)
	draw_colored_polygon(PackedVector2Array([
		heading_tip + heading_direction * 7.0,
		heading_tip + heading_side * 4.5,
		heading_tip - heading_side * 4.5
	]), HudStyle.GOLD)

	# Wind arrow: chunky parchment, drawn on top.
	draw_line(tail, tip, HudStyle.PARCHMENT, 4.0, true)
	draw_line(tip, tip - wind_direction * 16.0 + side * 9.0, HudStyle.PARCHMENT, 4.0, true)
	draw_line(tip, tip - wind_direction * 16.0 - side * 9.0, HudStyle.PARCHMENT, 4.0, true)
	draw_circle(center, 4.0, HudStyle.GOLD)


func _draw_cardinal(center: Vector2, radius: float, text: String, direction: Vector2) -> void:
	var font := get_theme_default_font()
	var font_size := 12 if text == "N" else 11
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var color := HudStyle.GOLD if text == "N" else HudStyle.PARCHMENT_DIM
	draw_string(font, center + direction * radius - text_size * 0.5 + Vector2(0.0, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
