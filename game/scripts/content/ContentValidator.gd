extends RefCounted

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"
const CANNON_FIELDS := ["id", "name", "type", "range", "reload_time", "weight", "projectile_speed"]
const AMMO_FIELDS := ["id", "name", "range_multiplier", "damage", "status_effects"]
const AMMO_DAMAGE_FIELDS := ["hull", "sail", "crew", "morale", "cannon_disable_chance", "gun_port_disable_chance"]
const STATUS_EFFECT_FIELDS := ["severity", "chance", "self_ignition_chance", "duration", "hull_damage_per_second"]
const SHIP_FIELDS := ["broadsides"]
const PLAYER_SHIP_FIELDS := ["ship_type", "faction", "visual_variant", "sail_set", "crew", "cargo_weight", "cargo", "cargo_role", "modifications", "broadsides"]
const TARGET_SHIP_FIELDS := ["ship_type", "faction", "visual_variant", "sail_set", "crew", "cargo_weight", "cargo", "cargo_role", "modifications", "broadsides"]
const CARGO_TYPE_FIELDS := ["id", "name", "role", "weight", "value", "description", "effect"]
const CARGO_ROLES := ["plunder", "powder", "rum"]
const CARGO_EFFECT_KINDS := ["repair", "morale", "provisions", "wounded_recovery", "arms"]
const CARGO_ROLE_FIELDS := ["id", "name", "hold_fraction", "goods"]
const BROADSIDES_FIELDS := ["port", "starboard"]
const BROADSIDE_FIELDS := ["cannons"]
const SHIP_TYPE_FIELDS := ["id", "name", "visual_scale", "visual_profile", "sailing", "combat"]
const SHIP_SAILING_FIELDS := ["max_speed", "acceleration", "deceleration", "turn_rate", "minimum_turn_rate", "sail_trim_speed"]
const SHIP_COMBAT_FIELDS := ["max_hull", "max_sail", "max_crew", "max_morale", "magazine_explosion_multiplier", "usable_load_capacity", "gun_ports"]
const SHIP_VISUAL_PROFILE_FIELDS := ["id", "name", "scale", "hull", "masts", "sails", "flags", "visual_states", "model"]
const SHIP_VISUAL_HULL_FIELDS := ["mode", "scene", "faction_scenes", "length", "width", "height", "bow_length", "stern_height", "deck_color", "sockets"]
const SHIP_VISUAL_STATE_FIELDS := ["light_damage_threshold", "heavy_damage_threshold", "deck_fire_main", "sail_fire_main"]
const FACTION_FIELDS := ["id", "name", "flag", "sail_palette"]
const FACTION_LIVERY_FIELDS := ["id", "paint", "accent", "hull_wood", "trim", "streamer", "sails"]
const FLAG_FIELDS := ["id", "name", "pattern", "primary_color", "secondary_color", "accent_color"]
const ENVIRONMENT_CONDITION_FIELDS := ["id", "name", "wind"]
const ENVIRONMENT_WIND_FIELDS := ["direction_degrees", "strength", "reference_strength"]
const OVERWORLD_SHIP_FIELDS := ["id", "name", "faction", "ship_type", "visual_variant", "sail_set", "crew", "cargo_weight", "cargo", "cargo_role", "start_x", "start_z", "route", "modifications", "broadsides"]
const OVERWORLD_ROUTE_FIELDS := ["x", "z"]
const SHIP_MODIFICATION_FIELDS := ["id", "name", "modifiers"]
const SHIP_MODIFIERS_FIELDS := ["sailing", "combat"]
const SHIP_MODIFIER_SAILING_FIELDS := ["max_speed_multiplier", "acceleration_multiplier", "deceleration_multiplier", "turn_rate_multiplier", "minimum_turn_rate_multiplier", "sail_trim_speed_multiplier"]
const SHIP_MODIFIER_COMBAT_FIELDS := ["max_hull_multiplier", "magazine_explosion_multiplier"]
const FIRE_LEVEL_FIELDS := ["id", "name", "visual_scale", "hull_damage_per_second", "duration", "growth_chance_per_second", "magazine_explosion_chance_per_second"]
const DUEL_WEAPON_FIELDS := ["id", "name", "windup_multiplier", "recovery_multiplier", "damage_multiplier", "summary"]
const DUEL_RULE_FIELDS := ["id", "name", "player_vigor", "timing", "damage", "taunt", "support"]
const DUEL_TIMING_FIELDS := ["opening_delay", "attack_windup", "attack_recovery", "countered_recovery_multiplier", "evade_startup", "evade_active", "evade_recovery", "stagger_duration", "taunt_duration", "taunt_recovery", "pistol_draw", "pistol_recovery", "yield_duration"]
const DUEL_DAMAGE_FIELDS := ["chop", "thrust", "slash", "pistol", "interrupt_multiplier", "riposte_multiplier", "wrong_evade_multiplier"]
const DUEL_TAUNT_FIELDS := ["duration", "windup_penalty", "read_penalty"]
const DUEL_PROFILE_FIELDS := ["id", "name", "vigor", "weapon", "reaction_time", "read_accuracy", "aggression", "feint_chance", "pistol_chance", "pistol_discipline", "coat", "accent", "hat"]
const DUEL_PROFILE_UNIT_FIELDS := ["read_accuracy", "aggression", "feint_chance", "pistol_chance", "pistol_discipline"]
const DUEL_HAT_STYLES := ["none", "tricorn", "bandana"]
const CAPTAIN_ASSIGNMENT_FIELDS := ["id", "faction", "ship_type", "profile"]
# Difficulty levels carry one section per consuming system. `duel` is the only
# section written so far; naval, land, and overworld sections join this list as
# those systems start reading difficulty.
const DIFFICULTY_LEVEL_FIELDS := ["id", "name", "duel", "boarding", "morale", "post_battle"]
const DIFFICULTY_BOARDING_FIELDS := ["enemy_boarding_chance", "enemy_crew_advantage", "defender_strength_multiplier"]
const DIFFICULTY_MORALE_FIELDS := ["gunnery_floor", "surrender_threshold", "desertion_per_battle", "drunk_gunnery_penalty", "sober_up_per_battle"]
const DIFFICULTY_POST_BATTLE_FIELDS := ["salvage_fraction"]
const DIFFICULTY_DUEL_FIELDS := ["vigor_multiplier", "reaction_time_multiplier", "read_accuracy_multiplier", "aggression_multiplier", "feint_chance_multiplier", "pistol_discipline_multiplier", "attack_pause_slow", "attack_pause_fast", "punish_chance", "punish_delay"]
const DIFFICULTY_DUEL_MULTIPLIER_FIELDS := ["vigor_multiplier", "reaction_time_multiplier", "read_accuracy_multiplier", "aggression_multiplier", "feint_chance_multiplier", "pistol_discipline_multiplier"]
const BOARDING_RULE_FIELDS := ["id", "name", "alongside_gap", "max_closing_speed", "grapple_time", "minimum_crew", "player_pistol", "boarding_party_fraction", "defender_strength", "enemy_interest_multiplier", "condition", "opponent_scaling"]
const BOARDING_CONDITION_FIELDS := ["crew_weight", "morale_weight"]
const BOARDING_SCALING_FIELDS := ["vigor_weak_multiplier", "vigor_fresh_multiplier", "reaction_penalty", "read_penalty", "aggression_penalty", "minimum_read_accuracy", "minimum_aggression"]
const DUEL_SUPPORT_FIELDS := ["base_kill_rate", "hit_burst", "surge_gain", "surge_decay", "surge_max"]
const SHIP_COLLISION_FIELDS := ["id", "name", "minimum_impact_speed", "maximum_impact_speed", "hull_damage_per_speed", "crew_damage_per_speed", "sail_damage_per_speed", "mass_influence", "cooldown", "shake", "foam"]


