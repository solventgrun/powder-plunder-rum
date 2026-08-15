extends Node3D
class_name MuzzleFlashEffect

# Muzzle effect: the original emissive flash core (scale pop), plus a
# one-shot black powder smoke burst and a brief warm light blink.
# Node keeps the "MuzzleFlash" root name the smoke test asserts on.

const FLASH_LIFETIME := 0.16
const LIGHT_LIFETIME := 0.11
const TOTAL_LIFETIME := 1.0

var age: float = 0.0
var flash: Node3D
var blink: OmniLight3D
var blink_energy: float = 4.5


func _ready() -> void:
	flash = get_node_or_null("FlashCore")
	blink = get_node_or_null("Blink") as OmniLight3D
	if blink:
		blink_energy = blink.light_energy
	_build_smoke()


func _process(delta: float) -> void:
	# Hitch-frame clamp, same rationale as TemporaryVisual.
	age += minf(delta, 0.1)
	if flash:
		flash.scale = Vector3.ONE * lerpf(0.2, 0.9, clampf(age / FLASH_LIFETIME, 0.0, 1.0))
		flash.visible = age < FLASH_LIFETIME
	if blink:
		blink.light_energy = blink_energy * maxf(1.0 - age / LIGHT_LIFETIME, 0.0)
		blink.visible = age < LIGHT_LIFETIME
	if age >= TOTAL_LIFETIME:
		queue_free()


func _build_smoke() -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "PowderSmoke"
	smoke.amount = 12
	smoke.lifetime = 0.8
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.local_coords = false
	smoke.emitting = true
	smoke.visibility_aabb = AABB(Vector3(-6.0, -3.0, -6.0), Vector3(12.0, 8.0, 12.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 0.6, 0.0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 2.2
	process_material.gravity = Vector3(0.0, 1.4, 0.0)
	process_material.damping_min = 1.5
	process_material.damping_max = 2.5
	process_material.scale_min = 0.8
	process_material.scale_max = 1.3
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.5))
	growth.add_point(Vector2(1.0, 1.6))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth
	process_material.scale_curve = growth_texture
	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, Color(0.08, 0.08, 0.08, 0.85))
	fade_gradient.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	fade_gradient.add_point(0.35, Color(0.12, 0.12, 0.12, 0.6))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	process_material.color_ramp = fade_texture
	smoke.process_material = process_material
	var puff_mesh := QuadMesh.new()
	puff_mesh.size = Vector2(0.7, 0.7)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_texture = EffectSprites.puff_texture()
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_mesh.material = puff_material
	smoke.draw_pass_1 = puff_mesh
	add_child(smoke)
