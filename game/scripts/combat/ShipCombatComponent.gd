extends Node
class_name ShipCombatComponent

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const GameDifficultyScript := preload("res://game/scripts/content/GameDifficulty.gd")
const MagazineExplosionScene := preload("res://game/scenes/MagazineExplosion.tscn")

const NON_BURNING_DIRECT_MAGAZINE_EXPLOSION_MULTIPLIER := 0.25
const CREW_PER_CANNON := 3.0

signal sunk
signal mast_broken
signal struck_colors

var max_hull: float = 80.0
var max_sail: float = 80.0
var max_crew: float = 80.0
var max_morale: float = 100.0
var hull: float = 80.0
var sail: float = 80.0
var crew: float = 80.0
var morale: float = 100.0
# How far into the rum this crew is, 0-100. Raised by issuing a ration at the
# after-action screen, shed between battles. It buys morale and costs gunnery,
# which is the whole trade — and it is the state a Republic of Rum event will
# one day be watching.
var drunkenness: float = 0.0
var magazine_explosion_multiplier: float = 1.0
var is_sunk: bool = false
var is_burning: bool = false
var is_mast_broken: bool = false
# Set when a boarding action decides the ship: a captured prize, or the player's
# own vessel giving up after the captain is cut down. Distinct from sinking —
# the hull is intact and someone now owns it.
var has_struck_colors: bool = false
var burning_time_remaining: float = 0.0
var burning_hull_damage_per_second: float = 0.0
var burning_magazine_explosion_chance_per_second: float = 0.0
var burning_explosion_tick: float = 0.0
var burning_growth_chance_per_second: float = 0.0
var burning_growth_tick: float = 0.0
var burning_severity: String = ""
var fire_levels: Dictionary = {}
var ship_loadout: Dictionary = {}
var ship_stats: Resource
var disabled_cannons := {"port": 0, "starboard": 0}
var disabled_gun_ports := {"port": 0, "starboard": 0}
var visual_node: Node
var display_name: String = "Ship"
var sunk_drop: float = 1.1
var sunk_roll_degrees: float = 16.0
var sunk_pitch_degrees: float = -4.0
var sink_duration: float = 3.2


func configure(stats: Resource, loadout: Dictionary, visuals: Node, name_override: String = "") -> void:
	fire_levels = ContentCatalog.load_fire_levels()
	ship_stats = stats
	ship_loadout = loadout
	visual_node = visuals
	if stats:
		max_hull = float(stats.get("max_hull"))
		max_sail = float(stats.get("max_sail"))
		max_crew = float(stats.get("max_crew"))
		max_morale = float(stats.get("max_morale"))
		magazine_explosion_multiplier = float(stats.get("magazine_explosion_multiplier"))
		display_name = str(stats.get("display_name"))
	if not name_override.is_empty():
		display_name = name_override
	hull = max_hull
	sail = max_sail
	crew = clampf(float(stats.get("starting_crew")) if stats else max_crew, 0.0, max_crew)
	morale = max_morale
	is_sunk = false
	is_burning = false
	is_mast_broken = false
	has_struck_colors = false
	disabled_cannons = {"port": 0, "starboard": 0}
	disabled_gun_ports = {"port": 0, "starboard": 0}


