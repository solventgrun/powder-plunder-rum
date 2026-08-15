extends RefCounted

const CANNON_TYPES_PATH := "res://data/cannons/cannon_types.yaml"
const AMMO_TYPES_PATH := "res://data/cannons/ammo_types.yaml"
const STATUS_EFFECTS_PATH := "res://data/combat/status_effects.yaml"
const SHIP_TYPES_PATH := "res://data/ships/ship_types.yaml"
const SHIP_MODIFICATIONS_PATH := "res://data/ships/ship_modifications.yaml"
const SHIP_VISUAL_PROFILES_PATH := "res://data/ships/ship_visual_profiles.yaml"
const PLAYER_SHIP_PATH := "res://data/ships/player_ship.yaml"
const TARGET_SHIP_PATH := "res://data/ships/target_ship.yaml"
const FACTIONS_PATH := "res://data/factions/factions.yaml"
const FLAGS_PATH := "res://data/visuals/flags.yaml"
const ENVIRONMENT_CONDITIONS_PATH := "res://data/environment/environment_conditions.yaml"
const OVERWORLD_SHIPS_PATH := "res://data/encounters/overworld_ships.yaml"
const CANNON_TYPE_SCRIPT := preload("res://game/scripts/content/CannonType.gd")
const AMMO_TYPE_SCRIPT := preload("res://game/scripts/content/AmmoType.gd")
const SHIP_STATS_SCRIPT := preload("res://game/scripts/content/ShipStats.gd")


static func load_cannon_types() -> Dictionary:
	var records := load_cannon_type_records()
	var catalog := {}
	for record in records:
		var cannon: Resource = CANNON_TYPE_SCRIPT.new()
		cannon.set("id", str(record.get("id", "")))
		cannon.set("display_name", str(record.get("name", cannon.get("id"))))
		cannon.set("cannon_type", str(record.get("type", "naval")))
		cannon.set("range", float(record.get("range", 30.0)))
		cannon.set("reload_time", float(record.get("reload_time", 1.5)))
		cannon.set("weight", float(record.get("weight", 0.0)))
		cannon.set("projectile_speed", float(record.get("projectile_speed", 28.0)))
		if not cannon.get("id").is_empty():
			catalog[cannon.get("id")] = cannon
	return catalog


static func load_ammo_types() -> Dictionary:
	var records := load_ammo_type_records()
	var catalog := {}
	for record in records:
		var ammo: Resource = AMMO_TYPE_SCRIPT.new()
		ammo.set("id", str(record.get("id", "")))
		ammo.set("display_name", str(record.get("name", ammo.get("id"))))
		ammo.set("range_multiplier", float(record.get("range_multiplier", 1.0)))
		var damage: Dictionary = record.get("damage", {})
		ammo.set("hull_damage", float(damage.get("hull", 1.0)))
		ammo.set("sail_damage", float(damage.get("sail", 0.0)))
		ammo.set("crew_damage", float(damage.get("crew", 0.0)))
		ammo.set("morale_damage", float(damage.get("morale", 0.0)))
		ammo.set("cannon_disable_chance", float(damage.get("cannon_disable_chance", 0.0)))
		ammo.set("gun_port_disable_chance", float(damage.get("gun_port_disable_chance", 0.0)))
		ammo.set("status_effects", record.get("status_effects", {}))
		if not ammo.get("id").is_empty():
			catalog[ammo.get("id")] = ammo
	return catalog


static func load_player_ship_loadout() -> Dictionary:
	return load_player_ship_record()


static func load_ship_type_records() -> Array[Dictionary]:
	return _load_yaml_records(SHIP_TYPES_PATH, "ship_types")


static func load_ship_modification_records() -> Array[Dictionary]:
	return _load_yaml_records(SHIP_MODIFICATIONS_PATH, "ship_modifications")


static func load_ship_visual_profile_records() -> Array[Dictionary]:
	return _load_yaml_records(SHIP_VISUAL_PROFILES_PATH, "ship_visual_profiles")


static func load_ship_types() -> Dictionary:
	var catalog := {}
	for record in load_ship_type_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_ship_modifications() -> Dictionary:
	var catalog := {}
	for record in load_ship_modification_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_ship_visual_profiles() -> Dictionary:
	var catalog := {}
	for record in load_ship_visual_profile_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_faction_records() -> Array[Dictionary]:
	return _load_yaml_records(FACTIONS_PATH, "factions")


static func load_factions() -> Dictionary:
	var catalog := {}
	for record in load_faction_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_flag_records() -> Array[Dictionary]:
	return _load_yaml_records(FLAGS_PATH, "flags")


