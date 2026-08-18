class_name HullSplinterEffect
extends Node3D

# Timber giving way where two hulls meet: splinters flung out along the line of
# impact on real gravity, plus a short puff of dust and spray at the contact
# point. Modelled on the plank debris in MagazineExplosionEffect, but thrown
# sideways from the collision rather than up out of an explosion.
#
# Spawned by ShipCollisionSystem; scaled by how hard the ships hit.

const SPLINTER_COLOR := Color(0.34, 0.22, 0.12, 1.0)
const SPLINTER_PALE := Color(0.55, 0.4, 0.24, 1.0)

var lifetime: float = 2.2


# Built by the caller rather than through a static factory: a script cannot
# reliably reference its own class_name from a static function before Godot has
# rescanned the project, which fails in tool and headless runs.
#
# `normal` points from one hull toward the other: splinters spray back along it,
# the way timber bursts out of a seam.
func build(normal: Vector3, raw_strength: float) -> void:
	var strength := clampf(raw_strength, 0.2, 1.6)
	var direction := normal.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.UP
	# Bias upward so shards arc over the rail instead of skimming the water.
	var throw := (direction + Vector3.UP * 0.85).normalized()

	_build_splinters(throw, strength, SPLINTER_COLOR, 24, 0.75)
	# A second, paler, faster burst reads as fresh-broken timber against the
	# darker weathered planking.
	_build_splinters(throw, strength * 1.25, SPLINTER_PALE, 14, 0.46)
	_build_dust(strength)

	var timer := get_tree().create_timer(lifetime) if get_tree() else null
	if timer:
		timer.timeout.connect(queue_free)


func _build_splinters(throw: Vector3, strength: float, color: Color, amount: int, size: float) -> void:
	var splinters := GPUParticles3D.new()
	splinters.amount = maxi(4, int(float(amount) * clampf(strength, 0.35, 1.4)))
	splinters.lifetime = 1.6
	splinters.one_shot = true
	splinters.explosiveness = 1.0
	splinters.local_coords = false
	splinters.emitting = true
	splinters.visibility_aabb = AABB(Vector3(-10.0, -4.0, -10.0), Vector3(20.0, 16.0, 20.0))

	var process := ParticleProcessMaterial.new()
	process.direction = throw
	process.spread = 62.0
	process.initial_velocity_min = 3.5 * strength
	process.initial_velocity_max = 8.5 * strength
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.angular_velocity_min = -520.0
	process.angular_velocity_max = 520.0
	process.scale_min = 0.6
	process.scale_max = 1.35
	splinters.process_material = process

	var shard := BoxMesh.new()
	shard.size = Vector3(size, 0.07, 0.13)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	shard.material = material
	splinters.draw_pass_1 = shard
	add_child(splinters)


# Dust and spray kicked off the seam: short-lived, and it sells the crunch more
# than the shards do at a distance.
func _build_dust(strength: float) -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 14
	dust.lifetime = 0.85
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.local_coords = false
	dust.emitting = true
	dust.visibility_aabb = AABB(Vector3(-6.0, -3.0, -6.0), Vector3(12.0, 9.0, 12.0))

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 80.0
	process.initial_velocity_min = 1.2 * strength
	process.initial_velocity_max = 3.4 * strength
	process.gravity = Vector3(0.0, -1.4, 0.0)
	process.scale_min = 0.8 * strength
	process.scale_max = 2.1 * strength
	dust.process_material = process

	var puff := SphereMesh.new()
	puff.radius = 0.32
	puff.height = 0.64
	puff.radial_segments = 6
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.55, 0.44, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = material
	dust.draw_pass_1 = puff
	add_child(dust)
