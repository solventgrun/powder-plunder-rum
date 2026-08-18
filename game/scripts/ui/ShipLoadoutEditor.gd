extends PanelContainer
class_name ShipLoadoutEditor

# One editable ship on the practice-battle setup screen. Produces the same
# record shape the YAML files hold (data/ships/player_ship.yaml), so everything
# downstream — stats, visuals, broadsides, validation — treats a hand-built
# ship exactly like a shipped one.
#
# Built from code rather than a .tscn because the control set is data-driven:
# a row per cannon type, a checkbox per modification, an entry per ship type.
# Adding a cannon to the YAML should grow this screen without anyone opening it.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

signal loadout_changed

const SIDES := ["port", "starboard"]

var ship_type_records: Array[Dictionary] = []
var cannon_type_records: Array[Dictionary] = []
var faction_records: Array[Dictionary] = []
var modification_records: Array[Dictionary] = []

# Fields the screen does not edit (visual_variant, sail_set) ride along from the
# record this editor was seeded with, so the built ship stays complete.
var _carried_fields: Dictionary = {}
var _ship_type_option: OptionButton
var _faction_option: OptionButton
var _crew_spin: SpinBox
var _cargo_spin: SpinBox
var _cannon_spins: Dictionary = {}
var _modification_checks: Dictionary = {}
var _gun_labels: Dictionary = {}
var _load_label: Label
var _crew_label: Label
var _suppress_signals: bool = false


func setup(title: String, seed_record: Dictionary, accent: Color) -> void:
	ship_type_records = ContentCatalog.load_ship_type_records()
	cannon_type_records = ContentCatalog.load_cannon_type_records()
	faction_records = ContentCatalog.load_faction_records()
	modification_records = ContentCatalog.load_ship_modification_records()
	MenuStyle.style_panel(self, accent)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui(title, accent)
	apply_record(seed_record)


# Rebuilds every control from a record — used to seed the editor and to restore
# the loadout the tester had when a practice battle hands them back here.
func apply_record(record: Dictionary) -> void:
	_suppress_signals = true
	_carried_fields = {
		"visual_variant": str(record.get("visual_variant", "worn")),
		"sail_set": str(record.get("sail_set", "full"))
	}
	_select_by_id(_ship_type_option, str(record.get("ship_type", "")))
	_select_by_id(_faction_option, str(record.get("faction", "")))

	for side in SIDES:
		var counts := _count_cannons(record, side)
		for cannon_id in _cannon_spins[side]:
			_cannon_spins[side][cannon_id].value = float(counts.get(cannon_id, 0))

	var selected_modifications: Array = record.get("modifications", [])
	for modification_id in _modification_checks:
		_modification_checks[modification_id].button_pressed = selected_modifications.has(modification_id)

	# Crew and cargo are clamped by the hull, so their limits must be in place
	# before the seeded values land or a big ship's crew would be cut down to a
	# small ship's maximum.
	_apply_ship_type_limits()
	_crew_spin.value = float(record.get("crew", _crew_spin.max_value))
	_cargo_spin.value = float(record.get("cargo_weight", 0.0))
	_suppress_signals = false
	_refresh_readouts()
	loadout_changed.emit()


func build_record() -> Dictionary:
	var record := {
		"ship_type": _selected_id(_ship_type_option),
		"faction": _selected_id(_faction_option),
		"visual_variant": _carried_fields.get("visual_variant", "worn"),
		"sail_set": _carried_fields.get("sail_set", "full"),
		"crew": int(_crew_spin.value),
		"cargo_weight": int(_cargo_spin.value),
		"modifications": _selected_modifications(),
		"broadsides": {}
	}
	for side in SIDES:
		var cannons: Array = []
		for cannon_id in _cannon_spins[side]:
			for _index in range(int(_cannon_spins[side][cannon_id].value)):
				cannons.append(cannon_id)
		record["broadsides"][side] = {"cannons": cannons}
	return record


func get_selected_ship_type() -> Dictionary:
	var ship_type_id := _selected_id(_ship_type_option)
	for record in ship_type_records:
		if str(record.get("id", "")) == ship_type_id:
			return record
	return {}


func _build_ui(title: String, accent: Color) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)

	column.add_child(MenuStyle.make_heading(title, 19, accent))

	# Load and crew ride directly under the title rather than at the foot of the
	# column: they are the two numbers that decide whether a loadout is legal,
	# and a long battery list must never scroll them out of sight.
	var summary := HBoxContainer.new()
	_load_label = MenuStyle.make_label("", 14)
	summary.add_child(_load_label)
	var summary_spacer := Control.new()
	summary_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(summary_spacer)
	_crew_label = MenuStyle.make_label("", 14)
	summary.add_child(_crew_label)
	column.add_child(summary)
	column.add_child(MenuStyle.make_separator())

	_ship_type_option = _make_option(ship_type_records)
	_ship_type_option.item_selected.connect(_on_ship_type_selected)
	column.add_child(MenuStyle.make_field_row("Ship", _ship_type_option))

	_faction_option = _make_option(faction_records)
	_faction_option.item_selected.connect(_on_control_changed)
	column.add_child(MenuStyle.make_field_row("Colours", _faction_option))

	_crew_spin = _make_spin(0.0, 999.0)
	_crew_spin.value_changed.connect(_on_control_changed)
	column.add_child(MenuStyle.make_field_row("Crew", _crew_spin))

	_cargo_spin = _make_spin(0.0, 9999.0)
	_cargo_spin.value_changed.connect(_on_control_changed)
	column.add_child(MenuStyle.make_field_row("Cargo weight", _cargo_spin))

	for side in SIDES:
		column.add_child(MenuStyle.make_separator())
		var heading := HBoxContainer.new()
		heading.add_child(MenuStyle.make_label("%s BATTERY" % side.to_upper(), 14, HudStyle.GOLD))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(spacer)
		var gun_label := MenuStyle.make_label("", 13, HudStyle.PARCHMENT_DIM)
		heading.add_child(gun_label)
		_gun_labels[side] = gun_label
		column.add_child(heading)

		_cannon_spins[side] = {}
		for cannon_record in cannon_type_records:
			var cannon_id := str(cannon_record.get("id", ""))
			if cannon_id.is_empty():
				continue
			var spin := _make_spin(0.0, 60.0)
			spin.value_changed.connect(_on_control_changed)
			_cannon_spins[side][cannon_id] = spin
			var caption := "%s (%d)" % [str(cannon_record.get("name", cannon_id)), int(cannon_record.get("weight", 0))]
			column.add_child(MenuStyle.make_field_row(caption, spin, 160.0))

	if not modification_records.is_empty():
		column.add_child(MenuStyle.make_separator())
		column.add_child(MenuStyle.make_label("MODIFICATIONS", 14, HudStyle.GOLD))
		for modification_record in modification_records:
			var modification_id := str(modification_record.get("id", ""))
			if modification_id.is_empty():
				continue
			var check := CheckBox.new()
			check.text = str(modification_record.get("name", modification_id))
			check.add_theme_color_override("font_color", HudStyle.PARCHMENT)
			check.add_theme_font_size_override("font_size", 14)
			check.toggled.connect(_on_control_changed)
			_modification_checks[modification_id] = check
			column.add_child(check)


