class_name ShipCollisionSystem
extends Node

# Consequences for two hulls meeting. The bodies already stopped each other —
# this is what it costs them.
#
# It lives in the battle scene rather than on either ship so a collision is
# resolved once, from one set of numbers, instead of each ship deciding
# separately how hard it was hit.
#
# Damage scales with closing speed and with the size difference, so ramming a
# sloop with a galleon is a tactic and ramming a galleon with a sloop is a
# mistake. Below the speed threshold nothing happens at all, which is what lets
# a ship come alongside to board without tearing itself open.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const ShipGeometryScript := preload("res://game/scripts/combat/ShipGeometry.gd")
const FoamRingEffectScript := preload("res://game/scripts/combat/FoamRingEffect.gd")
const FollowCameraScript := preload("res://game/scripts/FollowCamera.gd")
const HullSplinterEffectScript := preload("res://game/scripts/combat/HullSplinterEffect.gd")

signal ships_collided(impact_speed: float, damage: Dictionary)

@export var player_ship_path: NodePath
@export var target_ship_path: NodePath
@export var enabled: bool = true

var rules: Dictionary = {}
var player_ship: Node3D
var target_ship: Node3D
var last_impact_speed: float = 0.0

var _cooldown: float = 0.0


func _ready() -> void:
	rules = ContentCatalog.load_ship_collision_rules()
	player_ship = get_node_or_null(player_ship_path) as Node3D
	target_ship = get_node_or_null(target_ship_path) as Node3D


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not enabled or _cooldown > 0.0:
		return
	if player_ship == null or target_ship == null:
		return
	if bool(player_ship.get("is_sunk")) or bool(target_ship.get("is_sunk")):
		return
	if ShipGeometryScript.hull_gap(player_ship, target_ship) > 0.0:
		return

	var impact := ShipGeometryScript.closing_speed(player_ship, target_ship)
	var threshold := float(rules.get("minimum_impact_speed", 1.6))
	if impact <= threshold:
		# Touching, not ramming. This is the boarding approach, and it is free.
		return
	resolve_impact(impact - threshold)


# Split out so the smoke test can drive an impact without staging a crash.
func resolve_impact(raw_excess_speed: float) -> Dictionary:
	_cooldown = float(rules.get("cooldown", 1.1))
	# Capped so a freak closing speed cannot one-shot a hull.
	var excess_speed := minf(raw_excess_speed, float(rules.get("maximum_impact_speed", 6.0)))
	last_impact_speed = excess_speed

	var influence := float(rules.get("mass_influence", 1.0))
	var player_mass := ShipGeometryScript.mass_of(player_ship)
	var target_mass := ShipGeometryScript.mass_of(target_ship)
	# Each ship is hurt in proportion to what hit it, relative to its own bulk.
	var player_share := pow(target_mass / maxf(0.01, player_mass), influence)
	var target_share := pow(player_mass / maxf(0.01, target_mass), influence)

	var damage := {
		"player": _apply_to(player_ship, excess_speed, player_share),
		"target": _apply_to(target_ship, excess_speed, target_share)
	}

	_spawn_feedback(excess_speed)
	print("Hulls collide at %.1f: player -%.1f hull, enemy -%.1f hull." % [
		excess_speed, float(damage["player"]), float(damage["target"])])
	ships_collided.emit(excess_speed, damage)
	return damage


func _spawn_splinters(parent: Node, at: Vector3, normal: Vector3, strength: float) -> void:
	var effect: Node3D = HullSplinterEffectScript.new()
	effect.name = "HullSplinters"
	parent.add_child(effect)
	effect.global_position = at
	effect.call("build", normal, strength)


func _apply_to(ship: Node, excess_speed: float, share: float) -> float:
	if ship == null:
		return 0.0
	var hull := excess_speed * float(rules.get("hull_damage_per_speed", 9.0)) * share
	ship.call("apply_hull_damage", hull)
	ship.call("apply_crew_damage", excess_speed * float(rules.get("crew_damage_per_speed", 1.4)) * share)
	ship.call("apply_sail_damage", excess_speed * float(rules.get("sail_damage_per_speed", 2.0)) * share)
	return hull


func _spawn_feedback(excess_speed: float) -> void:
	var strength := clampf(excess_speed / 5.0, 0.25, 1.4)
	# The contact point, not the midpoint between two hulls that may be very
	# different sizes: splinters should fly from where the timber actually met.
	var between := target_ship.global_position - player_ship.global_position
	var direction := between.normalized() if between.length_squared() > 0.001 else Vector3.RIGHT
	var contact := player_ship.global_position + direction * ShipGeometryScript.hull_radius(player_ship, direction)
	contact.y = maxf(contact.y, player_ship.global_position.y) + 0.6

	FollowCameraScript.add_trauma_at(self, contact, float(rules.get("shake", 1.0)) * strength)

	var spawn_parent := player_ship.get_parent()
	if spawn_parent == null:
		return
	# Timber bursts from the seam in both directions.
	_spawn_splinters(spawn_parent, contact, -direction, strength)
	_spawn_splinters(spawn_parent, contact, direction, strength * 0.8)
	var foam := float(rules.get("foam", 1.0)) * strength
	FoamRingEffectScript.spawn(spawn_parent, Vector3(contact.x, player_ship.global_position.y, contact.z), 0.6, 4.5 * foam, 1.3, 0.0, 0.6)
