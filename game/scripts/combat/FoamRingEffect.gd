class_name FoamRingEffect
extends MeshInstance3D

# One expanding, fading foam ring laid flat on the water, riding the sampled
# wave height so it stays on the swell instead of clipping through it. Used
# by the magazine-explosion shockwave and the sinking foam pulses.

var delay: float = 0.0
var duration: float = 1.2
var start_radius: float = 0.6
var end_radius: float = 6.0
var max_opacity: float = 0.85

var age: float = 0.0
var anchor_xz: Vector2 = Vector2.ZERO
var wave_field: Node


static func spawn(parent: Node, world_position: Vector3, ring_start: float, ring_end: float, ring_duration: float, ring_delay: float = 0.0, opacity: float = 0.85) -> void:
	if parent == null:
		return
	var ring := FoamRingEffect.new()
	ring.name = "FoamRing"
	ring.start_radius = ring_start
	ring.end_radius = ring_end
	ring.duration = ring_duration
	ring.delay = ring_delay
	ring.max_opacity = opacity
	ring.anchor_xz = Vector2(world_position.x, world_position.z)
	parent.add_child(ring)
	ring.global_position = Vector3(world_position.x, 0.14, world_position.z)


func _ready() -> void:
	wave_field = get_node_or_null("/root/OceanWaveField")
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	rotation_degrees.x = -90.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.94, 0.97, 0.92, 1.0)
	material.albedo_texture = EffectSprites.ring_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	visible = false
	scale = Vector3.ONE * maxf(start_radius, 0.01)


func _process(delta: float) -> void:
	# Hitch-frame clamp, same rationale as TemporaryVisual.
	age += minf(delta, 0.1)
	var progress := (age - delay) / duration
	if progress < 0.0:
		return
	if progress >= 1.0:
		queue_free()
		return
	visible = true
	# Ease-out spread: fast initial push, coasting wide.
	var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
	var radius := lerpf(start_radius, end_radius, eased)
	scale = Vector3.ONE * radius
	transparency = 1.0 - max_opacity * (1.0 - progress)
	var height := 0.14
	if wave_field:
		height += float(wave_field.sample_height(Vector3(anchor_xz.x, 0.0, anchor_xz.y)))
	global_position = Vector3(anchor_xz.x, height, anchor_xz.y)
