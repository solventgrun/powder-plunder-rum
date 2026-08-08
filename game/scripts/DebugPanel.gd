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
	var combat_text := ""
	if broadside_controller:
		var combat: Dictionary = broadside_controller.call("get_debug_values")
		combat_text = "\nCannon: %s\nAmmo: %s\nPort Reload: %.1fs\nStarboard Reload: %.1fs" % [
			combat.cannon_name,
			combat.ammo_name,
			combat.port_cooldown,
			combat.starboard_cooldown
		]
		if ship.has_method("get_hull_fraction"):
			combat_text += "\nPlayer Hull: %.0f%%" % [ship.call("get_hull_fraction") * 100.0]
		if ship.get("is_burning"):
			combat_text += "\nPlayer: BURNING"
	if target_ship:
		var target_status := "SUNK" if target_ship.get("is_sunk") else "%.0f%%" % [target_ship.call("get_hull_fraction") * 100.0]
		combat_text += "\nTarget Hull: %s" % target_status
		if target_ship.get("is_burning"):
			combat_text += "\nTarget: BURNING"

	debug_label.text = "Speed: %.2f\nHeading: %03.0f deg\nWind: %03.0f deg @ %.1f\nWind Angle: %03.0f deg\nSail Efficiency: %.2f\nSail Trim: %.0f%%%s" % [
		values.speed,
		values.heading,
		values.wind_heading,
		wind_strength,
		values.wind_angle,
		values.sail_efficiency,
		values.sail_trim * 100.0,
		combat_text
	]

	if wind_indicator and wind_system:
		wind_indicator.set("wind_direction_degrees", wind_system.wind_direction_degrees)