static func validate_all() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	validate_cannon_types(ContentCatalog.load_cannon_type_records(), errors, warnings)
	validate_ammo_types(ContentCatalog.load_ammo_type_records(), errors, warnings)
	var cargo_types := ContentCatalog.load_cargo_types()
	validate_cargo_types(ContentCatalog.load_cargo_type_records(), errors, warnings)
	validate_cargo_roles(ContentCatalog.load_cargo_role_records(), cargo_types, errors, warnings)
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
	validate_faction_liveries(ContentCatalog.load_faction_livery_records(), factions, errors, warnings)
	validate_ship_types(ContentCatalog.load_ship_type_records(), visual_profiles, errors, warnings)
	validate_ship_modifications(ContentCatalog.load_ship_modification_records(), errors, warnings)
	validate_player_ship(ContentCatalog.load_player_ship_record(), ContentCatalog.load_cannon_types(), ship_types, ship_modifications, factions, errors, warnings)
	validate_target_ship(ContentCatalog.load_target_ship_record(), ship_types, ship_modifications, factions, errors, warnings)
	validate_overworld_ships(ContentCatalog.load_overworld_ship_records(), ship_types, ship_modifications, factions, errors, warnings)
	var duel_weapons := ContentCatalog.load_duel_weapons()
	var duel_profiles := ContentCatalog.load_duel_profiles()
	validate_duel_weapons(ContentCatalog.load_duel_weapon_records(), errors, warnings)
	validate_duel_rules(ContentCatalog.load_duel_rule_records(), errors, warnings)
	validate_duel_profiles(ContentCatalog.load_duel_profile_records(), duel_weapons, errors, warnings)
	validate_captain_assignments(ContentCatalog.load_captain_assignment_records(), duel_profiles, ship_types, factions, errors, warnings)
	validate_difficulty_levels(ContentCatalog.load_difficulty_level_records(), errors, warnings)
	validate_boarding_rules(ContentCatalog.load_boarding_rule_records(), errors, warnings)
	validate_ship_collisions(ContentCatalog.load_ship_collision_records(), errors, warnings)

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


