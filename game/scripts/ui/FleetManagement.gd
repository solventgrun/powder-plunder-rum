extends Control
class_name FleetManagement

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var session: Node
var cargo_types: Dictionary = {}
var list: VBoxContainer
var summary_label: Label
var ration_sliders: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	session = get_node_or_null("/root/GameSession")
	cargo_types = ContentCatalog.load_cargo_types()
	_build_ui()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
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
	column.add_child(MenuStyle.make_heading("MANAGE FLEET", 26))
	summary_label = MenuStyle.make_heading("", 14, HudStyle.PARCHMENT_DIM)
	column.add_child(summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var back := MenuStyle.make_button("BACK", HudStyle.GOLD_DIM, 15)
	back.pressed.connect(_on_back)
	footer.add_child(back)


func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	ration_sliders.clear()
	if session == null:
		return
	var fleet: Array = session.get("fleet")
	var flagship_index := int(session.get("flagship_index"))
	summary_label.text = "%d ships | Purse: %d | %s" % [fleet.size(), int(session.get("gold")), "Port Royal" if str(session.get("fleet_screen_return")) == "port" else "At sea"]
	for index in range(fleet.size()):
		var ship: Dictionary = fleet[index]
		var panel := PanelContainer.new()
		MenuStyle.style_panel(panel, HudStyle.GOLD if index == flagship_index else HudStyle.GOLD_DIM)
		list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title := FleetScript.get_display_name(ship).to_upper()
		if index == flagship_index:
			title += "  (FLAGSHIP)"
		info.add_child(MenuStyle.make_label(title, 16, HudStyle.GOLD))
		info.add_child(MenuStyle.make_label(_ship_summary(ship), 13, HudStyle.PARCHMENT))
		info.add_child(MenuStyle.make_label(_cargo_summary(ship), 12, HudStyle.PARCHMENT_DIM))
		info.add_child(_make_ration_row(index, ship))

		var button := MenuStyle.make_button("SAIL HER", HudStyle.GOLD_DIM, 14)
		button.disabled = index == flagship_index
		button.pressed.connect(_on_set_flagship.bind(index))
		row.add_child(button)


func _ship_summary(ship: Dictionary) -> String:
	var loadout: Dictionary = ship.get("loadout", {})
	var ship_type: Dictionary = ContentCatalog.load_ship_types().get(str(loadout.get("ship_type", "")), {})
	var ship_class_name := str(ship_type.get("name", loadout.get("ship_type", "Ship")))
	var free_hold := FleetScript.get_free_hold(ship)
	return "%s | %s | free hold %.0f" % [ship_class_name, FleetScript.describe_condition(ship), free_hold]


func _cargo_summary(ship: Dictionary) -> String:
	var manifest := FleetScript.get_manifest(ship)
	if manifest.is_empty():
		return "Hold empty."
	var parts: Array[String] = []
	var value := 0
	for cargo_id in manifest:
		var id := str(cargo_id)
		var units := int(manifest[cargo_id])
		var cargo: Dictionary = cargo_types.get(id, {})
		value += units * int(cargo.get("value", 0))
		parts.append("%s x%d" % [str(cargo.get("name", id)), units])
	return "Hold: %s | value %d" % [", ".join(parts), value]


func _make_ration_row(index: int, ship: Dictionary) -> HBoxContainer:
	var condition: Dictionary = ship.get("condition", {})
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 3
	slider.step = 1
	slider.value = int(condition.get("rum_ration", 1))
	slider.custom_minimum_size = Vector2(150, 0)
	slider.value_changed.connect(_on_ration_changed.bind(index))
	ration_sliders[str(index)] = slider

	var readout := MenuStyle.make_label(_ration_name(int(slider.value)), 13, HudStyle.PARCHMENT)
	readout.custom_minimum_size = Vector2(86, 0)
	slider.set_meta("readout", readout)

	var control := HBoxContainer.new()
	control.add_theme_constant_override("separation", 8)
	control.add_child(slider)
	control.add_child(readout)
	return MenuStyle.make_field_row("Rum ration", control, 94.0)


func _ration_name(value: int) -> String:
	match clampi(value, 0, 3):
		0:
			return "None"
		1:
			return "Sparing"
		2:
			return "Normal"
		_:
			return "Double"


func _on_ration_changed(value: float, index: int) -> void:
	if session == null:
		return
	var fleet: Array = session.get("fleet")
	if index < 0 or index >= fleet.size():
		return
	var ship: Dictionary = fleet[index]
	var condition: Dictionary = ship.get("condition", {})
	condition["rum_ration"] = int(value)
	ship["condition"] = condition
	var slider: HSlider = ration_sliders.get(str(index))
	if slider and slider.has_meta("readout"):
		var readout: Label = slider.get_meta("readout")
		readout.text = _ration_name(int(value))


func _on_set_flagship(index: int) -> void:
	if session:
		session.set_flagship_index(index)
	_refresh()


func _on_back() -> void:
	if session:
		session.leave_fleet_management()
