extends Control
class_name PortBuyProvisions

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

const PROVISIONS_ID := "provisions"

var session: Node
var cargo_types: Dictionary = {}
var buy_sliders: Dictionary = {}
var value_label: Label
var buy_button: Button
var list: VBoxContainer


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
	column.add_child(MenuStyle.make_heading("BUY PROVISIONS", 26))
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
	buy_button = MenuStyle.make_button("BUY SELECTED")
	buy_button.pressed.connect(_on_buy)
	footer.add_child(buy_button)


func _build_rows() -> void:
	for child in list.get_children():
		child.queue_free()
	buy_sliders.clear()
	if session == null:
		return
	var unit_weight := _unit_weight()
	var fleet: Array = session.get("fleet")
	for index in range(fleet.size()):
		var ship: Dictionary = fleet[index]
		var manifest := FleetScript.get_manifest(ship)
		var room := int(floorf(FleetScript.get_free_hold(ship) / unit_weight))
		var panel := PanelContainer.new()
		MenuStyle.style_panel(panel)
		list.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		panel.add_child(column)
		column.add_child(MenuStyle.make_label(FleetScript.get_display_name(ship).to_upper(), 15, HudStyle.GOLD))
		column.add_child(MenuStyle.make_label("Aboard: %d | room for %d more" % [int(manifest.get(PROVISIONS_ID, 0)), room], 13, HudStyle.PARCHMENT_DIM))
		var slider := _make_slider(room)
		buy_sliders[str(index)] = slider
		slider.value_changed.connect(_refresh)
		column.add_child(MenuStyle.make_field_row("Provisions (%d each)" % _unit_cost(), _with_value(slider), 170.0))


func _refresh(_value: Variant = null) -> void:
	var cost := _selected_cost()
	var purse := int(session.get("gold")) if session else 0
	value_label.text = "Purse: %d | Purchase cost: %d" % [purse, cost]
	if buy_button:
		buy_button.disabled = cost <= 0 or cost > purse
		buy_button.tooltip_text = "Sell cargo before buying this many provisions." if cost > purse else ""
	for key in buy_sliders:
		var box: HBoxContainer = buy_sliders[key].get_meta("value_box")
		var readout: Label = box.get_child(1)
		readout.text = "%d / %d" % [int(buy_sliders[key].value), int(buy_sliders[key].max_value)]


func _selected_cost() -> int:
	var cost := 0
	for key in buy_sliders:
		cost += int(buy_sliders[key].value) * _unit_cost()
	return cost


func _on_buy() -> void:
	if session == null:
		return
	var cost := _selected_cost()
	if cost <= 0 or cost > int(session.get("gold")):
		return
	var fleet: Array = session.get("fleet")
	for key in buy_sliders:
		var amount := int(buy_sliders[key].value)
		if amount <= 0:
			continue
		var ship: Dictionary = fleet[int(key)]
		var manifest := FleetScript.get_manifest(ship).duplicate()
		manifest[PROVISIONS_ID] = int(manifest.get(PROVISIONS_ID, 0)) + amount
		FleetScript.set_manifest(ship, manifest)
	session.set("gold", int(session.get("gold")) - cost)
	_build_rows()
	_refresh()


func _unit_weight() -> float:
	return maxf(0.01, float(cargo_types.get(PROVISIONS_ID, {}).get("weight", 1.0)))


func _unit_cost() -> int:
	return int(cargo_types.get(PROVISIONS_ID, {}).get("value", 8))


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
