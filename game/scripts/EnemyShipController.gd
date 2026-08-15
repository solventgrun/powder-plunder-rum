extends CharacterBody3D
class_name EnemyShipController

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var wind_system_path: NodePath
@export var player_ship_path: NodePath
@export var ai_enabled: bool = true
@export var movement_enabled: bool = true
@export var firing_enabled: bool = true
@export_range(0.15, 1.0, 0.01) var sail_trim: float = 0.85
@export_range(0.0, 1.0, 0.01) var aim_tolerance: float = 0.55
@export_range(8.0, 90.0, 1.0) var preferred_range: float = 40.0
@export_range(2.0, 40.0, 1.0) var minimum_range: float = 14.0
@export_range(0.0, 20.0, 0.5, "degrees") var steering_wobble_degrees: float = 5.0
@export_range(0.0, 12.0, 0.25) var initial_firing_delay: float = 3.0
@export_range(0.0, 4.0, 0.1) var aim_commit_time: float = 0.45
@export var ship_type_id: String = "brig"
@export var minimum_cannon_hit_scale: float = 1.12

@onready var sailing_model: Node = $SailingModel
@onready var ship_visuals: Node = $VisualRoot/ShipVisualBuilder
@onready var combat: Node = $ShipCombatComponent
@onready var broadside_controller: Node = $BroadsideController

var wind_system: Node
var player_ship: Node3D
var ship_stats: Resource
var ship_loadout: Dictionary = {}
var ship_display_name: String = "Enemy Ship"
var modification_names: Array[String] = []
var steering_input: float = 0.0
var battle_time: float = 0.0
var aim_commit_timer: float = 0.0


func _ready() -> void:
	ship_loadout = _load_encounter_ship_record()
	_apply_ship_stats(ContentCatalog.build_ship_stats(ship_loadout, ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications()))
	if ship_visuals:
		ship_visuals.apply_visuals(ship_loadout, ship_stats)
	if combat:
		combat.sunk_drop = 0.55
		combat.sunk_roll_degrees = 11.0
		combat.configure(ship_stats, ship_loadout, ship_visuals, ship_display_name)
	if broadside_controller:
		broadside_controller.set("ship_config", "target")
		broadside_controller.set("process_player_input", false)
		broadside_controller.set("ship_loadout", ship_loadout)
		broadside_controller.set("ship_stats", ship_stats)
		broadside_controller.set("selected_ammo_id", "round")
	if not wind_system_path.is_empty():
		wind_system = get_node_or_null(wind_system_path)
	if not player_ship_path.is_empty():
		player_ship = get_node_or_null(player_ship_path) as Node3D


func _physics_process(delta: float) -> void:
	if combat and combat.is_sunk:
		return
	battle_time += delta

	if ai_enabled and player_ship:
		_update_ai(delta)
	else:
		steering_input = 0.0

	if movement_enabled:
		_sail(delta)


func _process(delta: float) -> void:
	if combat:
		combat.update_status(delta)


func _update_ai(delta: float) -> void:
	if player_ship == null:
		return
	var to_player := player_ship.global_position - global_position
	var distance := to_player.length()
	var local_player := global_transform.basis.inverse() * to_player
	var desired_direction := to_player.normalized()
	if distance < minimum_range:
		desired_direction = -desired_direction
	elif distance <= preferred_range:
		var side := 1.0 if local_player.x >= 0.0 else -1.0
		desired_direction = global_transform.basis.x * side
	var desired_heading := atan2(-desired_direction.x, -desired_direction.z)
	var current_heading := atan2(-global_transform.basis.z.x, -global_transform.basis.z.z)
	var wobble := deg_to_rad(sin(Time.get_ticks_msec() * 0.0017) * steering_wobble_degrees)
	var heading_delta := wrapf(desired_heading + wobble - current_heading, -PI, PI)
	steering_input = clampf(heading_delta / deg_to_rad(45.0), -1.0, 1.0)

	if firing_enabled and distance <= preferred_range * 1.35:
		_try_fire_at_player(local_player, delta)
	else:
		aim_commit_timer = 0.0


