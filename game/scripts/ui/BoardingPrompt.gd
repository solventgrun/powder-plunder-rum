extends Control
class_name BoardingPrompt

# Tells the player when grapples can be thrown, and — more usefully — how much
# fight is left in the deck they are about to jump onto. Boarding is never
# blocked by their condition (user call 2026-08-17), so this is the only place
# the game teaches that softening a crew first is worth doing.

@export var boarding_path: NodePath
# Start hinting before you are alongside, so closing in feels intentional.
@export var hint_distance_multiplier: float = 2.4

var boarding: Node


func _ready() -> void:
	boarding = get_node_or_null(boarding_path)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if boarding == null:
		return
	if bool(boarding.get("is_boarding")):
		var boarded_by_enemy := str(boarding.get("initiator")) == "enemy"
		_draw_prompt("THEY ARE COMING ABOARD!" if boarded_by_enemy else "GRAPPLES AWAY!", "", HudStyle.GOLD)
		return
	# A warning worth more than the prompt: she has turned to close with you and
	# means to board. You still choose whether to board her first.
	if bool(boarding.get("enemy_intends_boarding")):
		var line := "PRESS  F  TO BOARD HER FIRST" if bool(boarding.get("is_available")) else _condition_line()
		_draw_prompt("SHE MEANS TO BOARD US!", line, Color(0.95, 0.55, 0.2))
		return
	if bool(boarding.get("is_available")):
		_draw_prompt("PRESS  F  TO BOARD", _condition_line(), HudStyle.GOLD)
		return

	var gap: float = boarding.call("get_hull_gap")
	var alongside: float = boarding.call("get_alongside_gap")
	if gap <= alongside * hint_distance_multiplier:
		_draw_prompt(str(boarding.get("block_reason")), _condition_line(), HudStyle.PARCHMENT_DIM)


func _condition_line() -> String:
	var condition: float = boarding.call("get_enemy_condition")
	var state := "FRESH"
	if condition <= 0.22:
		state = "BROKEN"
	elif condition <= 0.45:
		state = "WEARY"
	elif condition <= 0.72:
		state = "STEADY"
	return "THEIR DECK: %s" % state


func _draw_prompt(text: String, subtext: String, color: Color) -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20)
	var panel_width := maxf(text_size.x + 44.0, 250.0)
	var panel_height := 46.0 if subtext.is_empty() else 68.0
	var origin := Vector2((size.x - panel_width) * 0.5, size.y - 158.0)
	HudStyle.draw_panel(self, Rect2(origin, Vector2(panel_width, panel_height)))
	draw_string(font, Vector2(origin.x + (panel_width - text_size.x) * 0.5, origin.y + 30.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, color)
	if subtext.is_empty():
		return
	var sub_size := font.get_string_size(subtext, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
	draw_string(font, Vector2(origin.x + (panel_width - sub_size.x) * 0.5, origin.y + 54.0), subtext, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, HudStyle.PARCHMENT_DIM)
