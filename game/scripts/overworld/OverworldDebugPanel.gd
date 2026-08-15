extends CanvasLayer
class_name OverworldDebugPanel

@export var player_path: NodePath
@export var wind_system_path: NodePath
@export var overworld_path: NodePath

@onready var label: Label = $DebugLabel

var player: Node
var wind_system: Node
var overworld: Node


func _ready() -> void:
	player = get_node_or_null(player_path)
	wind_system = get_node_or_null(wind_system_path)
	overworld = get_node_or_null(overworld_path)


func _process(_delta: float) -> void:
	if player == null:
		return
	var values: Dictionary = player.call("get_debug_values")
	var wind_strength: float = wind_system.wind_strength if wind_system else 0.0
	var nearest_text := "None"
	if overworld and overworld.has_method("get_nearest_intercept_label"):
		nearest_text = overworld.call("get_nearest_intercept_label")
	label.text = "Overworld: Jamaica\nSpeed: %.2f\nHeading: %03.0f deg\nWind: %03.0f deg @ %.1f\nWind Angle: %03.0f deg\nSail Efficiency: %.2f\nSail Trim: %.0f%%\nNearest: %s" % [
		values.speed,
		values.heading,
		values.wind_heading,
		wind_strength,
		values.wind_angle,
		values.sail_efficiency,
		values.sail_trim * 100.0,
		nearest_text
	]
