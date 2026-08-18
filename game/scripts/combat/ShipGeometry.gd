class_name ShipGeometry
extends RefCounted

# Where a hull actually ends, shared by everything that cares how close two
# ships are: boarding, and ramming.
#
# The naive version — centre distance against a tuned constant — was wrong in
# both directions: it ignored which way the ships were lying, and the constant
# had drifted to roughly four ship-lengths, so you could be boarded from across
# the battle (playtest 2026-08-17). Measuring the gap between hulls costs a
# couple of dot products and cannot drift.

const DEFAULT_HALF_EXTENTS := Vector3(0.75, 0.33, 1.75)


# Water between the two hulls: zero means touching, negative means overlapping.
static func hull_gap(a: Node3D, b: Node3D) -> float:
	if a == null or b == null:
		return INF
	var between := b.global_position - a.global_position
	var distance := between.length()
	if distance <= 0.001:
		return -INF
	var direction := between / distance
	return distance - hull_radius(a, direction) - hull_radius(b, -direction)


# How far this ship reaches from its centre in a given world direction. A ship
# lying beam-on is close from much further out than one lying bow-on, which is
# exactly the difference a single "alongside distance" number cannot express.
static func hull_radius(ship: Node3D, direction: Vector3) -> float:
	var half := half_extents(ship)
	var basis := ship.global_transform.basis
	return absf(direction.dot(basis.x.normalized())) * half.x + absf(direction.dot(basis.z.normalized())) * half.z


# Read from the ship's own collision shape so the measure can never drift from
# the body that physically stops it, including the hit-forgiveness scaling small
# ships get.
static func half_extents(ship: Node3D) -> Vector3:
	var half := DEFAULT_HALF_EXTENTS
	var collision := ship.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		half = (collision.shape as BoxShape3D).size * 0.5 * collision.scale
	return half * ship.scale


# A stand-in for displacement, used to decide who comes off worse in a collision.
# Cubed because a ship a third longer is not a third heavier.
static func mass_of(ship: Node3D) -> float:
	var scale_factor := maxf(0.01, ship.scale.x)
	return pow(scale_factor, 3.0)


# How fast the two are converging along the line between them. Sliding along
# each other barely counts; driving a bow into a beam counts fully.
static func closing_speed(a: Node3D, b: Node3D) -> float:
	var between := b.global_position - a.global_position
	if between.length_squared() <= 0.000001:
		return 0.0
	var direction := between.normalized()
	var relative: Vector3 = _velocity_of(a) - _velocity_of(b)
	return relative.dot(direction)


static func _velocity_of(ship: Node3D) -> Vector3:
	var velocity = ship.get("velocity")
	return velocity if velocity is Vector3 else Vector3.ZERO
