extends Node3D
class_name SplashEffect

# Cannonball water splash: the crown plume is a TemporaryVisual child in the
# scene (scale pop + alpha fade), this root adds a vertical spray burst and
# an expanding foam ring, then frees the whole effect. Root keeps the
# "Splash" name the smoke test asserts on.

const RING_LIFETIME := 0.8
const TOTAL_LIFETIME := 1.0

var age: float = 0.0
var ring: MeshInstance3D


func _ready() -> void:
	_build_spray()
	_build_ring()


func _process(delta: float) -> void:
	# Hitch-frame clamp, same rationale as TemporaryVisual.
	age += minf(delta, 0.1)
	if ring:
		var progress := clampf(age / RING_LIFETIME, 0.0, 1.0)
		var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
		var spread := lerpf(0.6, 3.4, eased)
		ring.scale = Vector3(spread, 1.0, spread)
		ring.transparency = progress
	if age >= TOTAL_LIFETIME:
		queue_free()


func _build_ring() -> void:
	ring = MeshInstance3D.new()
	ring.name = "FoamRing"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.5, 1.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.94, 0.97, 0.92, 0.85)
	material.albedo_texture = EffectSprites.ring_texture()
	mesh.material = material
	ring.mesh = mesh
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _build_spray() -> void:
	var spray := GPUParticles3D.new()
	spray.name = "Spray"
	spray.amount = 18
	spray.lifetime = 0.65
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.local_coords = false
	spray.emitting = true
	spray.visibility_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 8.0, 8.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 24.0
	process_material.initial_velocity_min = 3.2
	process_material.initial_velocity_max = 5.6
	process_material.gravity = Vector3(0.0, -9.8, 0.0)
	process_material.scale_min = 0.5
	process_material.scale_max = 1.0
	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, Color(0.93, 0.98, 0.96, 0.9))
	fade_gradient.set_color(1, Color(0.93, 0.98, 0.96, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	process_material.color_ramp = fade_texture
	spray.process_material = process_material
	var droplet_mesh := QuadMesh.new()
	droplet_mesh.size = Vector2(0.22, 0.22)
	var droplet_material := StandardMaterial3D.new()
	droplet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	droplet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet_material.vertex_color_use_as_albedo = true
	droplet_material.albedo_texture = EffectSprites.puff_texture()
	droplet_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	droplet_mesh.material = droplet_material
	spray.draw_pass_1 = droplet_mesh
	add_child(spray)