# Seeds a ship with the state she ended her last battle in. Without this every
# ship sails fresh out of her YAML record, and nothing a battle does to a hull
# survives it — which is the whole of post-battle consequences.
#
# Hull and sail come in as fractions so they survive retuning a ship type's
# maxima or bolting a reinforced hull onto her; crew and morale are counts.
func apply_condition(condition: Dictionary) -> void:
	if condition.is_empty():
		return
	hull = clampf(float(condition.get("hull_fraction", 1.0)), 0.0, 1.0) * max_hull
	sail = clampf(float(condition.get("sail_fraction", 1.0)), 0.0, 1.0) * max_sail
	morale = clampf(float(condition.get("morale", max_morale)), 0.0, max_morale)
	drunkenness = clampf(float(condition.get("drunkenness", 0.0)), 0.0, 100.0)
	is_mast_broken = bool(condition.get("mast_broken", false))
	var disabled: Dictionary = condition.get("disabled_cannons", {})
	disabled_cannons = {"port": int(disabled.get("port", 0)), "starboard": int(disabled.get("starboard", 0))}
	var ports: Dictionary = condition.get("disabled_gun_ports", {})
	disabled_gun_ports = {"port": int(ports.get("port", 0)), "starboard": int(ports.get("starboard", 0))}
	if is_mast_broken and visual_node and visual_node.has_method("set_mast_broken"):
		visual_node.call("set_mast_broken", true)


# The mirror of apply_condition: what this ship is carrying away from the fight.
func export_condition() -> Dictionary:
	return {
		"hull_fraction": hull / maxf(max_hull, 0.01),
		"sail_fraction": sail / maxf(max_sail, 0.01),
		"crew": crew,
		"morale": morale,
		"drunkenness": drunkenness,
		"mast_broken": is_mast_broken,
		"disabled_cannons": disabled_cannons.duplicate(),
		"disabled_gun_ports": disabled_gun_ports.duplicate()
	}


func update_status(delta: float) -> void:
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


func apply_projectile_hit(amount: float, status_effects: Dictionary, ammo_context: Dictionary, hit_position: Vector3) -> void:
	if is_sunk:
		return
	apply_hull_damage(amount)
	apply_sail_damage(float(ammo_context.get("sail_damage", 0.0)))
	apply_crew_damage(float(ammo_context.get("crew_damage", 0.0)))
	apply_morale_damage(float(ammo_context.get("morale_damage", 0.0)))
	_roll_armament_damage(_side_from_hit_position(hit_position), ammo_context)
	apply_status_effects(status_effects)


func apply_hull_damage(amount: float) -> void:
	if is_sunk:
		return
	hull = maxf(0.0, hull - amount)
	if visual_node:
		visual_node.call("set_damage_fraction", get_hull_fraction())
	if amount >= 0.5 or hull <= 0.0:
		print("%s hull: %.1f / %.1f" % [display_name, hull, max_hull])
	if hull <= 0.0:
		_sink()


func apply_sail_damage(amount: float) -> void:
	if is_sunk:
		return
	sail = maxf(0.0, sail - amount)
	if visual_node and visual_node.has_method("set_sail_fraction"):
		visual_node.call("set_sail_fraction", get_sail_fraction())
	if sail <= 0.0 and not is_mast_broken:
		break_mast()


func apply_crew_damage(amount: float) -> void:
	if is_sunk:
		return
	crew = maxf(0.0, crew - amount)


func apply_morale_damage(amount: float) -> void:
	if is_sunk:
		return
	morale = maxf(0.0, morale - amount)
	_check_surrender()


# A crew with nothing left in them stops fighting. This is the surrender that
# Milestone 2 deferred, and it cuts both ways: grape shot can break an enemy
# into striking without ever boarding her, and your own people can give up on
# you. `surrender_threshold: 0` in the difficulty file turns it off.
func _check_surrender() -> void:
	if is_sunk or has_struck_colors:
		return
	var threshold := GameDifficultyScript.value("morale", "surrender_threshold", 8.0)
	if threshold <= 0.0 or morale > threshold:
		return
	print("%s has no fight left and strikes her colours." % display_name)
	strike_colors()


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


# The ship gives up the fight without going down: she is taken. Called by the
# boarding layer once a duel decides who owns this deck.
func strike_colors() -> void:
	if is_sunk or has_struck_colors:
		return
	has_struck_colors = true
	var owner_3d := get_parent() as Node3D
	if owner_3d and owner_3d is CharacterBody3D:
		(owner_3d as CharacterBody3D).velocity = Vector3.ZERO
	print("%s strikes her colours." % display_name)
	struck_colors.emit()


