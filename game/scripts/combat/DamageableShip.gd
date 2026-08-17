extends StaticBody3D
class_name DamageableShip

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const MagazineExplosionScene := preload("res://game/scenes/MagazineExplosion.tscn")
const NON_BURNING_DIRECT_MAGAZINE_EXPLOSION_MULTIPLIER := 0.25

@export var max_hull: float = 60.0
@export var max_sail: float = 60.0
@export var max_crew: float = 60.0
@export var max_morale: float = 100.0
@export var ship_type_id: String = "sloop"
@export var sunk_drop: float = 0.55
@export var sunk_roll_degrees: float = 11.0
@export var minimum_cannon_hit_scale: float = 1.12

var hull: float = 60.0
var sail: float = 60.0
var crew: float = 60.0
var morale: float = 100.0
var ship_display_name: String = "Target Ship"
var modification_names: Array[String] = []
var magazine_explosion_multiplier: float = 1.0
var is_sunk: bool = false
var is_burning: bool = false
var burning_severity: String = ""
var burning_time_remaining: float = 0.0
var burning_hull_damage_per_second: float = 0.0
var burning_magazine_explosion_chance_per_second: float = 0.0
var burning_explosion_tick: float = 0.0
var burning_growth_chance_per_second: float = 0.0
var burning_growth_tick: float = 0.0
var fire_levels: Dictionary = {}
var ship_loadout: Dictionary = {}
var ship_stats: Resource
var disabled_cannons := {"port": 0, "starboard": 0}
var disabled_gun_ports := {"port": 0, "starboard": 0}

@onready var ship_visuals: Node = $ShipVisualBuilder


func _ready() -> void:
	fire_levels = ContentCatalog.load_fire_levels()
	ship_loadout = ContentCatalog.load_target_ship_record()
	_apply_ship_type()
	if ship_visuals:
		ship_visuals.apply_visuals(ship_loadout, ship_stats)
	hull = max_hull


func _process(delta: float) -> void:
	if is_sunk or not is_burning:
		return

	burning_time_remaining = maxf(0.0, burning_time_remaining - delta)
	if burning_hull_damage_per_second > 0.0:
		apply_hull_damage(burning_hull_damage_per_second * delta)
	burning_explosion_tick += delta
	burning_growth_tick += delta
	if burning_growth_chance_per_second > 0.0 and burning_growth_tick >= 1.0:
		burning_growth_tick = 0.0
		if randf() <= burning_growth_chance_per_second:
			_apply_burning(_next_fire_severity(burning_severity))
	if burning_magazine_explosion_chance_per_second > 0.0 and burning_explosion_tick >= 1.0:
		burning_explosion_tick = 0.0
		if randf() <= burning_magazine_explosion_chance_per_second * magazine_explosion_multiplier:
			_explode()
	if burning_time_remaining <= 0.0:
		_stop_burning()


func apply_hull_damage(amount: float) -> void:
	if is_sunk:
		return

	hull = maxf(0.0, hull - amount)
	if ship_visuals:
		ship_visuals.set_damage_fraction(get_hull_fraction())
	if amount >= 0.5 or hull <= 0.0:
		print("Target hull: %.1f / %.1f" % [hull, max_hull])
	if hull <= 0.0:
		_sink()


func apply_sail_damage(amount: float) -> void:
	if is_sunk:
		return
	sail = maxf(0.0, sail - amount)
	if ship_visuals and ship_visuals.has_method("set_sail_fraction"):
		ship_visuals.call("set_sail_fraction", get_sail_fraction())


func apply_crew_damage(amount: float) -> void:
	if is_sunk:
		return
	crew = maxf(0.0, crew - amount)


func apply_morale_damage(amount: float) -> void:
	if is_sunk:
		return
	morale = maxf(0.0, morale - amount)


func apply_projectile_hit(amount: float, status_effects: Dictionary, ammo_context: Dictionary, hit_position: Vector3) -> void:
	if is_sunk:
		return
	apply_hull_damage(amount)
	apply_sail_damage(float(ammo_context.get("sail_damage", 0.0)))
	apply_crew_damage(float(ammo_context.get("crew_damage", 0.0)))
	apply_morale_damage(float(ammo_context.get("morale_damage", 0.0)))
	_roll_armament_damage(_side_from_hit_position(hit_position), ammo_context)
	apply_status_effects(status_effects)


func apply_status_effects(status_effects: Dictionary) -> void:
	if is_sunk or status_effects.is_empty():
		return

	if status_effects.has("burning"):
		var burning: Dictionary = status_effects.get("burning")
		var chance := float(burning.get("chance", 1.0))
		if randf() <= chance:
			_apply_burning(str(burning.get("severity", "small")))
	if status_effects.has("magazine_explosion"):
		var explosion: Dictionary = status_effects.get("magazine_explosion")
		var base_chance := float(explosion.get("chance", 0.0))
		if base_chance < 1.0 and not is_burning:
			base_chance *= NON_BURNING_DIRECT_MAGAZINE_EXPLOSION_MULTIPLIER
		var chance := base_chance * magazine_explosion_multiplier
		if randf() <= chance:
			_explode()


func get_hull_fraction() -> float:
	if max_hull <= 0.0:
		return 0.0
	return hull / max_hull


func get_sail_fraction() -> float:
	if max_sail <= 0.0:
		return 0.0
	return sail / max_sail


func get_crew_fraction() -> float:
	if max_crew <= 0.0:
		return 0.0
	return crew / max_crew


func get_morale_fraction() -> float:
	if max_morale <= 0.0:
		return 0.0
	return morale / max_morale