static func validate_cargo_types(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("cargo_types", records, errors)
	_validate_unique_ids("cargo_types", records, errors)

	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("cargo_types", index, record)
		_validate_required_fields(label, record, ["id", "name", "role", "weight", "value"], errors)
		_warn_unknown_fields(label, record, CARGO_TYPE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		# A weightless good would be free to carry, which breaks the only
		# decision the hold poses.
		_validate_positive_number(label, record, "weight", errors)
		_validate_non_negative_number(label, record, "value", errors)
		var role := str(record.get("role", ""))
		if not role.is_empty() and not CARGO_ROLES.has(role):
			errors.append("%s role '%s' must be one of %s." % [label, role, str(CARGO_ROLES)])

		if not record.has("effect"):
			continue
		if not record.get("effect") is Dictionary:
			errors.append("%s effect must be a mapping." % label)
			continue
		var effect: Dictionary = record.get("effect")
		var kind := str(effect.get("kind", ""))
		if not CARGO_EFFECT_KINDS.has(kind):
			errors.append("%s effect kind '%s' must be one of %s." % [label, kind, str(CARGO_EFFECT_KINDS)])
			continue
		# Each kind carries its own numbers; an effect missing them would be
		# silently inert, which is worse than a good with no effect at all.
		match kind:
			"repair":
				_validate_required_fields("%s effect" % label, effect, ["hull_per_unit", "sail_per_unit"], errors)
			"morale":
				_validate_required_fields("%s effect" % label, effect, ["morale_per_unit", "drunkenness_per_unit"], errors)
			"provisions":
				pass
			"wounded_recovery":
				_validate_required_fields("%s effect" % label, effect, ["crew_per_unit"], errors)
			"arms":
				_validate_required_fields("%s effect" % label, effect, ["crew_armed_per_unit", "fully_armed_strength_bonus"], errors)


static func validate_cargo_roles(records: Array[Dictionary], cargo_types: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("cargo_roles", records, errors)
	_validate_unique_ids("cargo_roles", records, errors)

	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("cargo_roles", index, record)
		_validate_required_fields(label, record, ["id", "name", "hold_fraction"], errors)
		_warn_unknown_fields(label, record, CARGO_ROLE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_unit_number(label, record, "hold_fraction", errors)
		if not record.has("goods"):
			continue
		if not record.get("goods") is Dictionary:
			errors.append("%s goods must be a mapping of cargo id to share." % label)
			continue
		for cargo_id in record.get("goods", {}):
			var id := str(cargo_id)
			if not cargo_types.has(id):
				errors.append("%s references unknown cargo type '%s'." % [label, id])
			elif float(record["goods"][cargo_id]) <= 0.0:
				errors.append("%s share for '%s' must be positive." % [label, id])


# Checks a ship's hold: that every good is real, every count is a positive whole
# number, and — with `strict_capacity` — that the whole lot plus her guns still
# fits. Overworld ships are only warned, because a manifest rolled from a role
# should not be able to fail the content gate.
static func validate_cargo_manifest(label: String, record: Dictionary, cargo_types: Dictionary, ship_types: Dictionary, errors: Array[String], warnings: Array[String], strict_capacity: bool = true) -> void:
	var role_id := str(record.get("cargo_role", ""))
	if not role_id.is_empty() and not ContentCatalog.load_cargo_roles().has(role_id):
		errors.append("%s references unknown cargo_role '%s'." % [label, role_id])

	if not record.has("cargo"):
		return
	if not record.get("cargo") is Dictionary:
		errors.append("%s cargo must be a mapping of cargo id to units." % label)
		return

	var manifest: Dictionary = record.get("cargo", {})
	for cargo_id in manifest:
		var id := str(cargo_id)
		if not cargo_types.has(id):
			errors.append("%s carries unknown cargo type '%s'." % [label, id])
			continue
		var units: Variant = manifest[cargo_id]
		if not (units is int or units is float) or float(units) < 0.0 or float(units) != floorf(float(units)):
			errors.append("%s cargo '%s' must be a whole number of units." % [label, id])

	if manifest.is_empty():
		return
	if record.has("cargo_weight") and float(record.get("cargo_weight", 0.0)) > 0.0:
		warnings.append("%s has both a cargo manifest and a cargo_weight scalar; the manifest wins and the scalar is ignored." % label)

	var ship_type_id := str(record.get("ship_type", ""))
	if not ship_types.has(ship_type_id):
		return
	var free_hold := ContentCatalog.get_free_hold(record)
	var cargo_weight := ContentCatalog.calculate_cargo_weight(manifest, cargo_types)
	if cargo_weight <= free_hold:
		return
	var message := "%s cargo weighs %.1f but only %.1f of her hold is free once her guns are aboard." % [label, cargo_weight, free_hold]
	if strict_capacity:
		errors.append(message)
	else:
		warnings.append(message)


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


static func validate_faction_liveries(records: Array[Dictionary], factions: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("faction_liveries", records, errors)
	_validate_unique_ids("faction_liveries", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("faction_liveries", index, record)
		_validate_required_fields(label, record, FACTION_LIVERY_FIELDS, errors)
		_warn_unknown_fields(label, record, FACTION_LIVERY_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		var id := str(record.get("id", ""))
		if not id.is_empty() and not factions.has(id):
			errors.append("%s references unknown faction '%s'." % [label, id])
		for field in ["paint", "accent", "hull_wood", "trim", "streamer", "sails"]:
			_validate_hex_color(label, record, field, errors)


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
	validate_ship_loadout("player_ship", record, cannon_types, ship_types, ship_modifications, factions, errors, warnings)


# Checks a fully-armed ship record — the player's, or one the practice-battle
# setup screen just built. `label` names the ship in every message so the same
# rules can speak as "player_ship" to the YAML gate and as "Your ship" to a
# player staring at the loadout they are assembling.
static func validate_ship_loadout(label: String, record: Dictionary, cannon_types: Dictionary, ship_types: Dictionary, ship_modifications: Dictionary, factions: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	if record.is_empty():
		errors.append("%s must contain a loadout record." % label)
		return

	_warn_unknown_fields(label, record, PLAYER_SHIP_FIELDS, warnings)
	_validate_required_fields(label, record, ["ship_type", "broadsides"], errors)
	_validate_non_negative_number(label, record, "crew", errors)
	_validate_non_negative_number(label, record, "cargo_weight", errors)
	var ship_type_id := str(record.get("ship_type", ""))
	_validate_id("%s ship_type" % label, ship_type_id, errors)
	if not ship_type_id.is_empty() and not ship_types.has(ship_type_id):
		errors.append("%s references unknown ship_type '%s'." % [label, ship_type_id])
	_validate_faction_reference(label, record, factions, errors)
	for modification_id in record.get("modifications", []):
		var id := str(modification_id)
		_validate_id("%s modification" % label, id, errors)
		if not ship_modifications.has(id):
			errors.append("%s references unknown modification '%s'." % [label, id])

	if not record.get("broadsides") is Dictionary:
		errors.append("%s broadsides must be a mapping." % label)
		return

	var broadsides: Dictionary = record.get("broadsides")
	_warn_unknown_fields("%s broadsides" % label, broadsides, BROADSIDES_FIELDS, warnings)
	for side in BROADSIDES_FIELDS:
		if not broadsides.has(side):
			errors.append("%s broadsides missing required side '%s'." % [label, side])
			continue
		if not broadsides[side] is Dictionary:
			errors.append("%s broadsides.%s must be a mapping." % [label, side])
			continue

		var broadside: Dictionary = broadsides[side]
		var side_label := "%s broadsides.%s" % [label, side]
		_warn_unknown_fields(side_label, broadside, BROADSIDE_FIELDS, warnings)
		_validate_required_fields(side_label, broadside, ["cannons"], errors)
		if not broadside.get("cannons") is Array:
			errors.append("%s cannons must be a list." % side_label)
			continue

		var cannons: Array = broadside.get("cannons")
		if cannons.is_empty():
			errors.append("%s cannons must contain at least one cannon id." % side_label)
		if ship_types.has(ship_type_id):
			var ship_type: Dictionary = ship_types[ship_type_id]
			var combat: Dictionary = ship_type.get("combat", {})
			var gun_ports_per_side := int(floori(int(combat.get("gun_ports", 999)) / 2))
			if cannons.size() > gun_ports_per_side:
				warnings.append("%s carries %d cannons but only %d gun ports can fire on that side." % [side_label, cannons.size(), gun_ports_per_side])
		for cannon_id in cannons:
			var id := str(cannon_id)
			_validate_id("%s cannon id" % side_label, id, errors)
			if not cannon_types.has(id):
				errors.append("%s references unknown cannon id '%s'." % [side_label, id])
	if ship_types.has(ship_type_id):
		var ship_type: Dictionary = ship_types[ship_type_id]
		var combat: Dictionary = ship_type.get("combat", {})
		if record.has("crew") and float(record.get("crew", 0.0)) > float(combat.get("max_crew", 0.0)):
			errors.append("%s crew %.1f exceeds %s max_crew %.1f." % [label, float(record.get("crew")), ship_type_id, float(combat.get("max_crew"))])
		var capacity := float(combat.get("usable_load_capacity", 999999.0))
		var cannon_weight := ContentCatalog.calculate_cannon_weight(record, cannon_types)
		var cargo_weight := ContentCatalog.resolve_cargo_weight(record, ContentCatalog.load_cargo_types())
		var total_load := cannon_weight + cargo_weight
		if total_load > capacity:
			errors.append("%s total load %.1f exceeds %s usable_load_capacity %.1f." % [label, total_load, ship_type_id, capacity])
	validate_cargo_manifest(label, record, ContentCatalog.load_cargo_types(), ship_types, errors, warnings)


# One-call form for loadouts assembled at runtime rather than read from YAML:
# loads the catalogs itself and hands back the two lists the setup screen shows.
# Errors block the battle; warnings (guns beyond the gun ports, say) do not,
# because the sim stows the surplus rather than breaking.
static func validate_runtime_loadout(label: String, record: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	validate_ship_loadout(label, record, ContentCatalog.load_cannon_types(), ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications(), ContentCatalog.load_factions(), errors, warnings)
	return {"errors": errors, "warnings": warnings}


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
		var cargo_weight := ContentCatalog.resolve_cargo_weight(record, ContentCatalog.load_cargo_types())
		if cargo_weight > capacity:
			errors.append("target_ship cargo_weight %.1f exceeds %s usable_load_capacity %.1f." % [cargo_weight, ship_type_id, capacity])
	validate_cargo_manifest("target_ship", record, ContentCatalog.load_cargo_types(), ship_types, errors, warnings)


static func validate_overworld_ships(records: Array[Dictionary], ship_types: Dictionary, ship_modifications: Dictionary, factions: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("overworld_ships", records, errors)
	_validate_unique_ids("overworld_ships", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("overworld_ships", index, record)
		_warn_unknown_fields(label, record, OVERWORLD_SHIP_FIELDS, warnings)
		_validate_required_fields(label, record, ["id", "name", "faction", "ship_type", "start_x", "start_z", "route", "broadsides"], errors)
		_validate_id(label, record.get("id", ""), errors)
		_validate_non_negative_number(label, record, "crew", errors)
		_validate_non_negative_number(label, record, "cargo_weight", errors)
		_validate_number(label, record, "start_x", errors)
		_validate_number(label, record, "start_z", errors)
		# Warn rather than fail: these manifests may have been rolled from a
		# cargo_role, and a generator overfilling a hold is a tuning problem,
		# not a broken content file.
		validate_cargo_manifest(label, record, ContentCatalog.load_cargo_types(), ship_types, errors, warnings, false)
		_validate_ship_type_and_modifications(label, record, ship_types, ship_modifications, errors)
		_validate_faction_reference(label, record, factions, errors)
		_validate_optional_ship_broadsides(label, record, ContentCatalog.load_cannon_types(), ship_types, errors, warnings)
		if not record.get("route") is Array:
			errors.append("%s route must be a list." % label)
		else:
			var route: Array = record.get("route")
			if route.size() < 2:
				errors.append("%s route must include at least two waypoints for a loop." % label)
			for route_index in range(route.size()):
				var waypoint = route[route_index]
				var waypoint_label := "%s route[%d]" % [label, route_index]
				if not waypoint is Dictionary:
					errors.append("%s must be a mapping." % waypoint_label)
					continue
				_warn_unknown_fields(waypoint_label, waypoint, OVERWORLD_ROUTE_FIELDS, warnings)
				_validate_required_fields(waypoint_label, waypoint, OVERWORLD_ROUTE_FIELDS, errors)
				_validate_number(waypoint_label, waypoint, "x", errors)
				_validate_number(waypoint_label, waypoint, "z", errors)


static func validate_duel_weapons(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("duel_weapons", records, errors)
	_validate_unique_ids("duel_weapons", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("duel_weapons", index, record)
		_validate_required_fields(label, record, DUEL_WEAPON_FIELDS, errors)
		_warn_unknown_fields(label, record, DUEL_WEAPON_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "windup_multiplier", errors)
		_validate_positive_number(label, record, "recovery_multiplier", errors)
		_validate_positive_number(label, record, "damage_multiplier", errors)


static func validate_duel_rules(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("duel_rules", records, errors)
	_validate_unique_ids("duel_rules", records, errors)
	var has_default := false
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("duel_rules", index, record)
		if str(record.get("id", "")) == "default":
			has_default = true
		_validate_required_fields(label, record, DUEL_RULE_FIELDS, errors)
		_warn_unknown_fields(label, record, DUEL_RULE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "player_vigor", errors)
		_validate_mapping_fields(label, record, "timing", DUEL_TIMING_FIELDS, errors, warnings)
		_validate_mapping_fields(label, record, "damage", DUEL_DAMAGE_FIELDS, errors, warnings)
		_validate_mapping_fields(label, record, "taunt", DUEL_TAUNT_FIELDS, errors, warnings)
		_validate_mapping_fields(label, record, "support", DUEL_SUPPORT_FIELDS, errors, warnings)
		if record.get("support") is Dictionary:
			var support: Dictionary = record.get("support")
			_validate_required_fields("%s support" % label, support, DUEL_SUPPORT_FIELDS, errors)
			_validate_positive_number("%s support" % label, support, "base_kill_rate", errors)
			_validate_non_negative_number("%s support" % label, support, "hit_burst", errors)
			# A surge that cannot fade, or one with no ceiling, lets a single
			# good exchange decide a melee that numbers should govern.
			_validate_positive_number("%s support" % label, support, "surge_decay", errors)
			if float(support.get("surge_max", 0.0)) < 1.0:
				errors.append("%s support surge_max must be at least 1.0 (no surge at all)." % label)
		if record.get("timing") is Dictionary:
			var timing: Dictionary = record.get("timing")
			# A tell that cannot be seen is not a tell: the whole duel rests on
			# the wind-up being long enough to read and answer.
			if float(timing.get("attack_windup", 0.0)) < float(timing.get("evade_startup", 0.0)) + 0.15:
				errors.append("%s attack_windup must leave the defender time to answer the tell." % label)
			if float(timing.get("evade_active", 0.0)) <= 0.0:
				errors.append("%s evade_active must be a positive window." % label)
	if not has_default and not records.is_empty():
		errors.append("duel_rules must include a 'default' record.")


static func validate_duel_profiles(records: Array[Dictionary], duel_weapons: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("duel_profiles", records, errors)
	_validate_unique_ids("duel_profiles", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("duel_profiles", index, record)
		_validate_required_fields(label, record, DUEL_PROFILE_FIELDS, errors)
		_warn_unknown_fields(label, record, DUEL_PROFILE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "vigor", errors)
		_validate_positive_number(label, record, "reaction_time", errors)
		for field in DUEL_PROFILE_UNIT_FIELDS:
			_validate_unit_number(label, record, field, errors)
		var weapon_id := str(record.get("weapon", ""))
		if not weapon_id.is_empty() and not duel_weapons.has(weapon_id):
			errors.append("%s references unknown duel weapon '%s'." % [label, weapon_id])
		var hat := str(record.get("hat", ""))
		if not hat.is_empty() and not DUEL_HAT_STYLES.has(hat):
			warnings.append("%s uses unknown hat style '%s'." % [label, hat])
		for field in ["coat", "accent"]:
			_validate_hex_color(label, record, field, errors)


static func validate_captain_assignments(records: Array[Dictionary], duel_profiles: Dictionary, ship_types: Dictionary, factions: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("captain_assignments", records, errors)
	_validate_unique_ids("captain_assignments", records, errors)
	var has_fallback := false
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("captain_assignments", index, record)
		_validate_required_fields(label, record, CAPTAIN_ASSIGNMENT_FIELDS, errors)
		_warn_unknown_fields(label, record, CAPTAIN_ASSIGNMENT_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		var faction := str(record.get("faction", ""))
		var ship_type := str(record.get("ship_type", ""))
		var profile := str(record.get("profile", ""))
		if faction == "any" and ship_type == "any":
			has_fallback = true
		if faction != "any" and not faction.is_empty() and not factions.has(faction):
			errors.append("%s references unknown faction '%s'." % [label, faction])
		if ship_type != "any" and not ship_type.is_empty() and not ship_types.has(ship_type):
			errors.append("%s references unknown ship type '%s'." % [label, ship_type])
		if not profile.is_empty() and not duel_profiles.has(profile):
			errors.append("%s references unknown duel profile '%s'." % [label, profile])
	if not has_fallback and not records.is_empty():
		errors.append("captain_assignments must include an any/any fallback record.")


static func validate_difficulty_levels(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("difficulty_levels", records, errors)
	_validate_unique_ids("difficulty_levels", records, errors)
	var has_normal := false
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("difficulty_levels", index, record)
		if str(record.get("id", "")) == "normal":
			has_normal = true
		_validate_required_fields(label, record, DIFFICULTY_LEVEL_FIELDS, errors)
		_warn_unknown_fields(label, record, DIFFICULTY_LEVEL_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_mapping_fields(label, record, "duel", DIFFICULTY_DUEL_FIELDS, errors, warnings)
		_validate_mapping_fields(label, record, "boarding", DIFFICULTY_BOARDING_FIELDS, errors, warnings)
		if record.get("boarding") is Dictionary:
			var boarding: Dictionary = record.get("boarding")
			var boarding_label := "%s boarding" % label
			_validate_required_fields(boarding_label, boarding, DIFFICULTY_BOARDING_FIELDS, errors)
			_validate_unit_number(boarding_label, boarding, "enemy_boarding_chance", errors)
			_validate_positive_number(boarding_label, boarding, "enemy_crew_advantage", errors)
			_validate_positive_number(boarding_label, boarding, "defender_strength_multiplier", errors)
		_validate_mapping_fields(label, record, "morale", DIFFICULTY_MORALE_FIELDS, errors, warnings)
		if record.get("morale") is Dictionary:
			var morale: Dictionary = record.get("morale")
			var morale_label := "%s morale" % label
			_validate_required_fields(morale_label, morale, DIFFICULTY_MORALE_FIELDS, errors)
			_validate_unit_number(morale_label, morale, "gunnery_floor", errors)
			_validate_non_negative_number(morale_label, morale, "surrender_threshold", errors)
			_validate_unit_number(morale_label, morale, "desertion_per_battle", errors)
			_validate_unit_number(morale_label, morale, "drunk_gunnery_penalty", errors)
			_validate_non_negative_number(morale_label, morale, "sober_up_per_battle", errors)
		_validate_mapping_fields(label, record, "post_battle", DIFFICULTY_POST_BATTLE_FIELDS, errors, warnings)
		if record.get("post_battle") is Dictionary:
			var post_battle: Dictionary = record.get("post_battle")
			var post_battle_label := "%s post_battle" % label
			_validate_required_fields(post_battle_label, post_battle, DIFFICULTY_POST_BATTLE_FIELDS, errors)
			_validate_unit_number(post_battle_label, post_battle, "salvage_fraction", errors)
		if not record.get("duel") is Dictionary:
			continue
		var duel: Dictionary = record.get("duel")
		var duel_label := "%s duel" % label
		_validate_required_fields(duel_label, duel, DIFFICULTY_DUEL_FIELDS, errors)
		for field in DIFFICULTY_DUEL_MULTIPLIER_FIELDS:
			_validate_positive_number(duel_label, duel, field, errors)
		_validate_positive_number(duel_label, duel, "attack_pause_slow", errors)
		_validate_positive_number(duel_label, duel, "attack_pause_fast", errors)
		_validate_unit_number(duel_label, duel, "punish_chance", errors)
		_validate_non_negative_number(duel_label, duel, "punish_delay", errors)
		# An aggressive fighter must not end up pausing longer than a passive
		# one, or aggression would read backwards in play.
		if float(duel.get("attack_pause_fast", 0.0)) > float(duel.get("attack_pause_slow", 0.0)):
			errors.append("%s attack_pause_fast must not exceed attack_pause_slow." % duel_label)
	if not has_normal and not records.is_empty():
		errors.append("difficulty_levels must include a 'normal' record; it is the tuning target.")


static func validate_boarding_rules(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("boarding_rules", records, errors)
	_validate_unique_ids("boarding_rules", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("boarding_rules", index, record)
		_validate_required_fields(label, record, BOARDING_RULE_FIELDS, errors)
		_warn_unknown_fields(label, record, BOARDING_RULE_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		_validate_positive_number(label, record, "alongside_gap", errors)
		_validate_positive_number(label, record, "max_closing_speed", errors)
		_validate_non_negative_number(label, record, "grapple_time", errors)
		_validate_non_negative_number(label, record, "minimum_crew", errors)
		_validate_unit_number(label, record, "boarding_party_fraction", errors)
		_validate_positive_number(label, record, "defender_strength", errors)
		_validate_mapping_fields(label, record, "condition", BOARDING_CONDITION_FIELDS, errors, warnings)
		_validate_mapping_fields(label, record, "opponent_scaling", BOARDING_SCALING_FIELDS, errors, warnings)
		if record.get("opponent_scaling") is Dictionary:
			var scaling: Dictionary = record.get("opponent_scaling")
			# Softening the enemy must never make their captain stronger.
			if float(scaling.get("vigor_weak_multiplier", 0.0)) >= float(scaling.get("vigor_fresh_multiplier", 0.0)):
				errors.append("%s vigor_weak_multiplier must be below vigor_fresh_multiplier." % label)


static func validate_ship_collisions(records: Array[Dictionary], errors: Array[String], warnings: Array[String]) -> void:
	_validate_records_present("ship_collision_rules", records, errors)
	_validate_unique_ids("ship_collision_rules", records, errors)
	for index in range(records.size()):
		var record := records[index]
		var label := _record_label("ship_collision_rules", index, record)
		_validate_required_fields(label, record, SHIP_COLLISION_FIELDS, errors)
		_warn_unknown_fields(label, record, SHIP_COLLISION_FIELDS, warnings)
		_validate_id(label, record.get("id", ""), errors)
		# A threshold of zero would make coming alongside to board damage both
		# ships, which is the one thing this must not do.
		_validate_positive_number(label, record, "minimum_impact_speed", errors)
		_validate_positive_number(label, record, "maximum_impact_speed", errors)
		if float(record.get("maximum_impact_speed", 0.0)) <= float(record.get("minimum_impact_speed", 0.0)):
			errors.append("%s maximum_impact_speed must exceed minimum_impact_speed." % label)
		_validate_non_negative_number(label, record, "hull_damage_per_speed", errors)
		_validate_non_negative_number(label, record, "crew_damage_per_speed", errors)
		_validate_non_negative_number(label, record, "sail_damage_per_speed", errors)
		_validate_non_negative_number(label, record, "mass_influence", errors)
		_validate_positive_number(label, record, "cooldown", errors)


static func _validate_hex_color(label: String, record: Dictionary, field: String, errors: Array[String]) -> void:
	if not record.has(field):
		return
	var value := str(record.get(field))
	if not Color.html_is_valid(value):
		errors.append("%s field '%s' should be a valid hex color, got '%s'." % [label, field, value])


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


static func _validate_number(label: String, record: Dictionary, field: String, errors: Array[String]) -> void:
	if not record.has(field):
		return
	if not _is_number(record[field]):
		errors.append("%s field '%s' must be numeric." % [label, field])


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