func break_mast() -> void:
	if is_sunk or is_mast_broken:
		return
	is_mast_broken = true
	sail = 0.0
	var owner_3d := get_parent() as Node3D
	if owner_3d:
		if owner_3d is CharacterBody3D:
			(owner_3d as CharacterBody3D).velocity = Vector3.ZERO
		var mast := owner_3d.get_node_or_null("VisualRoot/Mast") as MeshInstance3D
		if mast:
			mast.rotation_degrees.z = 72.0
			mast.position.y = maxf(0.45, mast.position.y * 0.45)
	if visual_node and visual_node.has_method("set_mast_broken"):
		visual_node.call("set_mast_broken", true)
	print("%s mast broken." % display_name)
	mast_broken.emit()


func get_hull_fraction() -> float:
	return hull / max_hull if max_hull > 0.0 else 0.0


func get_sail_fraction() -> float:
	return sail / max_sail if max_sail > 0.0 else 0.0


func get_crew_fraction() -> float:
	return crew / max_crew if max_crew > 0.0 else 0.0


func get_morale_fraction() -> float:
	return morale / max_morale if max_morale > 0.0 else 0.0


func get_movement_power() -> float:
	if is_sunk or is_mast_broken:
		return 0.0
	return clampf(lerpf(0.25, 1.0, get_sail_fraction()), 0.0, 1.0)


func get_active_cannon_limit() -> int:
	if is_sunk:
		return 0
	return int(floor(crew / CREW_PER_CANNON * get_gunnery_multiplier()))


# How well this crew is working the guns, as a fraction of a willing sober one.
# Two things drag on it: a crew with no heart left in them, and a crew that has
# been at the rum. Both scale by difficulty (`morale` section) so the whole
# effect can be turned off for a gentler game.
#
# This is what makes morale worth spending rum on — before this it was a number
# that only the enemy's boarding odds ever read.
func get_gunnery_multiplier() -> float:
	var tuning := GameDifficultyScript.section("morale")
	var floor_rate := float(tuning.get("gunnery_floor", 0.7))
	var morale_scale := lerpf(floor_rate, 1.0, clampf(get_morale_fraction(), 0.0, 1.0))
	var drunk_penalty := float(tuning.get("drunk_gunnery_penalty", 0.2)) * clampf(drunkenness / 100.0, 0.0, 1.0)
	return clampf(morale_scale - drunk_penalty, 0.05, 1.0)


func get_disabled_cannon_count(side: int) -> int:
	return int(disabled_cannons.get(_side_name(side), 0))


func get_disabled_gun_port_count(side: int) -> int:
	return int(disabled_gun_ports.get(_side_name(side), 0))


func _apply_burning(severity: String) -> void:
	var next_severity := _escalate_fire_severity(severity)
	var level: Dictionary = fire_levels.get(next_severity, fire_levels.get("small", {}))
	is_burning = true
	burning_severity = next_severity
	burning_time_remaining = maxf(burning_time_remaining, float(level.get("duration", 5.0)))
	burning_hull_damage_per_second = float(level.get("hull_damage_per_second", 1.0))
	burning_growth_chance_per_second = float(level.get("growth_chance_per_second", 0.0))
	burning_magazine_explosion_chance_per_second = float(level.get("magazine_explosion_chance_per_second", 0.0))
	# Fire visuals live in ShipVisualBuilder.set_fire_state (severity-scaled
	# flames/embers/smoke at the fire sockets, Tier 3); the old emissive
	# sphere spawn is gone.
	if visual_node:
		visual_node.call("set_fire_state", true, burning_severity)


