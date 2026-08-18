extends Control
class_name AfterAction

# What the battle cost and what it won — and, when she struck rather than sank,
# what to do about her. This is the first place the game makes a fight matter
# beyond the fight (ADR 0016).
#
# Every decision here is metered against the same hull allowance that already
# drives speed and handling: plunder, guns and cargo all weigh, so the screen is
# really one question asked several ways — what will you carry home?

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")
const GameDifficultyScript := preload("res://game/scripts/content/GameDifficulty.gd")

const FATE_RELEASE := "release"
const FATE_BURN := "burn"
const FATE_SINK := "sink"
const FATE_CONSORT := "consort"
const FATE_FLAGSHIP := "flagship"

# How much of a sunk ship's hold can be fished out of the water is a difficulty
# knob (`post_battle.salvage_fraction`); this is the fallback outside a game.
const DEFAULT_SALVAGE_FRACTION := 0.25

var session: Node
var report: Dictionary = {}
var flagship: Dictionary = {}

var _cargo_types: Dictionary = {}
var _cannon_types: Dictionary = {}
var _prize_manifest: Dictionary = {}
var _take_sliders: Dictionary = {}
var _gun_sliders: Dictionary = {}
var _slider_value_labels: Dictionary = {}
var _recruit_slider: HSlider
var _repair_slider: HSlider
var _fate: String = FATE_RELEASE
var _fate_buttons: Dictionary = {}
var _load_label: Label
var _guns_label: Label
var _note_label: Label
var _confirm_button: Button
var _wounded_recovered: int = 0
var _desertions: int = 0
var _desertion_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	session = get_node_or_null("/root/GameSession")
	_cargo_types = ContentCatalog.load_cargo_types()
	_cannon_types = ContentCatalog.load_cannon_types()
	if session:
		report = session.get("battle_report")
		flagship = session.call("get_flagship")
	_prepare_prize()
	_build_ui()
	_auto_load_hold()
	_refresh()


func is_victory() -> bool:
	return str(report.get("result", "")) in ["enemy_sunk", "enemy_captured"]


func is_capture() -> bool:
	return str(report.get("result", "")) == "enemy_captured"