static func load_flags() -> Dictionary:
	var catalog := {}
	for record in load_flag_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_environment_condition_records() -> Array[Dictionary]:
	return _load_yaml_records(ENVIRONMENT_CONDITIONS_PATH, "environment_conditions")


static func load_environment_conditions() -> Dictionary:
	var catalog := {}
	for record in load_environment_condition_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_environment_condition(condition_id: String = "default_battle") -> Dictionary:
	var conditions := load_environment_conditions()
	return conditions.get(condition_id, conditions.get("default_battle", {}))


static func load_overworld_ship_records() -> Array[Dictionary]:
	return _load_overworld_ship_records(OVERWORLD_SHIPS_PATH)
	

static func load_fire_levels() -> Dictionary:
	var catalog := {}
	for record in load_fire_level_records():
		var id := str(record.get("id", ""))
		if not id.is_empty():
			catalog[id] = record
	return catalog


static func load_player_ship_stats() -> Resource:
	return build_ship_stats(load_player_ship_record(), load_ship_types(), load_ship_modifications())


static func load_target_ship_stats() -> Resource:
	return build_ship_stats(load_target_ship_record(), load_ship_types(), load_ship_modifications())


static func build_ship_stats(ship_record: Dictionary, ship_types: Dictionary, ship_modifications: Dictionary) -> Resource:
	var ship_type_id := str(ship_record.get("ship_type", "brig"))
	var ship_type: Dictionary = ship_types.get(ship_type_id, ship_types.get("brig", {}))
	var sailing: Dictionary = ship_type.get("sailing", {})
	var combat: Dictionary = ship_type.get("combat", {})
	var stats: Resource = SHIP_STATS_SCRIPT.new()
	stats.set("ship_type_id", ship_type_id)
	stats.set("display_name", str(ship_type.get("name", ship_type_id)))
	stats.set("visual_scale", float(ship_type.get("visual_scale", 1.0)))
	stats.set("visual_profile_id", str(ship_type.get("visual_profile", "%s_basic" % ship_type_id)))
	stats.set("max_speed", float(sailing.get("max_speed", 9.0)))
	stats.set("acceleration", float(sailing.get("acceleration", 3.8)))
	stats.set("deceleration", float(sailing.get("deceleration", 2.6)))
	stats.set("turn_rate", float(sailing.get("turn_rate", 70.0)))
	stats.set("minimum_turn_rate", float(sailing.get("minimum_turn_rate", 18.0)))
	stats.set("sail_trim_speed", float(sailing.get("sail_trim_speed", 0.65)))
	stats.set("max_hull", float(combat.get("max_hull", 80.0)))
	stats.set("max_sail", float(combat.get("max_sail", combat.get("max_hull", 80.0))))
	stats.set("max_crew", float(combat.get("max_crew", 80.0)))
	stats.set("starting_crew", clampf(float(ship_record.get("crew", stats.get("max_crew"))), 0.0, float(stats.get("max_crew"))))
	stats.set("max_morale", float(combat.get("max_morale", 100.0)))
	stats.set("magazine_explosion_multiplier", float(combat.get("magazine_explosion_multiplier", 1.0)))
	stats.set("usable_load_capacity", float(combat.get("usable_load_capacity", 90.0)))
	stats.set("gun_ports", int(combat.get("gun_ports", 14)))
	stats.set("gun_ports_per_side", int(floor(float(combat.get("gun_ports", 14)) / 2.0)))
	stats.set("cargo_weight", float(ship_record.get("cargo_weight", 0.0)))

	var modification_ids: Array[String] = []
	var modification_names: Array[String] = []
	for modification_id in ship_record.get("modifications", []):
		var id := str(modification_id)
		if not ship_modifications.has(id):
			continue
		var modification: Dictionary = ship_modifications[id]
		modification_ids.append(id)
		modification_names.append(str(modification.get("name", id)))
		_apply_ship_modification(stats, modification)

	stats.set("modification_ids", modification_ids)
	stats.set("modification_names", modification_names)
	_apply_load_adjustment(stats, ship_record)
	return stats


static func load_cannon_type_records() -> Array[Dictionary]:
	return _load_yaml_records(CANNON_TYPES_PATH, "cannon_types")


static func load_ammo_type_records() -> Array[Dictionary]:
	return _load_yaml_records(AMMO_TYPES_PATH, "ammo_types")


static func load_player_ship_record() -> Dictionary:
	return _load_player_ship_record(PLAYER_SHIP_PATH)