func _stop_burning() -> void:
	is_burning = false
	burning_severity = ""
	burning_time_remaining = 0.0
	burning_hull_damage_per_second = 0.0
	burning_growth_chance_per_second = 0.0
	burning_magazine_explosion_chance_per_second = 0.0
	burning_explosion_tick = 0.0
	burning_growth_tick = 0.0
	if visual_node:
		visual_node.call("set_fire_state", false, "")


func _sink() -> void:
	is_sunk = true
	_stop_burning()
	var owner_3d := get_parent() as Node3D
	if owner_3d:
		if owner_3d is CharacterBody3D:
			(owner_3d as CharacterBody3D).velocity = Vector3.ZERO
		var collision := owner_3d.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision:
			collision.set_deferred("disabled", true)
		# The settle is the payoff moment (Tier 3): the old snap becomes an
		# ease-in drop — water claiming the hull — while the wreck rolls to
		# port and goes down by the head. is_sunk stays immediate; only the
		# body transform animates. NavalBattle.result_delay gives it room.
		var tween := owner_3d.create_tween()
		tween.set_parallel(true)
		tween.tween_property(owner_3d, "position:y", owner_3d.position.y - sunk_drop, sink_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(owner_3d, "rotation_degrees:z", sunk_roll_degrees, sink_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(owner_3d, "rotation_degrees:x", sunk_pitch_degrees, sink_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_spawn_sink_foam(owner_3d)
	if visual_node:
		visual_node.call("set_damage_fraction", 0.0)
	print("%s disabled." % display_name)
	sunk.emit()


# Churned foam pulses spreading from the hull as it settles under.
func _spawn_sink_foam(owner_3d: Node3D) -> void:
	var spawn_parent := _get_effect_spawn_parent()
	if spawn_parent == null:
		return
	var at := owner_3d.global_position
	FoamRingEffect.spawn(spawn_parent, at, 1.2, 6.5, 1.6, 0.0, 0.7)
	FoamRingEffect.spawn(spawn_parent, at, 0.8, 8.5, 2.2, 1.1, 0.42)
	FoamRingEffect.spawn(spawn_parent, at, 0.6, 9.5, 2.6, 2.2, 0.3)


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
	print("%s %s cannon disabled (%d/%d disabled)." % [display_name, side_name, disabled + 1, carried])


func _disable_gun_port(side_name: String) -> void:
	var ports := int(ship_stats.get("gun_ports_per_side")) if ship_stats else 0
	var disabled := int(disabled_gun_ports.get(side_name, 0))
	if disabled >= ports:
		return
	disabled_gun_ports[side_name] = disabled + 1
	print("%s %s gun port disabled (%d/%d disabled)." % [display_name, side_name, disabled + 1, ports])


func _get_carried_cannon_count(side_name: String) -> int:
	var broadsides: Dictionary = ship_loadout.get("broadsides", {})
	var broadside: Dictionary = broadsides.get(side_name, {})
	return int(broadside.get("cannons", []).size())


func _side_from_hit_position(hit_position: Vector3) -> int:
	var owner_3d := get_parent() as Node3D
	if owner_3d == null:
		return 1
	var local_hit := owner_3d.to_local(hit_position)
	return -1 if local_hit.x < 0.0 else 1


func _side_name(side: int) -> String:
	return "port" if side < 0 else "starboard"


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
	var spawn_parent := _get_effect_spawn_parent()
	if spawn_parent:
		var explosion := MagazineExplosionScene.instantiate() as Node3D
		if explosion:
			spawn_parent.add_child(explosion)
			var owner_3d := get_parent() as Node3D
			explosion.global_position = owner_3d.global_position if owner_3d else Vector3.ZERO
	hull = 0.0
	_sink()


func _get_effect_spawn_parent() -> Node:
	# Spawn effects as siblings of the ship, not under current_scene, which
	# can point at a different scene than the ship's (test harness scenes,
	# the battle-end scene-change window).
	var owner_node := get_parent()
	if owner_node and owner_node.get_parent():
		return owner_node.get_parent()
	return owner_node
