class_name HudStyle
extends RefCounted

# Shared palette and panel painter for the HUD's custom-draw controls.
# Register set by the North Star (docs/design/visual-improvement-plan.md):
# gold-framed dark-wood panels, parchment text, warm highlights. Control-node
# UI gets the same look from game/ui/HudTheme.tres; keep the two in sync.

const GOLD := Color(0.82, 0.66, 0.35)
const GOLD_DIM := Color(0.55, 0.42, 0.2)
const WOOD := Color(0.09, 0.065, 0.045, 0.92)
const WOOD_INSET := Color(0.05, 0.035, 0.02, 0.9)
const PARCHMENT := Color(0.93, 0.87, 0.7)
const PARCHMENT_DIM := Color(0.78, 0.71, 0.55)

static var _panel_box: StyleBoxFlat


static func panel_box() -> StyleBoxFlat:
	if _panel_box == null:
		_panel_box = StyleBoxFlat.new()
		_panel_box.bg_color = WOOD
		_panel_box.border_color = GOLD
		_panel_box.set_border_width_all(2)
		_panel_box.set_corner_radius_all(7)
		_panel_box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		_panel_box.shadow_size = 5
	return _panel_box


static func draw_panel(target: CanvasItem, rect: Rect2) -> void:
	panel_box().draw(target.get_canvas_item(), rect)


# Gold-trimmed dark bar with an inset fill, shared by status and reload bars.
static func draw_bar(target: CanvasItem, rect: Rect2, fraction: float, fill_color: Color) -> void:
	target.draw_rect(rect, WOOD_INSET, true)
	var inset_width := (rect.size.x - 4.0) * clampf(fraction, 0.0, 1.0)
	if inset_width > 0.0:
		target.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(inset_width, rect.size.y - 4.0)), fill_color, true)
	target.draw_rect(rect, GOLD_DIM, false, 1.0)