static func load_target_ship_record() -> Dictionary:
	return _load_ship_config_record(TARGET_SHIP_PATH, "target_ship")


static func load_fire_level_records() -> Array[Dictionary]:
	return _load_yaml_records(STATUS_EFFECTS_PATH, "fire_levels")


static func _apply_ship_modification(stats: Resource, modification: Dictionary) -> void:
	var modifiers: Dictionary = modification.get("modifiers", {})
	var sailing: Dictionary = modifiers.get("sailing", {})
	var combat: Dictionary = modifiers.get("combat", {})

	if sailing.has("max_speed_multiplier"):
		stats.set("max_speed", float(stats.get("max_speed")) * float(sailing.get("max_speed_multiplier")))
	if sailing.has("acceleration_multiplier"):
		stats.set("acceleration", float(stats.get("acceleration")) * float(sailing.get("acceleration_multiplier")))
	if sailing.has("deceleration_multiplier"):
		stats.set("deceleration", float(stats.get("deceleration")) * float(sailing.get("deceleration_multiplier")))
	if sailing.has("turn_rate_multiplier"):
		stats.set("turn_rate", float(stats.get("turn_rate")) * float(sailing.get("turn_rate_multiplier")))
	if sailing.has("minimum_turn_rate_multiplier"):
		stats.set("minimum_turn_rate", float(stats.get("minimum_turn_rate")) * float(sailing.get("minimum_turn_rate_multiplier")))
	if sailing.has("sail_trim_speed_multiplier"):
		stats.set("sail_trim_speed", float(stats.get("sail_trim_speed")) * float(sailing.get("sail_trim_speed_multiplier")))
	if combat.has("max_hull_multiplier"):
		stats.set("max_hull", float(stats.get("max_hull")) * float(combat.get("max_hull_multiplier")))
	if combat.has("magazine_explosion_multiplier"):
		stats.set("magazine_explosion_multiplier", float(stats.get("magazine_explosion_multiplier")) * float(combat.get("magazine_explosion_multiplier")))


static func _apply_load_adjustment(stats: Resource, ship_record: Dictionary) -> void:
	var capacity := float(stats.get("usable_load_capacity"))
	var cannon_weight := calculate_cannon_weight(ship_record, load_cannon_types())
	var cargo_weight := float(ship_record.get("cargo_weight", 0.0))
	var total_weight := cannon_weight + cargo_weight
	var load_fraction := 0.0
	if capacity > 0.0:
		load_fraction = total_weight / capacity

	var speed_multiplier := _calculate_load_speed_multiplier(load_fraction)
	var turn_multiplier := _calculate_load_turn_multiplier(load_fraction)

	stats.set("cargo_weight", cargo_weight)
	stats.set("cannon_weight", cannon_weight)
	stats.set("total_load_weight", total_weight)
	stats.set("load_fraction", load_fraction)
	stats.set("load_speed_multiplier", speed_multiplier)
	stats.set("load_turn_multiplier", turn_multiplier)
	stats.set("max_speed", float(stats.get("max_speed")) * speed_multiplier)
	stats.set("acceleration", float(stats.get("acceleration")) * speed_multiplier)
	stats.set("deceleration", float(stats.get("deceleration")) * turn_multiplier)
	stats.set("turn_rate", float(stats.get("turn_rate")) * turn_multiplier)


static func calculate_cannon_weight(ship_record: Dictionary, cannon_types: Dictionary) -> float:
	var weight := 0.0
	var broadsides: Dictionary = ship_record.get("broadsides", {})
	for side in ["port", "starboard"]:
		var broadside: Dictionary = broadsides.get(side, {})
		for cannon_id in broadside.get("cannons", []):
			if cannon_types.has(str(cannon_id)):
				weight += float(cannon_types[str(cannon_id)].get("weight"))
	return weight


static func _calculate_load_speed_multiplier(load_fraction: float) -> float:
	if load_fraction <= 0.6:
		return 1.05
	if load_fraction <= 0.8:
		return lerpf(1.05, 0.9, inverse_lerp(0.6, 0.8, load_fraction))
	if load_fraction <= 0.9:
		return lerpf(0.9, 0.72, inverse_lerp(0.8, 0.9, load_fraction))
	return 0.62


static func _calculate_load_turn_multiplier(load_fraction: float) -> float:
	if load_fraction <= 0.6:
		return 1.05
	if load_fraction <= 0.8:
		return lerpf(1.05, 0.88, inverse_lerp(0.6, 0.8, load_fraction))
	if load_fraction <= 0.9:
		return lerpf(0.88, 0.68, inverse_lerp(0.8, 0.9, load_fraction))
	return 0.55


