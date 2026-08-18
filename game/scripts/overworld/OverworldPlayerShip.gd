extends CharacterBody3D
class_name OverworldPlayerShip

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var wind_system_path: NodePath
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.1, 2.0, 0.05) var sail_trim_speed: float = 0.75
@export_range(1.0, 4.0, 0.1) var overworld_visual_scale: float = 2.15

@onready var sailing_model: SailingModel = $SailingModel
@onready var ship_visuals: Node = $VisualRoot/ShipVisualBuilder

var wind_system: Node
var steering_input: float = 0.0
var ship_stats: Resource


func _ready() -> void:
	# Same reason as the NPCs: a boat should stop at the beach, never ride up it.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)
	# The map shows whatever the player is actually sailing: take a prize as your
	# own and the ship on the chart changes with you.
	var session := get_node_or_null("/root/GameSession")
	var ship_record: Dictionary = session.call("get_player_ship_record") if session and session.has_method("get_player_ship_record") else ContentCatalog.load_player_ship_record()
	ship_stats = ContentCatalog.build_ship_stats(ship_record, ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	_apply_ship_stats(ship_stats)
	if ship_visuals:
		ship_visuals.apply_visuals(ship_record, ship_stats)
		ship_visuals.update_sail_trim(sail_trim)


func _physics_process(delta: float) -> void:
	steering_input = Input.get_axis("steer_port", "steer_starboard")
	_update_sail_trim(delta)

	var wind_direction := Vector3.FORWARD
	var wind_speed_factor := 1.0
	if wind_system:
		wind_direction = wind_system.get_wind_direction()
		if wind_system.has_method("get_wind_speed_factor"):
			wind_speed_factor = float(wind_system.call("get_wind_speed_factor"))

	var turn_degrees := sailing_model.calculate_turn_degrees(velocity.length(), steering_input, delta)
	rotate_y(deg_to_rad(turn_degrees))

	var forward := -global_transform.basis.z
	velocity = sailing_model.calculate_velocity(velocity, forward, wind_direction, sail_trim, delta, wind_speed_factor)
	move_and_slide()
	# Same reason as the NPCs: stay on the water plane whatever the physics
	# solver did to get us out of an overlap.
	if not is_zero_approx(global_position.y):
		global_position.y = 0.0
	velocity.y = 0.0


func get_debug_values() -> Dictionary:
	var heading := rad_to_deg(atan2(-global_transform.basis.z.x, -global_transform.basis.z.z))
	var wind_heading := 0.0
	if wind_system:
		var wind: Vector3 = wind_system.get_wind_direction()
		wind_heading = rad_to_deg(atan2(wind.x, wind.z))
	return {
		"speed": velocity.length(),
		"heading": wrapf(heading, 0.0, 360.0),
		"wind_heading": wrapf(wind_heading, 0.0, 360.0),
		"wind_angle": sailing_model.last_wind_angle_degrees,
		"sail_efficiency": sailing_model.last_sail_efficiency,
		"sail_trim": sail_trim,
		"fleet": _fleet_summary()
	}


# Names the fleet and, when a consort is holding you back, says so — otherwise
# the speed penalty is invisible and reads as the ship feeling wrong.
func _fleet_summary() -> String:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return "1 ship"
	var fleet: Array = session.get("fleet")
	if fleet.size() <= 1:
		return "1 ship"
	var flagship_stats := ContentCatalog.build_ship_stats(session.call("get_player_ship_record"), ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	var pace := _fleet_pace(flagship_stats)
	if pace < float(flagship_stats.get("max_speed")) - 0.01:
		return "%d ships (held to %.1f kn by the slowest)" % [fleet.size(), pace]
	return "%d ships" % fleet.size()


func _update_sail_trim(delta: float) -> void:
	var trim_input := Input.get_axis("ease_sails", "trim_sails")
	if not is_zero_approx(trim_input):
		sail_trim = clampf(sail_trim + trim_input * sail_trim_speed * delta, 0.15, 1.0)
		if ship_visuals:
			ship_visuals.update_sail_trim(sail_trim)


func _apply_ship_stats(stats: Resource) -> void:
	if stats == null:
		return
	# A fleet sails at the speed of its slowest ship. This is what a consort
	# actually costs: keeping a fat prize because she can carry the plunder your
	# own hold cannot means sailing at her pace from now on, which is the
	# argument for stripping her and burning her instead.
	var fleet_pace := _fleet_pace(stats)
	sailing_model.max_speed = fleet_pace * 2.4
	sailing_model.acceleration = float(stats.get("acceleration")) * 2.8
	sailing_model.deceleration = float(stats.get("deceleration")) * 2.4
	sailing_model.turn_rate = float(stats.get("turn_rate"))
	sailing_model.minimum_turn_rate = float(stats.get("minimum_turn_rate"))
	sail_trim_speed = float(stats.get("sail_trim_speed"))
	scale = Vector3.ONE * float(stats.get("visual_scale")) * overworld_visual_scale


# The slowest hull in the fleet, flagship included. A ship sailing alone is
# simply her own pace, so this costs nothing until you keep a prize.
func _fleet_pace(flagship_stats: Resource) -> float:
	var pace := float(flagship_stats.get("max_speed"))
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return pace
	var fleet: Array = session.get("fleet")
	var ship_types := ContentCatalog.load_ship_types()
	var modifications := ContentCatalog.load_ship_modifications()
	for ship in fleet:
		var stats := ContentCatalog.build_ship_stats(ship.get("loadout", {}), ship_types, modifications)
		pace = minf(pace, float(stats.get("max_speed")))
	return pace
