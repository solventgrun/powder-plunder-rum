extends Node3D
class_name MagazineExplosionEffect

# Magazine explosion as a sequence (Tier 3): flash core + light blink, a
# ballooning black smoke ball, flung plank debris on real gravity, and an
# expanding water shockwave ring. Root keeps the "MagazineExplosion" name the
# smoke test asserts on.

const FLASH_LIFETIME := 0.24
const LIGHT_LIFETIME := 0.2
const TOTAL_LIFETIME := 2.6

var age: float = 0.0
var flash: Node3D
var blink: OmniLight3D
var blink_energy: float = 9.0


func _ready() -> void:
	flash = get_node_or_null("FlashCore")
	blink = get_node_or_null("Blink") as OmniLight3D
	if blink:
		blink_energy = blink.light_energy
	_build_smoke_ball()
	_build_debris()
	# The shockwave lives under our parent so it survives if battle cleanup
	# frees this effect early; it self-frees on its own clock.
	FoamRingEffect.spawn(get_parent(), global_position, 0.8, 11.0, 1.1, 0.08, 0.9)
	FollowCamera.add_trauma_at(self, global_position, 0.9, 100.0)


func _process(delta: float) -> void:
	# Hitch-frame clamp, same rationale as TemporaryVisual.
	age += minf(delta, 0.1)
	if flash:
		flash.scale = Vector3.ONE * lerpf(0.3, 1.6, clampf(age / FLASH_LIFETIME, 0.0, 1.0))
		flash.visible = age < FLASH_LIFETIME
	if blink:
		blink.light_energy = blink_energy * maxf(1.0 - age / LIGHT_LIFETIME, 0.0)
		blink.visible = age < LIGHT_LIFETIME
	if age >= TOTAL_LIFETIME:
		queue_free()


func _build_smoke_ball() -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "SmokeBall"
	# Born at deck height — at the waterline origin the hull swallowed half
	# the ball and it read as thin haze.
	smoke.position = Vector3(0.0, 1.4, 0.0)
	smoke.amount = 42
	smoke.lifetime = 1.7
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.local_coords = false
	smoke.emitting = true
	smoke.visibility_aabb = AABB(Vector3(-10.0, -3.0, -10.0), Vector3(20.0, 18.0, 20.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.75, 0.0)
	process.spread = 85.0
	process.initial_velocity_min = 3.5
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0.0, 1.1, 0.0)
	process.damping_min = 1.6
	process.damping_max = 2.6
	process.scale_min = 1.4
	process.scale_max = 2.6
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.45))
	growth.add_point(Vector2(1.0, 2.1))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth
	process.scale_curve = growth_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(0.07, 0.06, 0.06, 1.0))
	fade.add_point(0.5, Color(0.09, 0.08, 0.08, 0.85))
	fade.set_color(1, Color(0.24, 0.23, 0.22, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var puff_mesh := QuadMesh.new()
	puff_mesh.size = Vector2(1.5, 1.5)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_texture = EffectSprites.puff_texture()
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_mesh.material = puff_material
	smoke.draw_pass_1 = puff_mesh
	add_child(smoke)


func _build_debris() -> void:
	var debris := GPUParticles3D.new()
	debris.name = "PlankDebris"
	debris.amount = 16
	debris.lifetime = 1.9
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.local_coords = false
	debris.emitting = true
	debris.visibility_aabb = AABB(Vector3(-12.0, -4.0, -12.0), Vector3(24.0, 20.0, 24.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 55.0
	process.initial_velocity_min = 6.5
	process.initial_velocity_max = 11.5
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.angular_velocity_min = -420.0
	process.angular_velocity_max = 420.0
	process.scale_min = 0.7
	process.scale_max = 1.3
	debris.process_material = process
	var plank := BoxMesh.new()
	plank.size = Vector3(0.55, 0.07, 0.14)
	var plank_material := StandardMaterial3D.new()
	plank_material.albedo_color = Color(0.32, 0.2, 0.1, 1.0)
	plank_material.roughness = 0.9
	plank.material = plank_material
	debris.draw_pass_1 = plank
	add_child(debris)
