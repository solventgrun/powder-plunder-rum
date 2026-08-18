extends Control
class_name PracticeSetup

# The practice yard: build both ships, see immediately whether they are legal,
# then sail straight into a naval battle. Beats the alternative of hand-editing
# data/ships/player_ship.yaml and restarting to try one different broadside.
#
# Nothing here is a second source of truth about what a ship may carry —
# ContentValidator answers that, using the same rules that gate the YAML files.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const ContentValidator := preload("res://game/scripts/content/ContentValidator.gd")
const ShipLoadoutEditorScript := preload("res://game/scripts/ui/ShipLoadoutEditor.gd")

const PLAYER_LABEL := "Your ship"
const ENEMY_LABEL := "Enemy ship"

var player_editor: ShipLoadoutEditor
var enemy_editor: ShipLoadoutEditor
var begin_button: Button
var back_button: Button
var reset_button: Button

var _report_label: Label
var _result_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_restore_state()
	_refresh_validation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# The two records the screen currently describes, in the shape the YAML files
# use. Public so the smoke test can build a matchup without clicking anything.
func build_records() -> Dictionary:
	return {"player": player_editor.build_record(), "enemy": enemy_editor.build_record()}


func validate() -> Dictionary:
	var records := build_records()
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for entry in [[PLAYER_LABEL, records["player"]], [ENEMY_LABEL, records["enemy"]]]:
		var result: Dictionary = ContentValidator.validate_runtime_loadout(str(entry[0]), entry[1])
		errors.append_array(result.get("errors", []))
		warnings.append_array(result.get("warnings", []))
	return {"errors": errors, "warnings": warnings}


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = MenuStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	column.add_child(MenuStyle.make_heading("PRACTICE NAVAL COMBAT", 26))
	_result_label = MenuStyle.make_heading("", 14, HudStyle.PARCHMENT_DIM)
	column.add_child(_result_label)

	# The ship columns are the tall part of the screen; let them scroll so a
	# long cannon list never pushes the Begin Battle button off the bottom.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var ships := HBoxContainer.new()
	ships.name = "Ships"
	ships.add_theme_constant_override("separation", 18)
	ships.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ships)

	player_editor = ShipLoadoutEditorScript.new()
	player_editor.name = "PlayerLoadout"
	ships.add_child(player_editor)
	player_editor.setup(PLAYER_LABEL.to_upper(), ContentCatalog.load_player_ship_record(), HudStyle.GOLD)
	player_editor.loadout_changed.connect(_refresh_validation)

	enemy_editor = ShipLoadoutEditorScript.new()
	enemy_editor.name = "EnemyLoadout"
	ships.add_child(enemy_editor)
	enemy_editor.setup(ENEMY_LABEL.to_upper(), ContentCatalog.load_target_ship_record(), MenuStyle.DANGER)
	enemy_editor.loadout_changed.connect(_refresh_validation)

	var report_panel := PanelContainer.new()
	MenuStyle.style_panel(report_panel)
	column.add_child(report_panel)
	_report_label = MenuStyle.make_label("", 13)
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_panel.add_child(_report_label)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)

	back_button = MenuStyle.make_button("BACK TO MENU", HudStyle.GOLD_DIM, 15)
	back_button.name = "BackButton"
	back_button.pressed.connect(_on_back_pressed)
	footer.add_child(back_button)

	reset_button = MenuStyle.make_button("RESET TO DEFAULTS", HudStyle.GOLD_DIM, 15)
	reset_button.name = "ResetButton"
	reset_button.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	begin_button = MenuStyle.make_button("BEGIN BATTLE")
	begin_button.name = "BeginButton"
	begin_button.pressed.connect(_on_begin_pressed)
	footer.add_child(begin_button)


func _restore_state() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var state: Dictionary = session.get("practice_setup_state")
	if state.has("player"):
		player_editor.apply_record(state["player"])
	if state.has("enemy"):
		enemy_editor.apply_record(state["enemy"])

	var result := str(session.get("last_battle_result"))
	if not result.is_empty():
		_result_label.text = "Last battle: %s" % _describe_result(result)


func _refresh_validation() -> void:
	var report := validate()
	var errors: Array = report.get("errors", [])
	var warnings: Array = report.get("warnings", [])

	# Plain words, not symbols: the HUD font has no glyph for a tick or a cross
	# and Godot falls back to a colour emoji that reads as a browser error.
	var lines: Array[String] = []
	for error in errors:
		lines.append("FAULT   %s" % error)
	for warning in warnings:
		lines.append("NOTE    %s" % warning)

	if lines.is_empty():
		_report_label.text = "Both ships are seaworthy."
		_report_label.add_theme_color_override("font_color", MenuStyle.APPROVE)
	else:
		_report_label.text = "\n".join(lines)
		_report_label.add_theme_color_override("font_color", MenuStyle.DANGER if not errors.is_empty() else MenuStyle.CAUTION)

	begin_button.disabled = not errors.is_empty()
	begin_button.tooltip_text = "Fix the faults above before sailing." if begin_button.disabled else ""


func _on_begin_pressed() -> void:
	var records := build_records()
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	session.set("practice_setup_state", records)
	session.start_practice_battle(records["player"], records["enemy"])


func _on_reset_pressed() -> void:
	player_editor.apply_record(ContentCatalog.load_player_ship_record())
	enemy_editor.apply_record(ContentCatalog.load_target_ship_record())


func _on_back_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session:
		session.set("practice_setup_state", build_records())
		session.return_to_main_menu()


func _describe_result(result: String) -> String:
	match result:
		"enemy_sunk":
			return "you sank her."
		"enemy_captured":
			return "she struck her colours."
		"player_sunk":
			return "you went down."
		"player_defeated":
			return "you struck your colours."
		"abandoned":
			return "broken off."
		_:
			return result
