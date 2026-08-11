extends CanvasLayer
class_name DebugPanel

@export var ship_path: NodePath
@export var wind_system_path: NodePath
@export var target_ship_path: NodePath

@onready var debug_label: Label = $DebugLabel
@onready var wind_indicator: Control = $WindIndicator

var ship: Node
var wind_system: Node
var target_ship: Node
var broadside_controller: Node


func _ready() -> void:
	ship = get_node_or_null(ship_path)
	wind_system = get_node_or_null(wind_system_path)
	target_ship = get_node_or_null(target_ship_path)
	if ship:
		broadside_controller = ship.get_node_or_null("BroadsideController")


func _process(_delta: float) -> void:
	if not ship:
		return

	var values: Dictionary = ship.get_debug_values()
	var wind_strength: float = wind_system.wind_strength if wind_system else 0.0
	var wind_factor: float = wind_system.call("get_wind_speed_factor") if wind_system and wind_system.has_method("get_wind_speed_factor") else 1.0
	var combat_text := ""
	if broadside_controller:
		var combat: Dictionary = broadside_controller.call("get_debug_values")
		combat_text = "\nAmmo: %s\nPort: %s\nStarboard: %s\nGun Ports: %d/side\nPort Range: %.0f\nStarboard Range: %.0f\nPort Reload: %.1fs\nStarboard Reload: %.1fs\nCannon Weight: %.0f" % [
			combat.ammo_name,
			combat.port_label,
			combat.starboard_label,
			combat.gun_ports_per_side,
			combat.port_range,
			combat.starboard_range,
			combat.port_cooldown,
			combat.starboard_cooldown,
			combat.total_weight
		]
		combat_text += "\nCrew Cannon Limit: %d" % int(combat.crew_cannon_limit)
		if ship.has_method("get_hull_fraction"):
			combat_text += "\nPlayer Hull: %.0f%%" % [ship.call("get_hull_fraction") * 100.0]
			combat_text += "\nPlayer Sail/Crew/Morale: %.0f%% / %.0f%% / %.0f%%" % [
				ship.call("get_sail_fraction") * 100.0,
				ship.call("get_crew_fraction") * 100.0,
				ship.call("get_morale_fraction") * 100.0
			]
		if ship.get("is_mast_broken"):
			combat_text += "\nPlayer: MAST BROKEN"
		if ship.get("is_burning"):
			combat_text += "\nPlayer: BURNING"
	if target_ship:
		var target_name := str(target_ship.get("ship_display_name"))
		if not target_name.is_empty():
			combat_text += "\nTarget: %s" % target_name
		var target_status := "SUNK" if target_ship.get("is_sunk") else "%.0f%%" % [target_ship.call("get_hull_fraction") * 100.0]
		combat_text += "\nTarget Hull: %s" % target_status
		combat_text += "\nTarget Sail/Crew/Morale: %.0f%% / %.0f%% / %.0f%%" % [
			target_ship.call("get_sail_fraction") * 100.0,
			target_ship.call("get_crew_fraction") * 100.0,
			target_ship.call("get_morale_fraction") * 100.0
		]
		if target_ship.get("is_burning"):
			combat_text += "\nTarget: BURNING (%s)" % str(target_ship.get("burning_severity"))
		if target_ship.get("is_mast_broken"):
			combat_text += "\nTarget: MAST BROKEN"

	var ship_mods := str(values.ship_mods)
	if ship_mods.is_empty():
		ship_mods = "None"
	var load_percent := float(values.load_fraction) * 100.0

	debug_label.text = "Ship: %s\nMods: %s\nLoad: %.0f / %.0f (%.0f%%)\nLoad Move: %.2fx speed, %.2fx turn\nSpeed: %.2f\nHeading: %03.0f deg\nWind: %03.0f deg @ %.1f (%.2fx)\nWind Angle: %03.0f deg\nSail Efficiency: %.2f\nSail Trim: %.0f%%%s" % [
		values.ship_type,
		ship_mods,
		values.load_weight,
		values.load_capacity,
		load_percent,
		values.load_speed_multiplier,
		values.load_turn_multiplier,
		values.speed,
		values.heading,
		values.wind_heading,
		wind_strength,
		wind_factor,
		values.wind_angle,
		values.sail_efficiency,
		values.sail_trim * 100.0,
		combat_text
	]

	if wind_indicator and wind_system:
		wind_indicator.set("wind_direction_degrees", wind_system.wind_direction_degrees)
