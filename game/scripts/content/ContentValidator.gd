extends RefCounted

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"
const CANNON_FIELDS := ["id", "name", "type", "range", "reload_time", "weight", "projectile_speed"]
const AMMO_FIELDS := ["id", "name", "range_multiplier", "damage", "status_effects"]
const AMMO_DAMAGE_FIELDS := ["hull", "sail", "crew", "morale", "cannon_disable_chance", "gun_port_disable_chance"]
const STATUS_EFFECT_FIELDS := ["severity", "chance", "self_ignition_chance", "duration", "hull_damage_per_second"]
const SHIP_FIELDS := ["broadsides"]
const PLAYER_SHIP_FIELDS := ["ship_type", "faction", "visual_variant", "sail_set", "crew", "cargo_weight", "modifications", "broadsides"]
const TARGET_SHIP_FIELDS := ["ship_type", "faction", "visual_variant", "sail_set", "crew", "cargo_weight", "modifications", "broadsides"]
const BROADSIDES_FIELDS := ["port", "starboard"]
const BROADSIDE_FIELDS := ["cannons"]
const SHIP_TYPE_FIELDS := ["id", "name", "visual_scale", "visual_profile", "sailing", "combat"]
const SHIP_SAILING_FIELDS := ["max_speed", "acceleration", "deceleration", "turn_rate", "minimum_turn_rate", "sail_trim_speed"]
const SHIP_COMBAT_FIELDS := ["max_hull", "max_sail", "max_crew", "max_morale", "magazine_explosion_multiplier", "usable_load_capacity", "gun_ports"]
const SHIP_VISUAL_PROFILE_FIELDS := ["id", "name", "scale", "hull", "masts", "sails", "flags", "visual_states", "model"]
const SHIP_VISUAL_HULL_FIELDS := ["mode", "scene", "length", "width", "height", "bow_length", "stern_height", "deck_color", "sockets"]
const SHIP_VISUAL_STATE_FIELDS := ["light_damage_threshold", "heavy_damage_threshold", "deck_fire_main", "sail_fire_main"]
const FACTION_FIELDS := ["id", "name", "flag", "sail_palette"]
const FLAG_FIELDS := ["id", "name", "pattern", "primary_color", "secondary_color", "accent_color"]
const ENVIRONMENT_CONDITION_FIELDS := ["id", "name", "wind"]
const ENVIRONMENT_WIND_FIELDS := ["direction_degrees", "strength", "reference_strength"]
const SHIP_MODIFICATION_FIELDS := ["id", "name", "modifiers"]
const SHIP_MODIFIERS_FIELDS := ["sailing", "combat"]
const SHIP_MODIFIER_SAILING_FIELDS := ["max_speed_multiplier", "acceleration_multiplier", "deceleration_multiplier", "turn_rate_multiplier", "minimum_turn_rate_multiplier", "sail_trim_speed_multiplier"]
const SHIP_MODIFIER_COMBAT_FIELDS := ["max_hull_multiplier", "magazine_explosion_multiplier"]
const FIRE_LEVEL_FIELDS := ["id", "name", "visual_scale", "hull_damage_per_second", "duration", "growth_chance_per_second", "magazine_explosion_chance_per_second"]


static func validate_all() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	validate_cannon_types(ContentCatalog.load_cannon_type_records(), errors, warnings)
	validate_ammo_types(ContentCatalog.load_ammo_type_records(), errors, warnings)
	var ship_types := ContentCatalog.load_ship_types()
	var ship_modifications := ContentCatalog.load_ship_modifications()
	validate_fire_levels(ContentCatalog.load_fire_level_records(), errors, warnings)
	var visual_profiles := ContentCatalog.load_ship_visual_profiles()
	var factions := ContentCatalog.load_factions()
	var flags := ContentCatalog.load_flags()
	validate_ship_visual_profiles(ContentCatalog.load_ship_visual_profile_records(), errors, warnings)
	validate_flags(ContentCatalog.load_flag_records(), errors, warnings)
	validate_environment_conditions(ContentCatalog.load_environment_condition_records(), errors, warnings)
	validate_factions(ContentCatalog.load_faction_records(), flags, errors, warnings)
	validate_ship_types(ContentCatalog.load_ship_type_records(), visual_profiles, errors, warnings)
	validate_ship_modifications(ContentCatalog.load_ship_modification_records(), errors, warnings)
	validate_player_ship(ContentCatalog.load_player_ship_record(), ContentCatalog.load_cannon_types(), ship_types, ship_modifications, factions, errors, warnings)
	validate_target_ship(ContentCatalog.load_target_ship_record(), ship_types, ship_modifications, factions, errors, warnings)

	return {
		"errors": errors,
		"warnings": warnings
	}