func _try_fire_at_player(local_player: Vector3, delta: float) -> void:
	if broadside_controller == null:
		return
	if battle_time < initial_firing_delay:
		aim_commit_timer = 0.0
		return
	var side := 1 if local_player.x >= 0.0 else -1
	var side_direction := (global_transform.basis.x * side).normalized()
	var to_player := (player_ship.global_position - global_position).normalized()
	if side_direction.dot(to_player) < aim_tolerance:
		aim_commit_timer = 0.0
		return
	aim_commit_timer += delta
	if aim_commit_timer < aim_commit_time:
		return
	if side < 0:
		if broadside_controller.call("fire_port"):
			aim_commit_timer = 0.0
	else:
		if broadside_controller.call("fire_starboard"):
			aim_commit_timer = 0.0


func _sail(delta: float) -> void:
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


func _apply_ship_stats(stats: Resource) -> void:
	if stats == null:
		return
	ship_stats = stats
	ship_type_id = stats.get("ship_type_id")
	ship_display_name = str(stats.get("display_name"))
	modification_names = stats.get("modification_names")
	sailing_model.set("max_speed", float(stats.get("max_speed")))
	sailing_model.set("acceleration", float(stats.get("acceleration")))
	sailing_model.set("deceleration", float(stats.get("deceleration")))
	sailing_model.set("turn_rate", float(stats.get("turn_rate")))
	sailing_model.set("minimum_turn_rate", float(stats.get("minimum_turn_rate")))
	scale = Vector3.ONE * float(stats.get("visual_scale"))
	_apply_cannon_hit_forgiveness(float(stats.get("visual_scale")))


func apply_projectile_hit(amount: float, status_effects: Dictionary, ammo_context: Dictionary, hit_position: Vector3) -> void:
	combat.apply_projectile_hit(amount, status_effects, ammo_context, hit_position)


func apply_hull_damage(amount: float) -> void:
	combat.apply_hull_damage(amount)


func apply_sail_damage(amount: float) -> void:
	combat.apply_sail_damage(amount)


func apply_crew_damage(amount: float) -> void:
	combat.apply_crew_damage(amount)


func apply_morale_damage(amount: float) -> void:
	combat.apply_morale_damage(amount)


func apply_status_effects(status_effects: Dictionary) -> void:
	combat.apply_status_effects(status_effects)


func get_hull_fraction() -> float:
	return combat.get_hull_fraction()


func get_sail_fraction() -> float:
	return combat.get_sail_fraction()


func get_crew_fraction() -> float:
	return combat.get_crew_fraction()


func get_morale_fraction() -> float:
	return combat.get_morale_fraction()


func get_disabled_cannon_count(side: int) -> int:
	return combat.get_disabled_cannon_count(side)


func get_disabled_gun_port_count(side: int) -> int:
	return combat.get_disabled_gun_port_count(side)


func get_active_cannon_limit() -> int:
	return combat.get_active_cannon_limit()


func _get(property: StringName) -> Variant:
	if combat and property in ["hull", "sail", "crew", "morale", "max_hull", "max_sail", "max_crew", "max_morale", "is_sunk", "is_burning", "is_mast_broken", "burning_severity", "burning_growth_chance_per_second", "burning_magazine_explosion_chance_per_second", "burning_growth_tick", "magazine_explosion_multiplier", "disabled_cannons", "disabled_gun_ports"]:
		return combat.get(property)
	if property == "minimum_cannon_hit_scale":
		return minimum_cannon_hit_scale
	return null


func _set(property: StringName, value: Variant) -> bool:
	if combat and property in ["hull", "sail", "crew", "morale", "max_hull", "max_sail", "max_crew", "max_morale", "is_sunk", "is_burning", "is_mast_broken", "burning_severity", "burning_growth_chance_per_second", "burning_magazine_explosion_chance_per_second", "burning_growth_tick", "magazine_explosion_multiplier", "disabled_cannons", "disabled_gun_ports"]:
		combat.set(property, value)
		return true
	return false


func _apply_cannon_hit_forgiveness(visual_scale: float) -> void:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	if visual_scale > minimum_cannon_hit_scale + 0.001:
		collision.scale = Vector3.ONE
		return
	var forgiveness_scale := (minimum_cannon_hit_scale + 0.03) / maxf(visual_scale, 0.01)
	collision.scale = Vector3.ONE * forgiveness_scale


func _load_encounter_ship_record() -> Dictionary:
	var session := get_node_or_null("/root/GameSession")
	if session and session.has_method("get_selected_encounter"):
		var encounter: Dictionary = session.call("get_selected_encounter")
		if not encounter.is_empty():
			return encounter
	return ContentCatalog.load_target_ship_record()
