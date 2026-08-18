class_name DuelHud
extends Control

# The duel's readout, in the HUD register from HudStyle (gold-framed dark wood,
# parchment text). It polls the controller rather than being fed state, the same
# way CombatStatusPanel reads the ships — only one-shot events are pushed in.
#
# The numpad legend stays on screen permanently (as in the reference), because
# knowing which key answers which attack IS the game.

const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")
const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

const PHASE_WEAPON_SELECT := "weapon_select"
const PHASE_FIGHTING := "fighting"
const PHASE_FINISHED := "finished"

const VIGOR_COLOR := Color(0.74, 0.16, 0.12, 0.95)
# Warm amber rather than a second red: the two pools must be tellable apart at a
# glance without either reading as a status effect.
const VIGOR_COLOR_OPPONENT := Color(0.85, 0.5, 0.14, 0.95)
const HIGHLIGHT := Color(0.82, 0.66, 0.35, 0.22)
const FLASH_TIME := 0.9

var controller: Node
var phase: String = PHASE_WEAPON_SELECT
var title: String = "DUEL"
var subtitle: String = ""
var weapon_choices: Array = []
var result_text: String = ""
var result_color: Color = HudStyle.PARCHMENT

var _weapons: Dictionary = {}
var _flash_text: String = ""
var _flash_color: Color = HudStyle.PARCHMENT
var _flash_time: float = 0.0
var _support_flash: Dictionary = {"player": 0.0, "opponent": 0.0}


func _ready() -> void:
	_weapons = ContentCatalog.load_duel_weapons()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	for side in _support_flash:
		_support_flash[side] = maxf(0.0, float(_support_flash[side]) - delta)
	queue_redraw()


func flash(text: String, color: Color) -> void:
	_flash_text = text
	_flash_color = color
	_flash_time = FLASH_TIME


# A side's fighters take heart when their captain lands a blow; the bar flares
# so the connection between the duel and the melee is visible, not inferred.
func flash_support(side: String) -> void:
	_support_flash[side] = 0.45


func _draw() -> void:
	match phase:
		PHASE_WEAPON_SELECT:
			_draw_weapon_select()
		PHASE_FIGHTING:
			_draw_fight()
		PHASE_FINISHED:
			_draw_fight()
			_draw_banner(result_text, result_color, 40)