func _on_ship_type_selected(_index: int) -> void:
	if _suppress_signals:
		return
	_suppress_signals = true
	_apply_ship_type_limits()
	_suppress_signals = false
	_refresh_readouts()
	loadout_changed.emit()


func _on_control_changed(_value: Variant = null) -> void:
	if _suppress_signals:
		return
	_refresh_readouts()
	loadout_changed.emit()


# The hull decides how many hands and how much cargo it can take, so the
# spinners follow the chosen ship type rather than letting the player type a
# number the validator will only reject a moment later.
func _apply_ship_type_limits() -> void:
	var combat: Dictionary = get_selected_ship_type().get("combat", {})
	_crew_spin.max_value = float(combat.get("max_crew", 999))
	_crew_spin.value = minf(_crew_spin.value, _crew_spin.max_value)
	_cargo_spin.max_value = float(combat.get("usable_load_capacity", 9999))
	_cargo_spin.value = minf(_cargo_spin.value, _cargo_spin.max_value)


func _refresh_readouts() -> void:
	var combat: Dictionary = get_selected_ship_type().get("combat", {})
	var gun_ports_per_side := int(floori(int(combat.get("gun_ports", 0)) / 2))
	for side in SIDES:
		var carried := _count_side_cannons(side)
		var label: Label = _gun_labels[side]
		label.text = "%d / %d gun ports" % [carried, gun_ports_per_side]
		# Surplus guns are stowed rather than lost, so this is a caution, not a
		# fault: they still weigh on the hull but cannot be run out.
		label.add_theme_color_override("font_color", MenuStyle.CAUTION if carried > gun_ports_per_side else HudStyle.PARCHMENT_DIM)

	var capacity := float(combat.get("usable_load_capacity", 0.0))
	var total_load := _calculate_cannon_weight() + _cargo_spin.value
	_load_label.text = "Load  %d / %d" % [int(total_load), int(capacity)]
	_load_label.add_theme_color_override("font_color", MenuStyle.DANGER if total_load > capacity else HudStyle.PARCHMENT)

	var max_crew := float(combat.get("max_crew", 0.0))
	_crew_label.text = "Crew  %d / %d" % [int(_crew_spin.value), int(max_crew)]
	_crew_label.add_theme_color_override("font_color", MenuStyle.DANGER if _crew_spin.value > max_crew else HudStyle.PARCHMENT)


func _calculate_cannon_weight() -> float:
	var weight := 0.0
	for cannon_record in cannon_type_records:
		var cannon_id := str(cannon_record.get("id", ""))
		var count := 0
		for side in SIDES:
			if _cannon_spins[side].has(cannon_id):
				count += int(_cannon_spins[side][cannon_id].value)
		weight += float(cannon_record.get("weight", 0.0)) * count
	return weight


func _count_side_cannons(side: String) -> int:
	var count := 0
	for cannon_id in _cannon_spins[side]:
		count += int(_cannon_spins[side][cannon_id].value)
	return count


func _count_cannons(record: Dictionary, side: String) -> Dictionary:
	var counts := {}
	var broadsides: Dictionary = record.get("broadsides", {})
	var broadside: Dictionary = broadsides.get(side, {})
	for cannon_id in broadside.get("cannons", []):
		var id := str(cannon_id)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _selected_modifications() -> Array:
	var selected: Array = []
	for modification_id in _modification_checks:
		if _modification_checks[modification_id].button_pressed:
			selected.append(modification_id)
	return selected


func _make_option(records: Array[Dictionary]) -> OptionButton:
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 14)
	MenuStyle.style_button(option)
	for record in records:
		var id := str(record.get("id", ""))
		if id.is_empty():
			continue
		option.add_item(str(record.get("name", id)))
		option.set_item_metadata(option.item_count - 1, id)
	return option


func _make_spin(minimum: float, maximum: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1.0
	spin.custom_minimum_size = Vector2(88.0, 0.0)
	spin.get_line_edit().add_theme_color_override("font_color", HudStyle.PARCHMENT)
	spin.get_line_edit().add_theme_font_size_override("font_size", 14)
	return spin


func _select_by_id(option: OptionButton, id: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == id:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)


func _selected_id(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))
