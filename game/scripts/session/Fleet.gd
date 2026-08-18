class_name Fleet
extends RefCounted

# The player's ships. Not one ship — the player was never meant to stay with the
# one they started in (user directive 2026-08-17): take a prize, sail her
# instead, keep a consort, work up from a sloop.
#
# A fleet ship is a plain Dictionary in two halves:
#
#   loadout    the same record shape as data/ships/player_ship.yaml — what she
#              IS. Ship type, guns, mods, crew complement, and her hold.
#   condition  what a battle DID to her. Hull and sail as fractions, morale,
#              drunkenness, broken mast, disabled guns. This is what makes
#              damage persist: it is written back when a battle ends and seeded
#              in when the next one starts.
#
# Kept as Dictionaries rather than a Resource so the whole fleet serialises to
# human-readable data when save/load arrives, in the same spirit as the YAML.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")


static func make_ship(loadout: Dictionary, ship_name: String, ship_id: String, condition: Dictionary = {}) -> Dictionary:
	return {
		"id": ship_id,
		"name": ship_name,
		"loadout": loadout.duplicate(true),
		"condition": condition.duplicate(true) if not condition.is_empty() else fresh_condition()
	}


# A ship nobody has shot at yet.
static func fresh_condition() -> Dictionary:
	return {
		"hull_fraction": 1.0,
		"sail_fraction": 1.0,
		"morale": 100.0,
		"drunkenness": 0.0,
		"rum_ration": 1,
		"mast_broken": false,
		"disabled_cannons": {"port": 0, "starboard": 0},
		"disabled_gun_ports": {"port": 0, "starboard": 0}
	}


# Crew lives in the loadout, not the condition: `crew` on a ship record has
# always meant her current complement rather than her capacity
# (docs/testing.md), so battle losses simply write it down.
static func get_crew(ship: Dictionary) -> float:
	return float(ship.get("loadout", {}).get("crew", 0.0))


static func set_crew(ship: Dictionary, crew: float) -> void:
	ship["loadout"]["crew"] = maxf(0.0, crew)


static func get_manifest(ship: Dictionary) -> Dictionary:
	return ship.get("loadout", {}).get("cargo", {})


static func set_manifest(ship: Dictionary, manifest: Dictionary) -> void:
	ship["loadout"]["cargo"] = manifest.duplicate()
	# A manifest and the legacy scalar would double-count; the manifest wins.
	ship["loadout"]["cargo_weight"] = 0


# What is left of her allowance once guns and existing cargo are aboard. This is
# the number the after-action screen meters plunder against.
static func get_free_hold(ship: Dictionary) -> float:
	var loadout: Dictionary = ship.get("loadout", {})
	var cargo_types := ContentCatalog.load_cargo_types()
	return maxf(0.0, ContentCatalog.get_free_hold(loadout) - ContentCatalog.calculate_cargo_weight(get_manifest(ship), cargo_types))


static func get_display_name(ship: Dictionary) -> String:
	var given := str(ship.get("name", ""))
	if not given.is_empty():
		return given
	var ship_types := ContentCatalog.load_ship_types()
	var ship_type: Dictionary = ship_types.get(str(ship.get("loadout", {}).get("ship_type", "")), {})
	return str(ship_type.get("name", "Ship"))


# A one-line state of health, for the fleet list and the after-action header.
static func describe_condition(ship: Dictionary) -> String:
	var condition: Dictionary = ship.get("condition", {})
	var hull := int(round(float(condition.get("hull_fraction", 1.0)) * 100.0))
	var sail := int(round(float(condition.get("sail_fraction", 1.0)) * 100.0))
	var parts := ["hull %d%%" % hull, "sail %d%%" % sail, "%d hands" % int(get_crew(ship))]
	if bool(condition.get("mast_broken", false)):
		parts.append("mast gone")
	return ", ".join(parts)


# A prize needs hands aboard to sail her, and they come out of your own
# complement. This is what stops a fleet being free: every ship you keep is men
# you are not fighting with.
static func minimum_prize_crew(loadout: Dictionary) -> int:
	var ship_types := ContentCatalog.load_ship_types()
	var ship_type: Dictionary = ship_types.get(str(loadout.get("ship_type", "")), {})
	var combat: Dictionary = ship_type.get("combat", {})
	return maxi(4, int(ceilf(float(combat.get("max_crew", 40.0)) * 0.12)))


# Builds the fleet a new game starts with: whatever data/ships/player_ship.yaml
# describes, in fresh condition.
static func starting_fleet() -> Array[Dictionary]:
	var loadout := ContentCatalog.load_player_ship_record()
	return [make_ship(loadout, "", "flagship", {})]