func get_disabled_cannon_count(side: int) -> int:
	return int(disabled_cannons.get(_side_name(side), 0))


func get_disabled_gun_port_count(side: int) -> int:
	return int(disabled_gun_ports.get(_side_name(side), 0))


func _sink() -> void:
	is_sunk = true
	_stop_burning()
	position.y -= sunk_drop
	rotation_degrees.z = sunk_roll_degrees
	if ship_visuals:
		ship_visuals.set_damage_fraction(0.0)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", true)
	print("Target disabled.")


func _apply_burning(severity: String) -> void:
	var next_severity := _escalate_fire_severity(severity)
	var level: Dictionary = fire_levels.get(next_severity, fire_levels.get("small", {}))
	is_burning = true
	burning_severity = next_severity
	burning_time_remaining = maxf(burning_time_remaining, float(level.get("duration", 5.0)))
	burning_hull_damage_per_second = float(level.get("hull_damage_per_second", 1.0))
	burning_growth_chance_per_second = float(level.get("growth_chance_per_second", 0.0))
	burning_magazine_explosion_chance_per_second = float(level.get("magazine_explosion_chance_per_second", 0.0))
	# Fire visuals live in ShipVisualBuilder.set_fire_state (Tier 3).
	if ship_visuals:
		ship_visuals.set_fire_state(true, burning_severity)


func _stop_burning() -> void:
	is_burning = false
	burning_severity = ""
	burning_time_remaining = 0.0
	burning_hull_damage_per_second = 0.0
	burning_growth_chance_per_second = 0.0
	burning_magazine_explosion_chance_per_second = 0.0
	burning_explosion_tick = 0.0
	burning_growth_tick = 0.0
	if ship_visuals:
		ship_visuals.set_fire_state(false, "")


func _apply_ship_type() -> void:
	var stats: Resource = ContentCatalog.load_target_ship_stats()
	ship_stats = stats
	ship_type_id = str(stats.get("ship_type_id"))
	ship_display_name = str(stats.get("display_name"))
	modification_names = stats.get("modification_names")
	max_hull = float(stats.get("max_hull"))
	max_sail = float(stats.get("max_sail"))
	max_crew = float(stats.get("max_crew"))
	max_morale = float(stats.get("max_morale"))
	sail = max_sail
	crew = max_crew
	morale = max_morale
	magazine_explosion_multiplier = float(stats.get("magazine_explosion_multiplier"))
	var visual_scale := float(stats.get("visual_scale"))
	scale = Vector3.ONE * visual_scale
	_apply_cannon_hit_forgiveness(visual_scale)


func _roll_armament_damage(side: int, ammo_context: Dictionary) -> void:
	var side_name := _side_name(side)
	var cannon_chance := float(ammo_context.get("cannon_disable_chance", 0.0))
	var gun_port_chance := float(ammo_context.get("gun_port_disable_chance", 0.0))
	if cannon_chance > 0.0 and randf() <= cannon_chance:
		_disable_cannon(side_name)
	if gun_port_chance > 0.0 and randf() <= gun_port_chance:
		_disable_gun_port(side_name)


func _disable_cannon(side_name: String) -> void:
	var carried := _get_carried_cannon_count(side_name)
	var disabled := int(disabled_cannons.get(side_name, 0))
	if disabled >= carried:
		return
	disabled_cannons[side_name] = disabled + 1
	print("%s %s cannon disabled (%d/%d disabled)." % [ship_display_name, side_name, disabled + 1, carried])


func _disable_gun_port(side_name: String) -> void:
	var ports := int(ship_stats.get("gun_ports_per_side")) if ship_stats else 0
	var disabled := int(disabled_gun_ports.get(side_name, 0))
	if disabled >= ports:
		return
	disabled_gun_ports[side_name] = disabled + 1
	print("%s %s gun port disabled (%d/%d disabled)." % [ship_display_name, side_name, disabled + 1, ports])


func _get_carried_cannon_count(side_name: String) -> int:
	var broadsides: Dictionary = ship_loadout.get("broadsides", {})
	var broadside: Dictionary = broadsides.get(side_name, {})
	return int(broadside.get("cannons", []).size())


func _side_from_hit_position(hit_position: Vector3) -> int:
	var local_hit := to_local(hit_position)
	return -1 if local_hit.x < 0.0 else 1


func _side_name(side: int) -> String:
	return "port" if side < 0 else "starboard"


func _apply_cannon_hit_forgiveness(visual_scale: float) -> void:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	if visual_scale >= minimum_cannon_hit_scale:
		collision.scale = Vector3.ONE
		return
	var forgiveness_scale := minimum_cannon_hit_scale / maxf(visual_scale, 0.01)
	collision.scale = Vector3.ONE * forgiveness_scale


func _escalate_fire_severity(incoming_severity: String) -> String:
	if not is_burning:
		return incoming_severity
	if _fire_severity_rank(incoming_severity) > _fire_severity_rank(burning_severity):
		return incoming_severity
	return _next_fire_severity(burning_severity)


func _next_fire_severity(severity: String) -> String:
	if severity == "small":
		return "medium"
	if severity == "medium":
		return "large"
	return "large"


func _fire_severity_rank(severity: String) -> int:
	if severity == "large":
		return 3
	if severity == "medium":
		return 2
	if severity == "small":
		return 1
	return 0


func _explode() -> void:
	if is_sunk:
		return
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent:
		var explosion := MagazineExplosionScene.instantiate() as Node3D
		if explosion:
			spawn_parent.add_child(explosion)
			explosion.global_position = global_position
	hull = 0.0
	_sink()
