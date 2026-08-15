extends CharacterBody3D
class_name ShipController

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var wind_system_path: NodePath
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.1, 2.0, 0.05) var sail_trim_speed: float = 0.65
@export var ship_type_id: String = "brig"

@onready var sailing_model: Node = $SailingModel
@onready var ship_visuals: Node = $VisualRoot/ShipVisualBuilder
@onready var combat: Node = $ShipCombatComponent
@onready var broadside_controller: Node = $BroadsideController

var wind_system: Node
var steering_input: float = 0.0
var ship_stats: Resource
var ship_loadout: Dictionary = {}


func _ready() -> void:
	ship_loadout = ContentCatalog.load_player_ship_record()
	_apply_ship_stats(ContentCatalog.load_player_ship_stats())
	if ship_visuals:
		ship_visuals.apply_visuals(ship_loadout, ship_stats)
		ship_visuals.update_sail_trim(sail_trim)
	if combat:
		combat.configure(ship_stats, ship_loadout, ship_visuals, "Player ship")
	if broadside_controller:
		broadside_controller.set("ship_config", "player")
		broadside_controller.set("process_player_input", true)
		broadside_controller.set("ship_loadout", ship_loadout)
		broadside_controller.set("ship_stats", ship_stats)
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)


func _physics_process(delta: float) -> void:
	if combat and combat.is_sunk:
		return
	steering_input = Input.get_axis("steer_port", "steer_starboard")
	_update_sail_trim(delta)

	var ship_forward := -global_transform.basis.z
	var wind_direction := Vector3.FORWARD
	var wind_speed_factor := 1.0
	if wind_system:
		wind_direction = wind_system.get_wind_direction()
		if wind_system.has_method("get_wind_speed_factor"):
			wind_speed_factor = float(wind_system.call("get_wind_speed_factor"))

	var turn_degrees: float = sailing_model.calculate_turn_degrees(velocity.length(), steering_input, delta)
	rotate_y(deg_to_rad(turn_degrees))

	ship_forward = -global_transform.basis.z
	var movement_power: float = combat.get_movement_power() if combat else 1.0
	velocity = sailing_model.calculate_velocity(velocity, ship_forward, wind_direction, sail_trim * movement_power, delta, wind_speed_factor)
	if movement_power <= 0.0:
		velocity = velocity.move_toward(Vector3.ZERO, float(ship_stats.get("deceleration")) * delta if ship_stats else 2.0 * delta)
	move_and_slide()


func _process(delta: float) -> void:
	if combat:
		combat.update_status(delta)


func _update_sail_trim(delta: float) -> void:
	var trim_input := Input.get_axis("ease_sails", "trim_sails")
	if not is_zero_approx(trim_input):
		sail_trim = clampf(sail_trim + trim_input * sail_trim_speed * delta, 0.15, 1.0)
		if ship_visuals:
			ship_visuals.update_sail_trim(sail_trim)


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
		"ship_type": ship_stats.get("display_name") if ship_stats else ship_type_id,
		"ship_mods": ", ".join(ship_stats.get("modification_names")) if ship_stats else "",
		"max_hull": combat.max_hull if combat else 0.0,
		"sail_fraction": get_sail_fraction(),
		"crew_fraction": get_crew_fraction(),
		"morale_fraction": get_morale_fraction(),
		"mast_broken": combat.is_mast_broken if combat else false,
		"load_weight": float(ship_stats.get("total_load_weight")) if ship_stats else 0.0,
		"load_capacity": float(ship_stats.get("usable_load_capacity")) if ship_stats else 0.0,
		"load_fraction": float(ship_stats.get("load_fraction")) if ship_stats else 0.0,
		"load_speed_multiplier": float(ship_stats.get("load_speed_multiplier")) if ship_stats else 1.0,
		"load_turn_multiplier": float(ship_stats.get("load_turn_multiplier")) if ship_stats else 1.0
	}


func apply_status_effects(status_effects: Dictionary) -> void:
	combat.apply_status_effects(status_effects)


func apply_hull_damage(amount: float) -> void:
	combat.apply_hull_damage(amount)


func apply_sail_damage(amount: float) -> void:
	combat.apply_sail_damage(amount)


func apply_crew_damage(amount: float) -> void:
	combat.apply_crew_damage(amount)


func apply_morale_damage(amount: float) -> void:
	combat.apply_morale_damage(amount)


func apply_projectile_hit(amount: float, status_effects: Dictionary, ammo_context: Dictionary, hit_position: Vector3) -> void:
	combat.apply_projectile_hit(amount, status_effects, ammo_context, hit_position)


func get_disabled_cannon_count(side: int) -> int:
	return combat.get_disabled_cannon_count(side)


func get_disabled_gun_port_count(side: int) -> int:
	return combat.get_disabled_gun_port_count(side)


func get_active_cannon_limit() -> int:
	return combat.get_active_cannon_limit()


func get_hull_fraction() -> float:
	return combat.get_hull_fraction()


func get_sail_fraction() -> float:
	return combat.get_sail_fraction()


func get_crew_fraction() -> float:
	return combat.get_crew_fraction()


func get_morale_fraction() -> float:
	return combat.get_morale_fraction()


func _apply_ship_stats(stats: Resource) -> void:
	if stats == null:
		return
	ship_stats = stats
	ship_type_id = stats.get("ship_type_id")
	sailing_model.set("max_speed", float(stats.get("max_speed")))
	sailing_model.set("acceleration", float(stats.get("acceleration")))
	sailing_model.set("deceleration", float(stats.get("deceleration")))
	sailing_model.set("turn_rate", float(stats.get("turn_rate")))
	sailing_model.set("minimum_turn_rate", float(stats.get("minimum_turn_rate")))
	sail_trim_speed = float(stats.get("sail_trim_speed"))
	scale = Vector3.ONE * float(stats.get("visual_scale"))


func _get(property: StringName) -> Variant:
	if combat and property in ["hull", "sail", "crew", "morale", "max_hull", "max_sail", "max_crew", "max_morale", "is_sunk", "is_burning", "is_mast_broken", "burning_severity", "burning_growth_chance_per_second", "burning_magazine_explosion_chance_per_second", "burning_growth_tick", "magazine_explosion_multiplier", "disabled_cannons", "disabled_gun_ports"]:
		return combat.get(property)
	return null


func _set(property: StringName, value: Variant) -> bool:
	if combat and property in ["hull", "sail", "crew", "morale", "max_hull", "max_sail", "max_crew", "max_morale", "is_sunk", "is_burning", "is_mast_broken", "burning_severity", "burning_growth_chance_per_second", "burning_magazine_explosion_chance_per_second", "burning_growth_tick", "magazine_explosion_multiplier", "disabled_cannons", "disabled_gun_ports"]:
		combat.set(property, value)
		return true
	return false
