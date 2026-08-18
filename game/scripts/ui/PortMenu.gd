extends Control
class_name PortMenu

const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var session: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	session = get_node_or_null("/root/GameSession")
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_leave()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = MenuStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	MenuStyle.style_panel(panel, HudStyle.GOLD)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(430.0, 0.0)
	panel.add_child(column)

	column.add_child(MenuStyle.make_heading("PORT ROYAL", 28))
	column.add_child(MenuStyle.make_heading(_fleet_summary(), 13, HudStyle.PARCHMENT_DIM))
	column.add_child(MenuStyle.make_separator())

	var sell := MenuStyle.make_button("SELL CARGO")
	sell.pressed.connect(func(): session.open_port_sell_cargo())
	column.add_child(sell)

	var provisions := MenuStyle.make_button("BUY PROVISIONS")
	provisions.pressed.connect(func(): session.open_port_buy_provisions())
	column.add_child(provisions)

	var repair := MenuStyle.make_button("REPAIR SHIPS")
	repair.pressed.connect(func(): session.open_port_repair())
	column.add_child(repair)

	var hire := MenuStyle.make_button("HIRE CREW")
	hire.pressed.connect(func(): session.open_port_hire_crew())
	column.add_child(hire)

	var fleet := MenuStyle.make_button("MANAGE FLEET")
	fleet.pressed.connect(func(): session.open_fleet_management(true))
	column.add_child(fleet)

	column.add_child(MenuStyle.make_separator())
	var leave := MenuStyle.make_button("LEAVE PORT", HudStyle.GOLD_DIM, 16)
	leave.pressed.connect(_on_leave)
	column.add_child(leave)


func _fleet_summary() -> String:
	if session == null:
		return ""
	var fleet: Array = session.get("fleet")
	var flagship: Dictionary = session.call("get_flagship")
	return "%d ships in company | Flagship: %s | Purse: %d" % [fleet.size(), FleetScript.get_display_name(flagship), int(session.get("gold"))]


func _on_leave() -> void:
	if session:
		session.leave_port()
