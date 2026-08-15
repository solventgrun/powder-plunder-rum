extends Control
class_name AmmoReadout

# Four-slot ammo readout (bottom center): key hint, ammo name, gold highlight
# on the selected slot. Mirrors BroadsideController's ammo_order/selection so
# the choice no longer lives only in debug text.

@export var broadside_path: NodePath

var broadside: Node


func _ready() -> void:
	broadside = get_node_or_null(broadside_path)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if broadside == null:
		return
	var order: Array = broadside.get("ammo_order")
	var types: Dictionary = broadside.get("ammo_types")
	var selected := str(broadside.get("selected_ammo_id"))
	if order.is_empty():
		return

	var font := get_theme_default_font()
	var slot_size := Vector2(64.0, 34.0)
	var gap := 6.0
	var total_width := slot_size.x * float(order.size()) + gap * float(order.size() - 1)
	var origin := Vector2((size.x - total_width) * 0.5, size.y - 62.0)
	HudStyle.draw_panel(self, Rect2(origin + Vector2(-10.0, -10.0), Vector2(total_width + 20.0, slot_size.y + 20.0)))

	for index in range(order.size()):
		var ammo_id := str(order[index])
		var rect := Rect2(origin + Vector2(float(index) * (slot_size.x + gap), 0.0), slot_size)
		var is_selected := ammo_id == selected
		draw_rect(rect, HudStyle.WOOD_INSET, true)
		draw_rect(rect, HudStyle.GOLD if is_selected else HudStyle.GOLD_DIM, false, 2.0 if is_selected else 1.0)
		draw_string(font, rect.position + Vector2(4.0, 12.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, HudStyle.PARCHMENT_DIM)
		var ammo: Resource = types.get(ammo_id)
		var label := str(ammo.get("display_name")).split(" ")[0] if ammo else ammo_id.capitalize()
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
		var text_color := HudStyle.PARCHMENT if is_selected else HudStyle.PARCHMENT_DIM
		draw_string(font, Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, rect.position.y + 24.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, text_color)