static func validate_cannon_types(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("cannon_types", records, errors)
	_validate_unique_ids("cannon_types", records, errors)

	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("cannon_types", index, record)
		_validate_required_fields(label, record, ["id", "name", "type", "range", "reload_time", "weight"], errors)
		_warn_unknown_fields(label, record, CANNON_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "range", errors)
		_validate_positive_number(label, record, "reload_time", errors)
		_validate_non_negative_number(label, record, "weight", errors)
		if record.has("projectile_speed"):
			_validate_positive_number(label, record, "projectile_speed", errors)


static func validate_ammo_types(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("ammo_types", records, errors)
	_validate_unique_ids("ammo_types", records, errors)

	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("ammo_types", index, record)
		_validate_required_fields(label, record, ["id", "name", "range_multiplier", "damage"], errors)
		_warn_unknown_fields(label, record, AMMO_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "range_multiplier", errors)

		if not record.get("damage") is Dictionary:
			errors.append("%s damage must be a mapping." % label)
			continue

		var damage: Dictionary = record.get("damage")
		_validate_required_fields("%s damage" % label, damage, AMMO_DAMAGE_FIELDS, errors)
		_warn_unknown_fields("%s damage" % label, damage, AMMO_DAMAGE_FIELDS, warnings)
		for field in AMMO_DAMAGE_FIELDS:
			if field.ends_with("_chance"):
				_validate_unit_number("%s damage" % label, damage, field, errors)
			else:
				_validate_non_negative_number("%s damage" % label, damage, field, errors)

		if record.has("status_effects"):
			_validate_status_effects(label, record.get("status_effects"), errors, warnings)


static func validate_ship_types(records: Array[Dictionary], visual_profiles: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("ship_types", records, errors)
	_validate_unique_ids("ship_types", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("ship_types", index, record)
		_validate_required_fields(label, record, ["id", "name", "visual_scale", "sailing", "combat"], errors)
		_warn_unknown_fields(label, record, SHIP_TYPE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "visual_scale", errors)
		if record.has("visual_profile"):
			var visual_profile_id := str(record.get("visual_profile", ""))
			_validate_id("%s visual_profile" % label, visual_profile_id, errors)
			if not visual_profiles.has(visual_profile_id):
				errors.append("%s references unknown visual_profile '%s'." % [label, visual_profile_id])
		_validate_mapping_fields(label, record, "sailing", SHIP_SAILING_FIELDS, errors, warnings)
		_validate_mapping_fields(label, record, "combat", SHIP_COMBAT_FIELDS, errors, warnings)
		var sailing: Dictionary = record.get("sailing", {})
		for field in SHIP_SAILING_FIELDS:
			_validate_positive_number("%s sailing" % label, sailing, field, errors)
		var combat: Dictionary = record.get("combat", {})
		for field in SHIP_COMBAT_FIELDS:
			_validate_positive_number("%s combat" % label, combat, field, errors)
		if combat.has("gun_ports") and int(combat.get("gun_ports")) % 2 != 0:
			errors.append("%s combat gun_ports must be an even number so ports split evenly per side." % label)


static func validate_ship_visual_profiles(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("ship_visual_profiles", records, errors)
	_validate_unique_ids("ship_visual_profiles", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("ship_visual_profiles", index, record)
		_validate_required_fields(label, record, ["id", "name", "scale", "hull", "masts", "sails", "flags"], errors)
		_warn_unknown_fields(label, record, SHIP_VISUAL_PROFILE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "scale", errors)
		_validate_mapping_fields(label, record, "hull", SHIP_VISUAL_HULL_FIELDS, errors, warnings)
		if record.get("hull") is Dictionary:
			var hull: Dictionary = record.get("hull")
			for field in ["length", "width", "height", "bow_length"]:
				_validate_positive_number("%s hull" % label, hull, field, errors)
			_validate_non_negative_number("%s hull" % label, hull, "stern_height", errors)
		if not record.get("masts") is Dictionary:
			errors.append("%s masts must be a mapping." % label)
		if not record.get("sails") is Dictionary:
			errors.append("%s sails must be a mapping." % label)
		if not record.get("flags") is Dictionary:
			errors.append("%s flags must be a mapping." % label)
		_validate_mapping_fields(label, record, "visual_states", SHIP_VISUAL_STATE_FIELDS, errors, warnings)
		if record.get("visual_states") is Dictionary:
			var states: Dictionary = record.get("visual_states")
			_validate_unit_number("%s visual_states" % label, states, "light_damage_threshold", errors)
			_validate_unit_number("%s visual_states" % label, states, "heavy_damage_threshold", errors)


static func validate_flags(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("flags", records, errors)
	_validate_unique_ids("flags", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("flags", index, record)
		_validate_required_fields(label, record, ["id", "name", "pattern", "primary_color", "secondary_color"], errors)
		_warn_unknown_fields(label, record, FLAG_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)


static func validate_environment_conditions(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("environment_conditions", records, errors)
	_validate_unique_ids("environment_conditions", records, errors)
	var has_default := false
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("environment_conditions", index, record)
		_validate_required_fields(label, record, ["id", "name", "wind"], errors)
		_warn_unknown_fields(label, record, ENVIRONMENT_CONDITION_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		if str(record.get("id", "")) == "default_battle":
			has_default = true
		_validate_mapping_fields(label, record, "wind", ENVIRONMENT_WIND_FIELDS, errors, warnings)
		if record.get("wind") is Dictionary:
			var wind: Dictionary = record.get("wind")
			_validate_unit_degrees(label, wind, "direction_degrees", errors)
			_validate_non_negative_number("%s wind" % label, wind, "strength", errors)
			_validate_positive_number("%s wind" % label, wind, "reference_strength", errors)
	if not has_default:
		errors.append("environment_conditions must include a default_battle record.")


static func validate_factions(records: Array[Dictionary], flags: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("factions", records, errors)
	_validate_unique_ids("factions", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("factions", index, record)
		_validate_required_fields(label, record, ["id", "name", "flag", "sail_palette"], errors)
		_warn_unknown_fields(label, record, FACTION_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		var flag_id := str(record.get("flag", ""))
		_validate_id("%s flag" % label, flag_id, errors)
		if not flag_id.is_empty() and not flags.has(flag_id):
			errors.append("%s references unknown flag '%s'." % [label, flag_id])


static func validate_ship_modifications(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("ship_modifications", records, errors)
	_validate_unique_ids("ship_modifications", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("ship_modifications", index, record)
		_validate_required_fields(label, record, ["id", "name", "modifiers"], errors)
		_warn_unknown_fields(label, record, SHIP_MODIFICATION_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_mapping_fields(label, record, "modifiers", SHIP_MODIFIERS_FIELDS, errors, warnings)
		var modifiers: Dictionary = record.get("modifiers", {})
		if modifiers.has("sailing"):
			_validate_mapping_fields("%s modifiers" % label, modifiers, "sailing", SHIP_MODIFIER_SAILING_FIELDS, errors, warnings)
			var sailing: Dictionary = modifiers.get("sailing", {})
			for field in SHIP_MODIFIER_SAILING_FIELDS:
				_validate_positive_number("%s modifiers.sailing" % label, sailing, field, errors)
		if modifiers.has("combat"):
			_validate_mapping_fields("%s modifiers" % label, modifiers, "combat", SHIP_MODIFIER_COMBAT_FIELDS, errors, warnings)
			var combat: Dictionary = modifiers.get("combat", {})
			for field in SHIP_MODIFIER_COMBAT_FIELDS:
				_validate_positive_number("%s modifiers.combat" % label, combat, field, errors)


static func validate_fire_levels(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("fire_levels", records, errors)
	_validate_unique_ids("fire_levels", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("fire_levels", index, record)
		_validate_required_fields(label, record, FIRE_LEVEL_FIELDS, errors)
		_warn_unknown_fields(label, record, FIRE_LEVEL_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "visual_scale", errors)
		_validate_non_negative_number(label, record, "hull_damage_per_second", errors)
		_validate_positive_number(label, record, "duration", errors)
		_validate_unit_number(label, record, "growth_chance_per_second", errors)
		_validate_unit_number(label, record, "magazine_explosion_chance_per_second", errors)


static func validate_player_ship(record: Dictionary, cannon_types: Dictionary, ship_types: Dictionary, ship_modifications: Dictionary, factions: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	if record.is_empty():
		errors.append("player_ship must contain a loadout record.")
		return

	_warn_unknown_fields("player_ship", record, PLAYER_SHIP_FIELDS, warnings)
	_validate_required_fields("player_ship", record, ["ship_type", "broadsides"], errors)
	_validate_non_negative_number("player_ship", record, "crew", errors)
	_validate_non_negative_number("player_ship", record, "cargo_weight", errors)
	var ship_type_id := str(record.get("ship_type", ""))
	_validate_id("player_ship ship_type", ship_type_id, errors)
	if not ship_type_id.is_empty() and not ship_types.has(ship_type_id):
		errors.append("player_ship references unknown ship_type '%s'." % ship_type_id)
	_validate_faction_reference("player_ship", record, factions, errors)
	for modification_id in record.get("modifications", []):
		var id := str(modification_id)
		_validate_id("player_ship modification", id, errors)
		if not ship_modifications.has(id):
			errors.append("player_ship references unknown modification '%s'." % id)

	if not record.get("broadsides") is Dictionary:
		errors.append("player_ship broadsides must be a mapping.")
		return

	var broadsides: Dictionary = record.get("broadsides")
	_warn_unknown_fields("player_ship broadsides", broadsides, BROADSIDES_FIELDS, warnings)
	for side in BROADSIDES_FIELDS:
		if not broadsides.has(side):
			errors.append("player_ship broadsides missing required side '%s'." % side)
			continue
		if not broadsides[side] is Dictionary:
			errors.append("player_ship broadsides.%s must be a mapping." % side)
			continue

		var broadside: Dictionary = broadsides[side]
		var label := "player_ship broadsides.%s" % side
		_warn_unknown_fields(label, broadside, BROADSIDE_FIELDS, warnings)
		_validate_required_fields(label, broadside, ["cannons"], errors)
		if not broadside.get("cannons") is Array:
			errors.append("%s cannons must be a list." % label)
			continue

		var cannons: Array = broadside.get("cannons")
		if cannons.is_empty():
			errors.append("%s cannons must contain at least one cannon id." % label)
		if ship_types.has(ship_type_id):
			var ship_type: Dictionary = ship_types[ship_type_id]
			var combat: Dictionary = ship_type.get("combat", {})
			var gun_ports_per_side := int(floori(int(combat.get("gun_ports", 999)) / 2))
			if cannons.size() > gun_ports_per_side:
				warnings.append("%s carries %d cannons but only %d gun ports can fire on that side." % [label, cannons.size(), gun_ports_per_side])
		for cannon_id in cannons:
			var id := str(cannon_id)
			_validate_id("%s cannon id" % label, id, errors)
			if not cannon_types.has(id):
				errors.append("%s references unknown cannon id '%s'." % [label, id])
	if ship_types.has(ship_type_id):
		var ship_type: Dictionary = ship_types[ship_type_id]
		var combat: Dictionary = ship_type.get("combat", {})
		if record.has("crew") and float(record.get("crew", 0.0)) > float(combat.get("max_crew", 0.0)):
			errors.append("player_ship crew %.1f exceeds %s max_crew %.1f." % [float(record.get("crew")), ship_type_id, float(combat.get("max_crew"))])
		var capacity := float(combat.get("usable_load_capacity", 999999.0))
		var cannon_weight := ContentCatalog.calculate_cannon_weight(record, cannon_types)
		var cargo_weight := float(record.get("cargo_weight", 0.0))
		var total_load := cannon_weight + cargo_weight
		if total_load > capacity:
			errors.append("player_ship total load %.1f exceeds %s usable_load_capacity %.1f." % [total_load, ship_type_id, capacity])


static func validate_target_ship(record: Dictionary, ship_types: Dictionary, ship_modifications: Dictionary, factions: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	if record.is_empty():
		errors.append("target_ship must contain a ship config record.")
		return

	_warn_unknown_fields("target_ship", record, TARGET_SHIP_FIELDS, warnings)
	_validate_required_fields("target_ship", record, ["ship_type"], errors)
	_validate_non_negative_number("target_ship", record, "crew", errors)
	_validate_non_negative_number("target_ship", record, "cargo_weight", errors)
	_validate_ship_type_and_modifications("target_ship", record, ship_types, ship_modifications, errors)
	_validate_faction_reference("target_ship", record, factions, errors)
	_validate_optional_ship_broadsides("target_ship", record, ContentCatalog.load_cannon_types(), ship_types, errors, warnings)
	var ship_type_id := str(record.get("ship_type", ""))
	if ship_types.has(ship_type_id):
		var ship_type: Dictionary = ship_types[ship_type_id]
		var combat: Dictionary = ship_type.get("combat", {})
		if record.has("crew") and float(record.get("crew", 0.0)) > float(combat.get("max_crew", 0.0)):
			errors.append("target_ship crew %.1f exceeds %s max_crew %.1f." % [float(record.get("crew")), ship_type_id, float(combat.get("max_crew"))])
		var capacity := float(combat.get("usable_load_capacity", 999999.0))
		var cargo_weight := float(record.get("cargo_weight", 0.0))
		if cargo_weight > capacity:
			errors.append("target_ship cargo_weight %.1f exceeds %s usable_load_capacity %.1f." % [cargo_weight, ship_type_id, capacity])


static func _validate_optional_ship_broadsides(label_prefix: String, record: Dictionary, cannon_types: Dictionary, ship_types: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	if not record.has("broadsides"):
		return
	if not record.get("broadsides") is Dictionary:
		errors.append("%s broadsides must be a mapping." % label_prefix)
		return
	var broadsides: Dictionary = record.get("broadsides")
	_warn_unknown_fields("%s broadsides" % label_prefix, broadsides, BROADSIDES_FIELDS, warnings)
	for side in BROADSIDES_FIELDS:
		if not broadsides.has(side):
			continue
		if not broadsides[side] is Dictionary:
			errors.append("%s broadsides.%s must be a mapping." % [label_prefix, side])
			continue
		var broadside: Dictionary = broadsides[side]
		var label := "%s broadsides.%s" % [label_prefix, side]
		_warn_unknown_fields(label, broadside, BROADSIDE_FIELDS, warnings)
		if not broadside.get("cannons", []) is Array:
			errors.append("%s cannons must be a list." % label)
			continue
		for cannon_id in broadside.get("cannons", []):
			var id := str(cannon_id)
			_validate_id("%s cannon id" % label, id, errors)
			if not cannon_types.has(id):
				errors.append("%s references unknown cannon id '%s'." % [label, id])
		var ship_type_id := str(record.get("ship_type", ""))
		if ship_types.has(ship_type_id):
			var ship_type: Dictionary = ship_types[ship_type_id]
			var combat: Dictionary = ship_type.get("combat", {})
			var gun_ports_per_side := int(floori(int(combat.get("gun_ports", 999)) / 2))
			var cannon_count := int(broadside.get("cannons", []).size())
			if cannon_count > gun_ports_per_side:
				warnings.append("%s carries %d cannons but only %d gun ports can fire on that side." % [label, cannon_count, gun_ports_per_side])


static func _validate_faction_reference(label: String, record: Dictionary, factions: Dictionary, errors: Array[String]) -> void:
	var faction_id := str(record.get("faction", ""))
	_validate_id("%s faction" % label, faction_id, errors)
	if not faction_id.is_empty() and not factions.has(faction_id):
		errors.append("%s references unknown faction '%s'." % [label, faction_id])


static func _validate_ship_type_and_modifications(label: String, record: Dictionary, ship_types: Dictionary, ship_modifications: Dictionary, errors: Array[String]) -> void:
	var ship_type_id := str(record.get("ship_type", ""))
	_validate_id("%s ship_type" % label, ship_type_id, errors)
	if not ship_type_id.is_empty() and not ship_types.has(ship_type_id):
		errors.append("%s references unknown ship_type '%s'." % [label, ship_type_id])

	if not record.get("modifications", []) is Array:
		errors.append("%s modifications must be a list." % label)
		return

	for modification_id in record.get("modifications", []):
		var id := str(modification_id)
		_validate_id("%s modification" % label, id, errors)
		if not ship_modifications.has(id):
			errors.append("%s references unknown modification '%s'." % [label, id])


static func _validate_mapping_fields(label: String, record: Dictionary, field: String, allowed_fields: Array, errors: Array[String], warnings: Array[String]) -> void:
	if not record.has(field):
		return
	if not record[field] is Dictionary:
		errors.append("%s field '%s' must be a mapping." % [label, field])
		return
	var nested: Dictionary = record[field]
	_warn_unknown_fields("%s %s" % [label, field], nested, allowed_fields, warnings)


static func _validate_records_present(root_key: String, records: Array[Dictionary], errors: Array[String]) -> void:
	if records.is_empty():
		errors.append("%s must contain at least one record." % root_key)


static func _validate_status_effects(label: String, value: Variant, errors: Array[String], warnings: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("%s status_effects must be a mapping." % label)
		return

	var status_effects: Dictionary = value
	for effect_id in status_effects.keys():
		var effect_label := "%s status_effects[%s]" % [label, effect_id]
		_validate_id(effect_label, effect_id, errors)
		if not status_effects[effect_id] is Dictionary:
			errors.append("%s must be a mapping." % effect_label)
			continue

		var effect: Dictionary = status_effects[effect_id]
		_warn_unknown_fields(effect_label, effect, STATUS_EFFECT_FIELDS, warnings)
		if effect.has("severity"):
			_validate_id(effect_label, effect.get("severity"), errors)
		if effect.has("chance"):
			_validate_unit_number(effect_label, effect, "chance", errors)
		if effect.has("self_ignition_chance"):
			_validate_unit_number(effect_label, effect, "self_ignition_chance", errors)
		if effect.has("duration"):
			_validate_positive_number(effect_label, effect, "duration", errors)
		if effect.has("hull_damage_per_second"):
			_validate_non_negative_number(effect_label, effect, "hull_damage_per_second", errors)


static func _validate_unique_ids(root_key: String, records: Array[Dictionary], errors: Array[String]) -> void:
	var seen := {}
	for index in range(records.size()):
		var record := records[index]
		var id := str(record.get("id", ""))
		if id.is_empty():
			continue
		if seen.has(id):
			errors.append("%s duplicate id '%s' at records %d and %d." % [root_key, id, seen[id], index])
		else:
			seen[id] = index


static func _validate_required_fields(label: String, record: Dictionary, fields: Array, errors: Array[String]) -> void:
	for field in fields:
		if not record.has(field):
			errors.append("%s missing required field '%s'." % [label, field])


static func _warn_unknown_fields(label: String, record: Dictionary, allowed_fields: Array, warnings: Array[String]) -> void:
	for field in record.keys():
		if not allowed_fields.has(field):
			warnings.append("%s has unknown field '%s'. If intentional, update the validator allowed fields." % [label, field])


static func _validate_id(label: String, id_value: Variant, errors: Array[String]) -> void:
	var id := str(id_value)
	if id.is_empty():
		return
	for character in id:
		if not ID_CHARS.contains(character):
			errors.append("%s id '%s' must use lowercase letters, numbers, and underscores only." % [label, id])
			return


static func _validate_positive_number(label: String, record: Dictionary, field: String, errors: Array[String]) -> void:
	if not record.has(field):
		return
	if not _is_number(record[field]):
		errors.append("%s field '%s' must be numeric." % [label, field])
		return
	if float(record[field]) <= 0.0:
		errors.append("%s field '%s' must be greater than zero." % [label, field])


static func _validate_non_negative_number(label: String, record: Dictionary, field: String, errors: Array[String]) -> void:
	if not record.has(field):
		return
	if not _is_number(record[field]):
		errors.append("%s field '%s' must be numeric." % [label, field])
		return
	if float(record[field]) < 0.0:
		errors.append("%s field '%s' must be zero or greater." % [label, field])


static func _validate_unit_number(label: String, record: Dictionary, field: String, errors: Array[String]) -> void:
	if not record.has(field):
		return
	if not _is_number(record[field]):
		errors.append("%s field '%s' must be numeric." % [label, field])
		return
	var value := float(record[field])
	if value < 0.0 or value > 1.0:
		errors.append("%s field '%s' must be between zero and one." % [label, field])


static func _validate_unit_degrees(label: String, record: Dictionary, field: String, errors: Array[String]) -> void:
	if not record.has(field):
		return
	if not _is_number(record[field]):
		errors.append("%s field '%s' must be numeric." % [label, field])
		return
	var value := float(record[field])
	if value < 0.0 or value >= 360.0:
		errors.append("%s field '%s' must be between 0 and less than 360 degrees." % [label, field])


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _record_label(root_key: String, index: int, record: Dictionary) -> String:
	var id := str(record.get("id", "record_%d" % index))
	return "%s[%s]" % [root_key, id]