# What is actually available to take. A ship that struck her colours hands over
# her whole hold; a ship on the bottom yields only what floats.
func _prepare_prize() -> void:
	var manifest: Dictionary = report.get("enemy_manifest", {})
	_prize_manifest = {}
	if not is_victory():
		return
	for cargo_id in manifest:
		var units := int(manifest[cargo_id])
		if not is_capture():
			units = int(floorf(units * GameDifficultyScript.value("post_battle", "salvage_fraction", DEFAULT_SALVAGE_FRACTION)))
		if units > 0:
			_prize_manifest[str(cargo_id)] = units


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
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(MenuStyle.make_heading(_headline(), 26, HudStyle.GOLD if is_victory() else MenuStyle.DANGER))
	_note_label = MenuStyle.make_heading(_subhead(), 14, HudStyle.PARCHMENT_DIM)
	column.add_child(_note_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var panels := HBoxContainer.new()
	panels.name = "Panels"
	panels.add_theme_constant_override("separation", 16)
	panels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panels)

	panels.add_child(_build_own_ship_panel())
	if is_victory():
		panels.add_child(_build_prize_panel())
	if is_capture():
		column.add_child(_build_fate_row())

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)

	_load_label = MenuStyle.make_label("", 14)
	footer.add_child(_load_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(18.0, 0.0)
	footer.add_child(gap)
	_guns_label = MenuStyle.make_label("", 14)
	footer.add_child(_guns_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_confirm_button = MenuStyle.make_button("MAKE SAIL")
	_confirm_button.name = "ConfirmButton"
	_confirm_button.pressed.connect(_on_confirm)
	footer.add_child(_confirm_button)


# The left panel: what the fight did to you, and the stores you can spend on it.
func _build_own_ship_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "OwnShip"
	MenuStyle.style_panel(panel, HudStyle.GOLD)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var lost := str(report.get("result", "")) in ["player_sunk", "player_defeated"]
	column.add_child(MenuStyle.make_heading(FleetScript.get_display_name(flagship).to_upper() if not flagship.is_empty() else "YOUR SHIP", 19, MenuStyle.DANGER if lost else HudStyle.GOLD))
	column.add_child(MenuStyle.make_separator())

	var player_state: Dictionary = report.get("player", {})
	column.add_child(MenuStyle.make_label("Hull   %d%%" % int(round(float(player_state.get("hull_fraction", 1.0)) * 100.0)), 14))
	column.add_child(MenuStyle.make_label("Sail   %d%%" % int(round(float(player_state.get("sail_fraction", 1.0)) * 100.0)), 14))
	column.add_child(MenuStyle.make_label("Crew   %d hands" % int(float(player_state.get("crew", FleetScript.get_crew(flagship)))), 14))
	column.add_child(MenuStyle.make_label("Morale %d%%" % int(float(player_state.get("morale", 100.0))), 14))
	if bool(player_state.get("mast_broken", false)):
		column.add_child(MenuStyle.make_label("Her mast is gone.", 13, MenuStyle.DANGER))

	if lost:
		return panel

	# Medicine is not a choice — the surgeon works on whoever comes below. It is
	# reported rather than offered.
	_wounded_recovered = _apply_medicine()
	if _wounded_recovered > 0:
		column.add_child(MenuStyle.make_label("The surgeon returns %d wounded to duty." % _wounded_recovered, 13, MenuStyle.APPROVE))
	_desertion_label = MenuStyle.make_label("", 13, MenuStyle.CAUTION)
	column.add_child(_desertion_label)

	column.add_child(MenuStyle.make_separator())
	column.add_child(MenuStyle.make_label("SHIP'S STORES", 14, HudStyle.GOLD))

	var stores := FleetScript.get_manifest(flagship)
	var naval_stores := int(stores.get("naval_stores", 0))
	_repair_slider = _make_slider(0, naval_stores, "repair")
	column.add_child(_make_slider_field_row("Repair (stores)", _repair_slider, "repair", 130.0))
	if naval_stores <= 0:
		column.add_child(MenuStyle.make_label("No naval stores aboard to jury-rig with.", 12, HudStyle.PARCHMENT_DIM))

	return panel


# The right panel: her hold, her guns, her crew, and her fate.
func _build_prize_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Prize"
	MenuStyle.style_panel(panel, MenuStyle.DANGER)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	column.add_child(MenuStyle.make_heading(str(report.get("enemy_name", "The Prize")).to_upper(), 19, MenuStyle.DANGER))
	column.add_child(MenuStyle.make_separator())

	if _prize_manifest.is_empty():
		column.add_child(MenuStyle.make_label("Nothing worth taking out of her hold.", 13, HudStyle.PARCHMENT_DIM))
	else:
		column.add_child(MenuStyle.make_label("HER HOLD", 14, HudStyle.GOLD))
		for cargo_id in _prize_manifest:
			var cargo: Dictionary = _cargo_types.get(cargo_id, {})
			var available := int(_prize_manifest[cargo_id])
			var slider := _make_slider(0, available, "take_%s" % str(cargo_id))
			_take_sliders[cargo_id] = slider
			var caption := "%s  (%d wt, %d ea)" % [str(cargo.get("name", cargo_id)), int(cargo.get("weight", 0)), int(cargo.get("value", 0))]
			column.add_child(_make_slider_field_row(caption, slider, "take_%s" % str(cargo_id), 190.0))

	if not is_capture():
		column.add_child(MenuStyle.make_separator())
		column.add_child(MenuStyle.make_label("She is on the bottom. Only what floated could be fished out,\nand her guns went down with her.", 13, HudStyle.PARCHMENT_DIM))
		return panel

	column.add_child(MenuStyle.make_separator())
	column.add_child(MenuStyle.make_label("GUNS", 14, HudStyle.GOLD))
	column.add_child(MenuStyle.make_label("How many you end up with. Below what you carry is throwing\nyours overboard; above it is taking hers.", 12, HudStyle.PARCHMENT_DIM))
	var mine := _count_cannons(flagship.get("loadout", {}))
	var hers := _count_cannons(report.get("enemy_loadout", {}))
	for cannon_id in _cannon_types:
		var owned := int(mine.get(cannon_id, 0))
		var offered := int(hers.get(cannon_id, 0))
		if owned <= 0 and offered <= 0:
			continue
		var slider := _make_slider(0, owned + offered, "gun_%s" % str(cannon_id))
		slider.value = owned
		_gun_sliders[cannon_id] = slider
		var cannon: Resource = _cannon_types[cannon_id]
		var caption := "%s  (%d yours, %d hers)" % [str(cannon.get("display_name")), owned, offered]
		column.add_child(_make_slider_field_row(caption, slider, "gun_%s" % str(cannon_id), 190.0))

	column.add_child(MenuStyle.make_separator())
	var survivors := int(float(report.get("enemy", {}).get("crew", 0.0)))
	var berths := _free_berths()
	_recruit_slider = _make_slider(0, mini(survivors, berths), "recruit")
	# Hands cost nothing to carry and you are always short of them, so the
	# helpful default is all of them — the interesting choice is her fate.
	_recruit_slider.value = _recruit_slider.max_value
	column.add_child(_make_slider_field_row("Take on hands", _recruit_slider, "recruit", 190.0))
	column.add_child(MenuStyle.make_label("%d of her crew still stand; you have berths for %d." % [survivors, berths], 12, HudStyle.PARCHMENT_DIM))
	return panel


# Her fate is the headline decision, so it sits outside the scrolling panels
# where it cannot end up below the fold.
func _build_fate_row() -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.name = "Fate"
	wrapper.add_theme_constant_override("separation", 4)
	wrapper.add_child(MenuStyle.make_label("HER FATE", 14, HudStyle.GOLD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrapper.add_child(row)

	var prize_crew := FleetScript.minimum_prize_crew(report.get("enemy_loadout", {}))
	for option in [
		[FATE_RELEASE, "LET HER GO", "She limps away. No hands spared."],
		[FATE_BURN, "BURN HER", "Nobody sails her again."],
		[FATE_SINK, "SINK HER", "Same, quicker."],
		[FATE_CONSORT, "KEEP AS CONSORT", "She follows you. Costs %d hands to sail her." % prize_crew],
		[FATE_FLAGSHIP, "TAKE HER AS YOUR OWN", "You shift your flag to her. Costs %d hands to sail the ship you leave." % prize_crew]
	]:
		var button := MenuStyle.make_button(str(option[1]), HudStyle.GOLD_DIM, 13)
		button.toggle_mode = true
		button.tooltip_text = str(option[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_fate_selected.bind(str(option[0])))
		_fate_buttons[str(option[0])] = button
		row.add_child(button)
	_fate_buttons[FATE_RELEASE].button_pressed = true
	return wrapper


# Opens the screen with the best hold that actually fits: richest by weight
# first, until she is full. A screen that greeted you already overloaded and
# already blocked would be teaching the constraint by punishing you for it, and
# hand-emptying a dozen sliders is nobody's idea of a decision.
#
# The player is free to disagree — that is what the sliders are for.
func _auto_load_hold() -> void:
	if _take_sliders.is_empty():
		return
	var order := _take_sliders.keys()
	order.sort_custom(func(a, b): return _value_per_ton(a) > _value_per_ton(b))

	var room := _capacity() - _projected_gun_weight() - ContentCatalog.calculate_cargo_weight(FleetScript.get_manifest(flagship), _cargo_types)
	for cargo_id in order:
		var unit_weight := maxf(0.01, float(_cargo_types.get(cargo_id, {}).get("weight", 1.0)))
		var affordable := int(floorf(room / unit_weight))
		var take := clampi(affordable, 0, int(_take_sliders[cargo_id].max_value))
		_take_sliders[cargo_id].value = take
		room -= take * unit_weight


func _projected_desertions() -> int:
	var tuning := GameDifficultyScript.section("morale")
	var morale := float(report.get("player", {}).get("morale", 100.0))
	var crew := float(report.get("player", {}).get("crew", 0.0)) + _wounded_recovered
	var misery := 1.0 - clampf(morale / 100.0, 0.0, 1.0)
	return int(floorf(crew * float(tuning.get("desertion_per_battle", 0.04)) * misery))


func _value_per_ton(cargo_id: String) -> float:
	var cargo: Dictionary = _cargo_types.get(cargo_id, {})
	return float(cargo.get("value", 0.0)) / maxf(float(cargo.get("weight", 1.0)), 0.01)


func _headline() -> String:
	match str(report.get("result", "")):
		"enemy_sunk":
			return "SHE IS SUNK"
		"enemy_captured":
			return "SHE HAS STRUCK HER COLOURS"
		"player_sunk":
			return "YOU WENT DOWN WITH HER"
		"player_defeated":
			return "YOU STRUCK YOUR COLOURS"
		_:
			return "THE ACTION IS OVER"


func _subhead() -> String:
	if is_capture():
		return "She is yours to strip. Anything you take, you carry."
	if is_victory():
		return "What floated is all there is."
	return "The ship is lost."


func _on_control_changed(_value: Variant = null) -> void:
	_refresh()


func _on_fate_selected(fate: String) -> void:
	_fate = fate
	for id in _fate_buttons:
		_fate_buttons[id].button_pressed = id == fate
	_refresh()


func _refresh() -> void:
	if _load_label == null:
		return
	var loadout: Dictionary = flagship.get("loadout", {})
	var capacity := _capacity()
	var gun_weight := _projected_gun_weight()
	var cargo_weight := ContentCatalog.calculate_cargo_weight(_projected_manifest(), _cargo_types)
	var total := gun_weight + cargo_weight

	_load_label.text = "Load  %d / %d" % [int(total), int(capacity)]
	_load_label.add_theme_color_override("font_color", MenuStyle.DANGER if total > capacity else HudStyle.PARCHMENT)

	var ports_per_side := _gun_ports_per_side(loadout)
	var guns := _projected_gun_count()
	var per_side := int(ceilf(guns / 2.0))
	_guns_label.text = "Guns  %d  (%d a side, %d ports)" % [guns, per_side, ports_per_side]
	_guns_label.add_theme_color_override("font_color", MenuStyle.CAUTION if per_side > ports_per_side else HudStyle.PARCHMENT_DIM)

	# Overloading is the one thing this screen will not let you leave with: the
	# ship would sail, but nothing downstream expects a hold past capacity.
	if _confirm_button:
		_confirm_button.disabled = total > capacity
		_confirm_button.tooltip_text = "Leave something behind — she is over her allowance." if _confirm_button.disabled else ""
	_note_label.text = _hold_note(capacity, total)
	if _desertion_label:
		var likely := _projected_desertions()
		_desertion_label.text = "%d hands will slip away before you sail. Rum would hold them." % likely if likely > 0 else ""
	_refresh_slider_labels()


# The screen has to explain itself when it silently takes nothing. A hold full
# of guns is the correct answer and an invisible one: every slider reads zero
# and nothing says why.
func _hold_note(capacity: float, total: float) -> String:
	if not is_victory():
		return _subhead()
	if total > capacity:
		return "She is over her allowance. Leave something behind, or throw guns overboard."
	var left_behind := false
	for cargo_id in _take_sliders:
		if _take_sliders[cargo_id].value < _take_sliders[cargo_id].max_value:
			left_behind = true
	if not left_behind:
		return _subhead()
	if capacity - total < 1.0:
		return "Your guns fill her. Every ton of plunder is a gun over the side."
	return "Her hold is worth more than yours will carry — take the richest and leave the rest."


func _capacity() -> float:
	# Shifting your flag to the prize means her allowance is the one that
	# matters, so the meter has to follow the fate you picked.
	var taking_her := _fate == FATE_FLAGSHIP and is_capture()
	var loadout: Dictionary = report.get("enemy_loadout", {}) if taking_her else flagship.get("loadout", {})
	var ship_types := ContentCatalog.load_ship_types()
	var ship_type: Dictionary = ship_types.get(str(loadout.get("ship_type", "")), {})
	return float(ship_type.get("combat", {}).get("usable_load_capacity", 0.0))


func _gun_ports_per_side(loadout: Dictionary) -> int:
	var ship_types := ContentCatalog.load_ship_types()
	var ship_type: Dictionary = ship_types.get(str(loadout.get("ship_type", "")), {})
	return int(floorf(float(ship_type.get("combat", {}).get("gun_ports", 0)) / 2.0))


func _projected_gun_count() -> int:
	# No gun sliders means no prize to take guns from, so what she carries now
	# is what she leaves with.
	if _gun_sliders.is_empty():
		var owned := _count_cannons(flagship.get("loadout", {}))
		var carried := 0
		for cannon_id in owned:
			carried += int(owned[cannon_id])
		return carried
	var count := 0
	for cannon_id in _gun_sliders:
		count += int(_gun_sliders[cannon_id].value)
	return count


func _projected_gun_weight() -> float:
	if _gun_sliders.is_empty():
		return ContentCatalog.calculate_cannon_weight(flagship.get("loadout", {}), _cannon_types)
	var weight := 0.0
	for cannon_id in _gun_sliders:
		if _cannon_types.has(cannon_id):
			weight += float(_cannon_types[cannon_id].get("weight")) * int(_gun_sliders[cannon_id].value)
	return weight


# Your hold as it would be once you have taken what the sliders say and spent
# what the stores sliders say.
func _projected_manifest() -> Dictionary:
	var manifest := FleetScript.get_manifest(flagship).duplicate()
	for cargo_id in _take_sliders:
		var units := int(_take_sliders[cargo_id].value)
		if units > 0:
			manifest[cargo_id] = int(manifest.get(cargo_id, 0)) + units
	if _repair_slider:
		manifest["naval_stores"] = maxi(0, int(manifest.get("naval_stores", 0)) - int(_repair_slider.value))
	for cargo_id in manifest.keys():
		if int(manifest[cargo_id]) <= 0:
			manifest.erase(cargo_id)
	return manifest


func _free_berths() -> int:
	var ship_types := ContentCatalog.load_ship_types()
	var ship_type: Dictionary = ship_types.get(str(flagship.get("loadout", {}).get("ship_type", "")), {})
	var max_crew := float(ship_type.get("combat", {}).get("max_crew", 0.0))
	var aboard := float(report.get("player", {}).get("crew", FleetScript.get_crew(flagship))) + _wounded_recovered
	return maxi(0, int(max_crew - aboard))


func _apply_medicine() -> int:
	var manifest := FleetScript.get_manifest(flagship)
	var units := int(manifest.get("medicine", 0))
	if units <= 0:
		return 0
	var cargo: Dictionary = _cargo_types.get("medicine", {})
	var per_unit := float(cargo.get("effect", {}).get("crew_per_unit", 0.0))
	var lost := maxf(0.0, FleetScript.get_crew(flagship) - float(report.get("player", {}).get("crew", 0.0)))
	# You cannot recover more men than you lost, and the stores are spent on
	# whoever there was to treat.
	var spent := mini(units, int(ceilf(lost / maxf(per_unit, 0.01))))
	var recovered := mini(int(lost), int(spent * per_unit))
	if recovered <= 0:
		return 0
	manifest["medicine"] = units - spent
	if manifest["medicine"] <= 0:
		manifest.erase("medicine")
	FleetScript.set_manifest(flagship, manifest)
	return recovered


func _count_cannons(loadout: Dictionary) -> Dictionary:
	var counts := {}
	var broadsides: Dictionary = loadout.get("broadsides", {})
	for side in ["port", "starboard"]:
		for cannon_id in broadsides.get(side, {}).get("cannons", []):
			var id := str(cannon_id)
			counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _on_confirm() -> void:
	if session == null:
		return
	_apply_outcome()
	session.call("leave_after_action")


func _apply_outcome() -> void:
	var result := str(report.get("result", ""))
	var fleet: Array = session.get("fleet")
	var flagship_index := int(session.get("flagship_index"))

	if result in ["player_sunk", "player_defeated"]:
		# Sunk or taken, she is gone. With a consort you shift your flag; with
		# none, the campaign is over and leave_after_action sends you to the menu.
		if flagship_index >= 0 and flagship_index < fleet.size():
			session.call("remove_ship", flagship_index)
		return

	_write_back_condition()
	if not is_victory():
		return

	FleetScript.set_manifest(flagship, _projected_manifest())
	_apply_repair()
	_apply_desertion()
	if is_capture():
		_apply_guns()
		FleetScript.set_crew(flagship, FleetScript.get_crew(flagship) + int(_recruit_slider.value))
		_apply_fate()


# Carries the damage out of the battle and onto the ship, which is what makes it
# persist: there is no repair between battles but what you can jury-rig.
func _write_back_condition() -> void:
	var player_state: Dictionary = report.get("player", {})
	if player_state.is_empty() or flagship.is_empty():
		return
	var condition: Dictionary = flagship.get("condition", {})
	condition["hull_fraction"] = float(player_state.get("hull_fraction", 1.0))
	condition["sail_fraction"] = float(player_state.get("sail_fraction", 1.0))
	condition["morale"] = float(player_state.get("morale", 100.0))
	condition["mast_broken"] = bool(player_state.get("mast_broken", false))
	condition["disabled_cannons"] = player_state.get("disabled_cannons", {}).duplicate()
	condition["disabled_gun_ports"] = player_state.get("disabled_gun_ports", {}).duplicate()

	var tuning := GameDifficultyScript.section("morale")
	condition["drunkenness"] = maxf(0.0, float(player_state.get("drunkenness", 0.0)) - float(tuning.get("sober_up_per_battle", 40.0)))
	FleetScript.set_crew(flagship, float(player_state.get("crew", FleetScript.get_crew(flagship))) + _wounded_recovered)


# Men slip away from an unhappy ship between actions. Rum is now a standing
# fleet policy, so this screen only applies the battle's morale consequences.
func _apply_desertion() -> void:
	var condition: Dictionary = flagship.get("condition", {})
	var crew := FleetScript.get_crew(flagship)
	var misery := 1.0 - clampf(float(condition.get("morale", 100.0)) / 100.0, 0.0, 1.0)
	var deserters := floorf(crew * GameDifficultyScript.value("morale", "desertion_per_battle", 0.04) * misery)
	if deserters <= 0.0:
		return
	_desertions = int(deserters)
	FleetScript.set_crew(flagship, maxf(0.0, crew - deserters))


func _apply_repair() -> void:
	if _repair_slider == null or _repair_slider.value <= 0:
		return
	var effect: Dictionary = _cargo_types.get("naval_stores", {}).get("effect", {})
	var stats := ContentCatalog.build_ship_stats(flagship.get("loadout", {}), ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	var units := int(_repair_slider.value)
	var condition: Dictionary = flagship.get("condition", {})
	condition["hull_fraction"] = minf(1.0, float(condition.get("hull_fraction", 1.0)) + units * float(effect.get("hull_per_unit", 0.0)) / maxf(float(stats.get("max_hull")), 1.0))
	condition["sail_fraction"] = minf(1.0, float(condition.get("sail_fraction", 1.0)) + units * float(effect.get("sail_per_unit", 0.0)) / maxf(float(stats.get("max_sail")), 1.0))
	# Canvas back aloft means she is under her own sail again.
	if float(condition["sail_fraction"]) > 0.0:
		condition["mast_broken"] = false


# Rebuilds the flagship's broadsides to the counts the sliders hold, splitting
# each type as evenly as it will go. Asymmetric refits want a port to do it in.
func _apply_guns() -> void:
	if _gun_sliders.is_empty():
		return
	var port: Array = []
	var starboard: Array = []
	for cannon_id in _gun_sliders:
		var total := int(_gun_sliders[cannon_id].value)
		for index in range(total):
			if index % 2 == 0:
				port.append(cannon_id)
			else:
				starboard.append(cannon_id)
	flagship["loadout"]["broadsides"] = {"port": {"cannons": port}, "starboard": {"cannons": starboard}}


func _apply_fate() -> void:
	if _fate in [FATE_RELEASE, FATE_BURN, FATE_SINK]:
		return

	var prize_loadout: Dictionary = report.get("enemy_loadout", {}).duplicate(true)
	# Her hold is whatever you left in it.
	var remaining := {}
	for cargo_id in _prize_manifest:
		var left := int(_prize_manifest[cargo_id])
		if _take_sliders.has(cargo_id):
			left -= int(_take_sliders[cargo_id].value)
		if left > 0:
			remaining[cargo_id] = left
	prize_loadout["cargo"] = remaining
	prize_loadout["cargo_weight"] = 0
	# She flies your colours now. Leaving her Spanish would put an enemy flag in
	# your own line, and every system that reads faction would believe it.
	prize_loadout["faction"] = str(flagship.get("loadout", {}).get("faction", "pirates"))
	# Route and start position belong to the encounter she used to be, not to a
	# ship that now keeps station on you.
	prize_loadout.erase("route")
	prize_loadout.erase("start_x")
	prize_loadout.erase("start_z")

	var prize_crew := FleetScript.minimum_prize_crew(prize_loadout)
	prize_loadout["crew"] = prize_crew
	FleetScript.set_crew(flagship, maxf(0.0, FleetScript.get_crew(flagship) - prize_crew))

	var prize := FleetScript.make_ship(prize_loadout, str(report.get("enemy_name", "Prize")), "prize_%d" % int(session.get("fleet").size()), report.get("enemy", {}))
	session.call("add_prize", prize)
	if _fate == FATE_FLAGSHIP:
		session.call("set_flagship_index", int(session.get("fleet").size()) - 1)


func _make_slider(minimum: int, maximum: int, id: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = float(minimum)
	slider.max_value = float(maxi(minimum, maximum))
	slider.step = 1.0
	slider.allow_greater = false
	slider.allow_lesser = false
	slider.tick_count = mini(maximum - minimum + 1, 11) if maximum - minimum <= 10 else 0
	slider.ticks_on_borders = maximum - minimum <= 10
	slider.custom_minimum_size = Vector2(165.0, 0.0)
	slider.value_changed.connect(_on_control_changed)
	_slider_value_labels[id] = null
	return slider


func _make_slider_field_row(caption: String, slider: HSlider, id: String, caption_width: float) -> HBoxContainer:
	var value_label := MenuStyle.make_label("", 13, HudStyle.PARCHMENT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(62.0, 0.0)
	_slider_value_labels[id] = value_label

	var control := HBoxContainer.new()
	control.add_theme_constant_override("separation", 8)
	control.add_child(slider)
	control.add_child(value_label)
	var row := MenuStyle.make_field_row(caption, control, caption_width)
	_refresh_slider_label(id, slider)
	return row


func _refresh_slider_labels() -> void:
	for cargo_id in _take_sliders:
		_refresh_slider_label("take_%s" % str(cargo_id), _take_sliders[cargo_id])
	for cannon_id in _gun_sliders:
		_refresh_slider_label("gun_%s" % str(cannon_id), _gun_sliders[cannon_id])
	_refresh_slider_label("repair", _repair_slider)
	_refresh_slider_label("recruit", _recruit_slider)


func _refresh_slider_label(id: String, slider: HSlider) -> void:
	if slider == null or not _slider_value_labels.has(id) or _slider_value_labels[id] == null:
		return
	var value_label: Label = _slider_value_labels[id]
	value_label.text = "%d / %d" % [int(slider.value), int(slider.max_value)]