static func _load_yaml_records(path: String, root_key: String) -> Array[Dictionary]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open content file: %s" % path)
		return []

	var records: Array[Dictionary] = []
	var in_root := false
	var current: Dictionary = {}
	var nesting_path: Array = []

	while not file.eof_reached():
		var raw_line := file.get_line()
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		if not raw_line.begins_with(" "):
			in_root = line == "%s:" % root_key
			nesting_path = []
			continue

		if not in_root:
			continue

		if line.begins_with("- "):
			if not current.is_empty():
				records.append(current)
			current = {}
			nesting_path = []
			var remainder := line.substr(2).strip_edges()
			if not remainder.is_empty():
				var key := _set_record_value(current, remainder)
				nesting_path = [key] if not key.is_empty() else []
		else:
			var indent := _count_leading_spaces(raw_line)
			var depth := maxi(0, int(indent / 2) - 2)
			nesting_path = nesting_path.slice(0, depth)
			var target := _get_nested_dictionary(current, nesting_path)
			var key := _set_record_value(target, line)
			if not key.is_empty():
				nesting_path.append(key)

	if not current.is_empty():
		records.append(current)

	return records


static func _load_player_ship_record(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open content file: %s" % path)
		return {}

	var root: Dictionary = {
		"ship_type": "",
		"faction": "pirates",
		"visual_variant": "",
		"sail_set": "full",
		"cargo_weight": 0.0,
		"modifications": [],
		"broadsides": {
			"port": {"cannons": []},
			"starboard": {"cannons": []}
		}
	}
	var in_root := false
	var current_side := ""
	var in_cannons := false
	var in_modifications := false

	while not file.eof_reached():
		var raw_line := file.get_line()
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		if not raw_line.begins_with(" "):
			in_root = line == "player_ship:"
			current_side = ""
			in_cannons = false
			in_modifications = false
			continue

		if not in_root:
			continue

		if line == "port:" or line == "starboard:":
			current_side = line.trim_suffix(":")
			in_cannons = false
			in_modifications = false
		elif line.begins_with("ship_type:"):
			root["ship_type"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("faction:"):
			root["faction"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("visual_variant:"):
			root["visual_variant"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("sail_set:"):
			root["sail_set"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("crew:"):
			root["crew"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("cargo_weight:"):
			root["cargo_weight"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line == "modifications:":
			in_modifications = true
			in_cannons = false
			current_side = ""
		elif line == "cannons:" and not current_side.is_empty():
			in_cannons = true
			in_modifications = false
		elif line.begins_with("- ") and in_modifications:
			root.modifications.append(_parse_scalar(line.substr(2).strip_edges()))
		elif line.begins_with("- ") and in_cannons and not current_side.is_empty():
			root.broadsides[current_side].cannons.append(_parse_scalar(line.substr(2).strip_edges()))

	return root


static func _load_ship_config_record(path: String, root_key: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open content file: %s" % path)
		return {}

	var root: Dictionary = {
		"ship_type": "",
		"faction": "spain",
		"visual_variant": "",
		"sail_set": "full",
		"cargo_weight": 0.0,
		"modifications": [],
		"broadsides": {
			"port": {"cannons": []},
			"starboard": {"cannons": []}
		}
	}
	var in_root := false
	var in_modifications := false
	var current_side := ""
	var in_cannons := false

	while not file.eof_reached():
		var raw_line := file.get_line()
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		if not raw_line.begins_with(" "):
			in_root = line == "%s:" % root_key
			in_modifications = false
			current_side = ""
			in_cannons = false
			continue

		if not in_root:
			continue

		if line == "port:" or line == "starboard:":
			current_side = line.trim_suffix(":")
			in_modifications = false
			in_cannons = false
		elif line.begins_with("ship_type:"):
			root["ship_type"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("faction:"):
			root["faction"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("visual_variant:"):
			root["visual_variant"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("sail_set:"):
			root["sail_set"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("crew:"):
			root["crew"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line.begins_with("cargo_weight:"):
			root["cargo_weight"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_modifications = false
			in_cannons = false
		elif line == "modifications:":
			in_modifications = true
			in_cannons = false
			current_side = ""
		elif line == "cannons:" and not current_side.is_empty():
			in_cannons = true
			in_modifications = false
		elif line.begins_with("- ") and in_modifications:
			root.modifications.append(_parse_scalar(line.substr(2).strip_edges()))
		elif line.begins_with("- ") and in_cannons and not current_side.is_empty():
			root.broadsides[current_side].cannons.append(_parse_scalar(line.substr(2).strip_edges()))

	return root


static func _load_overworld_ship_records(path: String) -> Array[Dictionary]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open content file: %s" % path)
		return []

	var records: Array[Dictionary] = []
	var current: Dictionary = {}
	var in_root := false
	var in_route := false
	var current_route_point: Dictionary = {}
	var current_side := ""
	var in_cannons := false

	while not file.eof_reached():
		var raw_line := file.get_line()
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		if not raw_line.begins_with(" "):
			in_root = line == "overworld_ships:"
			continue

		if not in_root:
			continue

		var indent := _count_leading_spaces(raw_line)
		if line.begins_with("- id:"):
			if not current_route_point.is_empty():
				current.route.append(current_route_point)
				current_route_point = {}
			if not current.is_empty():
				records.append(current)
			current = _default_overworld_ship_record()
			current["id"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
			in_route = false
			in_cannons = false
			current_side = ""
		elif current.is_empty():
			continue
		elif indent == 4 and line.begins_with("route:"):
			in_route = true
			in_cannons = false
			current_side = ""
		elif indent == 6 and in_route and line.begins_with("- x:"):
			if not current_route_point.is_empty():
				current.route.append(current_route_point)
			current_route_point = {"x": _parse_scalar(line.substr(line.find(":") + 1).strip_edges())}
		elif indent == 8 and in_route and line.begins_with("z:"):
			current_route_point["z"] = _parse_scalar(line.substr(line.find(":") + 1).strip_edges())
		elif indent == 6 and (line == "port:" or line == "starboard:"):
			if not current_route_point.is_empty():
				current.route.append(current_route_point)
				current_route_point = {}
			in_route = false
			current_side = line.trim_suffix(":")
			in_cannons = false
		elif indent == 8 and line == "cannons:" and not current_side.is_empty():
			in_cannons = true
		elif indent == 10 and line.begins_with("- ") and in_cannons and not current_side.is_empty():
			current.broadsides[current_side].cannons.append(_parse_scalar(line.substr(2).strip_edges()))
		elif indent == 4:
			if not current_route_point.is_empty():
				current.route.append(current_route_point)
				current_route_point = {}
			in_route = false
			in_cannons = false
			current_side = ""
			if line == "broadsides:":
				continue
			var separator := line.find(":")
			if separator > 0:
				var key := line.substr(0, separator).strip_edges()
				current[key] = _parse_scalar(line.substr(separator + 1).strip_edges())

	if not current_route_point.is_empty() and not current.is_empty():
		current.route.append(current_route_point)
	if not current.is_empty():
		records.append(current)

	return records


static func _default_overworld_ship_record() -> Dictionary:
	return {
		"id": "",
		"name": "",
		"faction": "spain",
		"ship_type": "brig",
		"visual_variant": "",
		"sail_set": "full",
		"crew": 0,
		"cargo_weight": 0.0,
		"start_x": 0.0,
		"start_z": 0.0,
		"route": [],
		"modifications": [],
		"broadsides": {
			"port": {"cannons": []},
			"starboard": {"cannons": []}
		}
	}


static func _set_record_value(record: Dictionary, line: String) -> String:
	var separator := line.find(":")
	if separator <= 0:
		return ""

	var key := line.substr(0, separator).strip_edges()
	var value_text := line.substr(separator + 1).strip_edges()
	if value_text.is_empty():
		record[key] = {}
		return key

	record[key] = _parse_scalar(value_text)
	return ""


static func _parse_scalar(value_text: String) -> Variant:
	var unquoted := value_text
	if unquoted.length() >= 2 and unquoted.begins_with("\"") and unquoted.ends_with("\""):
		unquoted = unquoted.substr(1, unquoted.length() - 2)

	if unquoted.is_valid_int():
		return int(unquoted)
	if unquoted.is_valid_float():
		return float(unquoted)
	if unquoted == "true":
		return true
	if unquoted == "false":
		return false
	return unquoted


static func _count_leading_spaces(text: String) -> int:
	var count := 0
	for character in text:
		if character != " ":
			break
		count += 1
	return count


static func _get_nested_dictionary(root: Dictionary, path: Array) -> Dictionary:
	var current: Dictionary = root
	for key in path:
		if not current.has(key) or not current[key] is Dictionary:
			current[key] = {}
		var next: Dictionary = current[key]
		current = next
	return current
