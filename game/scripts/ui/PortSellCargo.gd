extends Control
class_name PortSellCargo

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var session: Node
var cargo_types: Dictionary = {}
var sale_sliders: Dictionary = {}
var value_label: Label
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
	column.add_child(MenuStyle.make_heading("SELL CARGO", 26))
	value_label = MenuStyle.make_heading("", 14, HudStyle.PARCHMENT_DIM)
	column.add_child(value_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_build_cargo_rows()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var back := MenuStyle.make_button("BACK TO PORT", HudStyle.GOLD_DIM, 15)
	back.pressed.connect(_on_back)
	footer.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var sell := MenuStyle.make_button("SELL SELECTED")
	sell.pressed.connect(_on_sell)
	footer.add_child(sell)


func _build_cargo_rows() -> void:
	for child in list.get_children():
		child.queue_free()
	sale_sliders.clear()
	if session == null:
		return
	var fleet: Array = session.get("fleet")
	var any := false
	for index in range(fleet.size()):
		var ship: Dictionary = fleet[index]
		var manifest := FleetScript.get_manifest(ship)
		if manifest.is_empty():
			continue
		any = true
		var panel := PanelContainer.new()
		MenuStyle.style_panel(panel)
		list.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		panel.add_child(column)
		column.add_child(MenuStyle.make_label(FleetScript.get_display_name(ship).to_upper(), 15, HudStyle.GOLD))
		for cargo_id in manifest:
			var id := str(cargo_id)
			var units := int(manifest[cargo_id])
			if units <= 0:
				continue
			var cargo: Dictionary = cargo_types.get(id, {})
			var slider := _make_slider(units)
			var key := "%d:%s" % [index, id]
			sale_sliders[key] = slider
			slider.value_changed.connect(_refresh)
			var label := "%s (%d each)" % [str(cargo.get("name", id)), int(cargo.get("value", 0))]
			column.add_child(MenuStyle.make_field_row(label, _with_value(slider), 190.0))
	if not any:
		list.add_child(MenuStyle.make_label("No cargo aboard the fleet.", 14, HudStyle.PARCHMENT_DIM))


func _refresh(_value: Variant = null) -> void:
	var total := 0
	for key in sale_sliders:
		var parts := str(key).split(":")
		var cargo_id := str(parts[1])
		var units := int(sale_sliders[key].value)
		total += units * int(cargo_types.get(cargo_id, {}).get("value", 0))
	value_label.text = "Purse: %d | Selected sale: %d" % [int(session.get("gold")) if session else 0, total]
	for key in sale_sliders:
		var box: HBoxContainer = sale_sliders[key].get_meta("value_box")
		var readout: Label = box.get_child(1)
		readout.text = "%d / %d" % [int(sale_sliders[key].value), int(sale_sliders[key].max_value)]


func _on_sell() -> void:
	if session == null:
		return
	var fleet: Array = session.get("fleet")
	var proceeds := 0
	for key in sale_sliders:
		var units := int(sale_sliders[key].value)
		if units <= 0:
			continue
		var parts := str(key).split(":")
		var ship_index := int(parts[0])
		var cargo_id := str(parts[1])
		var ship: Dictionary = fleet[ship_index]
		var manifest := FleetScript.get_manifest(ship).duplicate()
		manifest[cargo_id] = maxi(0, int(manifest.get(cargo_id, 0)) - units)
		if int(manifest[cargo_id]) <= 0:
			manifest.erase(cargo_id)
		FleetScript.set_manifest(ship, manifest)
		proceeds += units * int(cargo_types.get(cargo_id, {}).get("value", 0))
	session.set("gold", int(session.get("gold")) + proceeds)
	_build_cargo_rows()
	_refresh()


func _on_back() -> void:
	if session:
		session.return_to_port_menu()


func _make_slider(maximum: int) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = maximum
	slider.step = 1
	slider.custom_minimum_size = Vector2(190.0, 0.0)
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
