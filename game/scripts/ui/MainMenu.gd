extends Control
class_name MainMenu

# The first screen the game shows. Two ways in: the campaign, or the practice
# yard — a naval battle with both ships hand-built, so a loadout can be tried
# without editing data/ships/player_ship.yaml and restarting.

const BUILD_TAGLINE := "A Caribbean sailing prototype"

var start_button: Button
var practice_button: Button
var quit_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	start_button.grab_focus()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = MenuStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Menu"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	MenuStyle.style_panel(panel, HudStyle.GOLD)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(400.0, 0.0)
	panel.add_child(column)

	column.add_child(MenuStyle.make_heading("POWDER, PLUNDER & RUM", 30))
	column.add_child(MenuStyle.make_heading(BUILD_TAGLINE, 13, HudStyle.PARCHMENT_DIM))
	column.add_child(MenuStyle.make_separator())

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)

	start_button = MenuStyle.make_button("START GAME")
	start_button.name = "StartGameButton"
	start_button.tooltip_text = "Sail the Caribbean from Port Royal."
	start_button.pressed.connect(_on_start_pressed)
	actions.add_child(start_button)

	practice_button = MenuStyle.make_button("PRACTICE NAVAL COMBAT")
	practice_button.name = "PracticeButton"
	practice_button.tooltip_text = "Build both ships and fight a one-off battle."
	practice_button.pressed.connect(_on_practice_pressed)
	actions.add_child(practice_button)

	quit_button = MenuStyle.make_button("QUIT", HudStyle.GOLD_DIM, 16)
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(_on_quit_pressed)
	actions.add_child(quit_button)


func _on_start_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session:
		session.start_new_game()


func _on_practice_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session:
		session.open_practice_setup()


func _on_quit_pressed() -> void:
	get_tree().quit()
