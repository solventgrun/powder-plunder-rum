extends Control
class_name PortRepair

const FleetScript := preload("res://game/scripts/session/Fleet.gd")

const HULL_POINT_COST := 2
const SAIL_POINT_COST := 1

var session: Node
var repair_sliders: Dictionary = {}
var value_label: Label
var repair_button: Button
var list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	session = get_node_or_null("/root/GameSession")
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
	column.add_child(MenuStyle.make_heading("REPAIR SHIPS", 26))
	value_label = MenuStyle.make_heading("", 14, HudStyle.PARCHMENT_DIM)
	column.add_child(value_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_build_rows()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var back := MenuStyle.make_button("BACK TO PORT", HudStyle.GOLD_DIM, 15)
	back.pressed.connect(_on_back)
	footer.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	repair_button = MenuStyle.make_button("MAKE REPAIRS")
	repair_button.pressed.connect(_on_repair)
	footer.add_child(repair_button)


func _build_rows() -> void:
	for child in list.get_children():
		child.queue_free()
	repair_sliders.clear()
	if session == null:
		return
	var fleet: Array = session.get("fleet")
	for index in range(fleet.size()):
		var ship: Dictionary = fleet[index]
		var condition: Dictionary = ship.get("condition", {})
		var hull_missing := maxi(0, 100 - int(round(float(condition.get("hull_fraction", 1.0)) * 100.0)))
		var sail_missing := maxi(0, 100 - int(round(float(condition.get("sail_fraction", 1.0)) * 100.0)))
		var panel := PanelContainer.new()
		MenuStyle.style_panel(panel)
		list.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		panel.add_child(column)
		column.add_child(MenuStyle.make_label(FleetScript.get_display_name(ship).to_upper(), 15, HudStyle.GOLD))
		column.add_child(MenuStyle.make_label(FleetScript.describe_condition(ship), 13, HudStyle.PARCHMENT_DIM))
		var hull := _make_slider(hull_missing)
		var hull_key := "%d:hull" % index
		repair_sliders[hull_key] = hull
		hull.value_changed.connect(_refresh)
		column.add_child(MenuStyle.make_field_row("Hull repair (%d each)" % HULL_POINT_COST, _with_value(hull), 170.0))
		var sail := _make_slider(sail_missing)
		var sail_key := "%d:sail" % index
		repair_sliders[sail_key] = sail
		sail.value_changed.connect(_refresh)
		column.add_child(MenuStyle.make_field_row("Sail repair (%d each)" % SAIL_POINT_COST, _with_value(sail), 170.0))


func _refresh(_value: Variant = null) -> void:
	var cost := _selected_cost()
	var purse := int(session.get("gold")) if session else 0
	value_label.text = "Purse: %d | Selected repairs: %d" % [purse, cost]
	if repair_button:
		repair_button.disabled = cost <= 0 or cost > purse
		repair_button.tooltip_text = "Sell cargo before ordering these repairs." if cost > purse else ""
	for key in repair_sliders:
		var box: HBoxContainer = repair_sliders[key].get_meta("value_box")
		var readout: Label = box.get_child(1)
		readout.text = "%d / %d" % [int(repair_sliders[key].value), int(repair_sliders[key].max_value)]


func _selected_cost() -> int:
	var cost := 0
	for key in repair_sliders:
		var kind := str(key).split(":")[1]
		cost += int(repair_sliders[key].value) * (HULL_POINT_COST if kind == "hull" else SAIL_POINT_COST)
	return cost


func _on_repair() -> void:
	if session == null:
		return
	var cost := _selected_cost()
	if cost <= 0 or cost > int(session.get("gold")):
		return
	var fleet: Array = session.get("fleet")
	for key in repair_sliders:
		var amount := int(repair_sliders[key].value)
		if amount <= 0:
			continue
		var parts := str(key).split(":")
		var ship: Dictionary = fleet[int(parts[0])]
		var condition: Dictionary = ship.get("condition", {})
		var field := "hull_fraction" if str(parts[1]) == "hull" else "sail_fraction"
		condition[field] = minf(1.0, float(condition.get(field, 1.0)) + amount / 100.0)
		if field == "sail_fraction" and float(condition[field]) >= 1.0:
			condition["mast_broken"] = false
		ship["condition"] = condition
	session.set("gold", int(session.get("gold")) - cost)
	_build_rows()
	_refresh()


func _on_back() -> void:
	if session:
		session.return_to_port_menu()


func _make_slider(maximum: int) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = maximum
	slider.step = 1
	slider.custom_minimum_size = Vector2(190, 0)
	return slider


func _with_value(slider: HSlider) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var readout := MenuStyle.make_label("0 / %d" % int(slider.max_value), 13)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.custom_minimum_size = Vector2(62, 0)
	box.add_child(slider)
	box.add_child(readout)
	slider.set_meta("value_box", box)
	return box
