extends RefCounted

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"
const CANNON_FIELDS := ["id", "name", "type", "range", "reload_time", "weight", "projectile_speed"]
const AMMO_FIELDS := ["id", "name", "range_multiplier", "damage", "status_effects"]
const AMMO_DAMAGE_FIELDS := ["hull", "sail", "crew", "morale"]
const STATUS_EFFECT_FIELDS := ["chance", "self_ignition_chance", "duration", "hull_damage_per_second"]


static func validate_all() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	validate_cannon_types(ContentCatalog.load_cannon_type_records(), errors, warnings)
	validate_ammo_types(ContentCatalog.load_ammo_type_records(), errors, warnings)

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
			_validate_non_negative_number("%s damage" % label, damage, field, errors)

		if record.has("status_effects"):
			_validate_status_effects(label, record.get("status_effects"), errors, warnings)


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


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _record_label(root_key: String, index: int, record: Dictionary) -> String:
	var id := str(record.get("id", "record_%d" % index))
	return "%s[%s]" % [root_key, id]
