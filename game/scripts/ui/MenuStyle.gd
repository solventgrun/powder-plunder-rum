class_name MenuStyle
extends RefCounted

# Control-node dressing for the front-end screens (main menu, practice setup).
# The in-battle HUD paints itself with HudStyle; menus are built from real
# Buttons and SpinBoxes, so they need the same palette expressed as styleboxes.
# Keep the two files agreeing — HudStyle owns the colours, this owns the widgets.

const BACKDROP := Color(0.043, 0.062, 0.086)
const BACKDROP_LOW := Color(0.02, 0.03, 0.045)
const DANGER := Color(0.87, 0.36, 0.27)
const CAUTION := Color(0.92, 0.68, 0.28)
const APPROVE := Color(0.55, 0.78, 0.5)


static func panel_style(border: Color = HudStyle.GOLD_DIM) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = HudStyle.WOOD
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	box.set_content_margin_all(14.0)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 5
	return box


static func style_panel(panel: PanelContainer, border: Color = HudStyle.GOLD_DIM) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(border))


# Buttons get a wood plate with a gold edge that brightens on hover and sinks
# when pressed, so a menu still reads as part of the ship rather than as Godot's
# default grey chrome.
static func style_button(button: Button, accent: Color = HudStyle.GOLD) -> void:
	button.add_theme_stylebox_override("normal", _button_box(HudStyle.WOOD, accent.darkened(0.25), 2))
	button.add_theme_stylebox_override("hover", _button_box(HudStyle.WOOD.lightened(0.08), accent, 2))
	button.add_theme_stylebox_override("pressed", _button_box(HudStyle.WOOD_INSET, accent, 2))
	button.add_theme_stylebox_override("focus", _button_box(Color(0, 0, 0, 0), accent, 1))
	button.add_theme_stylebox_override("disabled", _button_box(HudStyle.WOOD_INSET, HudStyle.GOLD_DIM.darkened(0.45), 1))
	button.add_theme_color_override("font_color", HudStyle.PARCHMENT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_focus_color", HudStyle.PARCHMENT)
	button.add_theme_color_override("font_disabled_color", HudStyle.PARCHMENT_DIM.darkened(0.5))


static func make_button(text: String, accent: Color = HudStyle.GOLD, font_size: int = 18) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", font_size)
	style_button(button, accent)
	return button


static func make_label(text: String, font_size: int = 15, color: Color = HudStyle.PARCHMENT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func make_heading(text: String, font_size: int = 20, color: Color = HudStyle.GOLD) -> Label:
	var label := make_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# A labelled row: caption on the left, the control filling the rest. Every
# setting on the practice screen is one of these, so they line up without a grid.
static func make_field_row(caption: String, control: Control, caption_width: float = 118.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := make_label(caption, 14, HudStyle.PARCHMENT_DIM)
	label.custom_minimum_size = Vector2(caption_width, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


static func make_separator() -> HSeparator:
	var separator := HSeparator.new()
	var box := StyleBoxLine.new()
	box.color = HudStyle.GOLD_DIM
	box.thickness = 1
	separator.add_theme_stylebox_override("separator", box)
	return separator


static func _button_box(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(5)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 9.0
	box.content_margin_bottom = 9.0
	return box
