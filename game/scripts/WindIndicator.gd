extends Control
class_name WindIndicator

@export_range(0.0, 360.0, 1.0, "degrees") var wind_direction_degrees: float = 0.0:
	set(value):
		wind_direction_degrees = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var radians := deg_to_rad(wind_direction_degrees)
	var direction := Vector2(sin(radians), cos(radians))
	var tip := center + direction * radius
	var tail := center - direction * radius * 0.55
	var side := Vector2(-direction.y, direction.x)

	draw_circle(center, radius + 10.0, Color(0.02, 0.08, 0.12, 0.72))
	draw_arc(center, radius + 10.0, 0.0, TAU, 48, Color(0.65, 0.88, 0.95, 0.8), 2.0)
	draw_line(tail, tip, Color(0.95, 0.98, 0.75), 4.0, true)
	draw_line(tip, tip - direction * 16.0 + side * 9.0, Color(0.95, 0.98, 0.75), 4.0, true)
	draw_line(tip, tip - direction * 16.0 - side * 9.0, Color(0.95, 0.98, 0.75), 4.0, true)