func _draw_weapon_select() -> void:
	var font := get_theme_default_font()
	# Wide enough that the longest blurb clears the rating bars beside it.
	var panel_size := Vector2(660.0, 108.0 + weapon_choices.size() * 74.0)
	var origin := (size - panel_size) * 0.5
	HudStyle.draw_panel(self, Rect2(origin, panel_size))
	draw_string(font, origin + Vector2(30.0, 46.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, HudStyle.GOLD)
	# Difficulty is deliberately not shown or chosen here: it is a new-game
	# setting the duel only consumes (user call 2026-08-17), not a per-fight
	# option. The only choice on this panel is the blade.
	draw_string(font, origin + Vector2(30.0, 74.0), "CHOOSE YOUR STEEL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, HudStyle.PARCHMENT_DIM)

	for index in range(weapon_choices.size()):
		var weapon_id := str(weapon_choices[index])
		var weapon: Dictionary = _weapons.get(weapon_id, {})
		var row := origin + Vector2(30.0, 112.0 + index * 74.0)
		draw_string(font, row, "%d  %s" % [index + 1, str(weapon.get("name", weapon_id)).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, HudStyle.GOLD)
		draw_string(font, row + Vector2(18.0, 22.0), str(weapon.get("summary", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, HudStyle.PARCHMENT_DIM)
		# Speed is the inverse of wind-up: a slower blade is easier to read.
		var speed := clampf(1.6 - float(weapon.get("windup_multiplier", 1.0)), 0.0, 1.0)
		var power := clampf((float(weapon.get("damage_multiplier", 1.0)) - 0.6) / 0.9, 0.0, 1.0)
		_draw_rating(row + Vector2(408.0, 6.0), "SPEED", speed, Color(0.35, 0.68, 0.88, 0.95))
		_draw_rating(row + Vector2(408.0, 28.0), "WEIGHT", power, Color(0.86, 0.55, 0.2, 0.95))


func _draw_rating(at: Vector2, label: String, fraction: float, color: Color) -> void:
	var font := get_theme_default_font()
	draw_string(font, at + Vector2(0.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, HudStyle.PARCHMENT_DIM)
	HudStyle.draw_bar(self, Rect2(at + Vector2(66.0, 0.0), Vector2(112.0, 13.0)), fraction, color)


func _draw_fight() -> void:
	if controller == null:
		return
	var player: Dictionary = controller.get_fighter("player")
	var opponent: Dictionary = controller.get_fighter("opponent")
	if player.is_empty() or opponent.is_empty():
		return

	_draw_fighter_panel(Vector2(38.0, 34.0), player, controller.get_vigor_fraction("player"), VIGOR_COLOR, "player")
	_draw_fighter_panel(Vector2(size.x - 336.0, 34.0), opponent, controller.get_vigor_fraction("opponent"), VIGOR_COLOR_OPPONENT, "opponent")
	_draw_tell(opponent)
	_draw_pad(player)

	if _flash_time > 0.0:
		_draw_banner(_flash_text, _flash_color, 32)


func _draw_fighter_panel(at: Vector2, fighter: Dictionary, vigor: float, color: Color, side: String) -> void:
	var font := get_theme_default_font()
	var has_support: bool = controller.has_support()
	HudStyle.draw_panel(self, Rect2(at - Vector2(14.0, 24.0), Vector2(298.0, 92.0 + (28.0 if has_support else 0.0))))
	var name_text := str(fighter.get("name", "")).to_upper()
	draw_string(font, at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, HudStyle.GOLD)
	HudStyle.draw_bar(self, Rect2(at + Vector2(0.0, 12.0), Vector2(268.0, 17.0)), vigor, color)

	var weapon: Dictionary = fighter.get("weapon", {})
	var subtitle_text := str(fighter.get("subtitle", ""))
	var weapon_text := str(weapon.get("name", ""))
	if not subtitle_text.is_empty():
		weapon_text = "%s  -  %s" % [subtitle_text, weapon_text]
	draw_string(font, at + Vector2(0.0, 48.0), weapon_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, HudStyle.PARCHMENT_DIM)

	if bool(fighter.get("has_pistol", false)):
		var spent := bool(fighter.get("pistol_spent", false))
		var pistol_color := HudStyle.PARCHMENT_DIM if spent else Color(0.9, 0.78, 0.4)
		var pistol_text := "PISTOL SPENT" if spent else "PISTOL LOADED"
		draw_string(font, at + Vector2(158.0, 48.0), pistol_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, pistol_color)

	if not has_support:
		return
	# The fight around the duel: their numbers, falling live. Losing this is a
	# second way to lose the whole action, so it has to be visible at a glance.
	var remaining: int = ceili(float(controller.get_support_count(side)))
	var label: String = str(controller.get_support_label(side))
	var heading := "%d %s" % [remaining, label.to_upper()] if not label.is_empty() else "%d HANDS" % remaining
	draw_string(font, at + Vector2(0.0, 70.0), heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, HudStyle.PARCHMENT)
	var crew_color := Color(0.55, 0.72, 0.45, 0.95)
	if float(_support_flash.get(side, 0.0)) > 0.0:
		crew_color = crew_color.lerp(HudStyle.GOLD, 0.75)
	HudStyle.draw_bar(self, Rect2(at + Vector2(0.0, 76.0), Vector2(268.0, 11.0)), controller.get_support_fraction(side), crew_color)


# The wind-up tell, echoed in the HUD because readability outranks polish: the
# pose is the primary cue, this is the safety net at gameplay distance.
func _draw_tell(opponent: Dictionary) -> void:
	if str(opponent.get("state", "")) != "windup":
		return
	var action := str(opponent.get("action", ""))
	var height := DuelActionScript.height_of(action).to_upper()
	var font := get_theme_default_font()
	var text := "INCOMING  %s" % height
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24)
	var center := Vector2(size.x * 0.5, 108.0)
	var rect := Rect2(center - Vector2(text_size.x * 0.5 + 22.0, 30.0), text_size + Vector2(44.0, 22.0))
	HudStyle.draw_panel(self, rect)
	draw_string(font, center - Vector2(text_size.x * 0.5, -4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.95, 0.72, 0.26))

	# A shrinking bar for how long is left to answer it.
	var remaining := float(opponent.get("state_time", 0.0)) / maxf(0.01, float(opponent.get("state_duration", 1.0)))
	HudStyle.draw_bar(self, Rect2(center - Vector2(90.0, -12.0), Vector2(180.0, 9.0)), remaining, Color(0.9, 0.35, 0.2, 0.95))


func _draw_pad(player: Dictionary) -> void:
	var font := get_theme_default_font()
	var cell := Vector2(84.0, 46.0)
	var origin := size - Vector2(cell.x * 3.0 + 34.0, cell.y * 3.0 + 30.0)
	HudStyle.draw_panel(self, Rect2(origin - Vector2(12.0, 12.0), Vector2(cell.x * 3.0 + 18.0, cell.y * 3.0 + 18.0)))

	var active_action := str(player.get("action", ""))
	for index in range(DuelActionScript.PAD_SLOTS.size()):
		var slot: Array = DuelActionScript.PAD_SLOTS[index]
		var digit := int(slot[0])
		var action := str(slot[1])
		var column := index % 3
		var row := index / 3
		var cell_rect := Rect2(origin + Vector2(column * cell.x, row * cell.y), cell - Vector2(6.0, 6.0))

		var available := not action.is_empty()
		if action == DuelActionScript.PISTOL:
			available = bool(player.get("has_pistol", false)) and not bool(player.get("pistol_spent", false))
		if not action.is_empty() and action == active_action:
			draw_rect(cell_rect, HIGHLIGHT, true)
		draw_rect(cell_rect, HudStyle.GOLD_DIM if available else Color(0.3, 0.26, 0.2, 0.6), false, 1.0)

		var digit_color := HudStyle.GOLD if available else HudStyle.GOLD_DIM
		draw_string(font, cell_rect.position + Vector2(7.0, 17.0), str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, digit_color)
		if action.is_empty():
			continue
		var label := DuelActionScript.label_for(action)
		var label_color := HudStyle.PARCHMENT if available else HudStyle.PARCHMENT_DIM
		draw_string(font, cell_rect.position + Vector2(24.0, 32.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, label_color)
		if action == DuelActionScript.PISTOL and not available:
			var strike_y := cell_rect.position.y + cell_rect.size.y * 0.55
			draw_line(Vector2(cell_rect.position.x + 6.0, strike_y), Vector2(cell_rect.end.x - 6.0, strike_y), Color(0.72, 0.24, 0.18, 0.9), 2.0)


func _draw_banner(text: String, color: Color, font_size: int) -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var center := Vector2(size.x * 0.5, size.y * 0.34)
	var rect := Rect2(center - text_size * 0.5 - Vector2(28.0, 20.0), text_size + Vector2(56.0, 40.0))
	HudStyle.draw_panel(self, rect)
	draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.25), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
