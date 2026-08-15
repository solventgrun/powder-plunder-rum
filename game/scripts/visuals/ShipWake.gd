extends Node3D
class_name ShipWake

# Foam wake behind a moving ship: a world-space ribbon of fading, widening
# quads laid along the stern's track, plus a speed-keyed bow spray. Lives on
# the ship body (not VisualRoot) so the trail follows the hull's real course
# through the water rather than the bob. The ribbon is a top-level node so
# laid foam stays put in the world while the ship sails on.

@export var stern_point: Vector3 = Vector3(0.0, 0.0, 2.0)
@export var bow_point: Vector3 = Vector3(0.0, 0.28, -2.2)
@export var minimum_speed: float = 1.0
@export var point_spacing: float = 0.9
@export var point_lifetime: float = 2.8
@export var start_width: float = 0.45
@export var end_width: float = 2.6
@export var foam_alpha: float = 0.42
@export var full_strength_speed: float = 6.0
@export var surface_offset: float = 0.06
@export var spray_full_speed: float = 8.0

var ship: Node3D
var wave_field: Node
var ribbon: MeshInstance3D
var ribbon_mesh: ImmediateMesh
var spray: GPUParticles3D
var points: Array[Dictionary] = []
var last_sample_position := Vector3.ZERO


func _ready() -> void:
	ship = get_parent() as Node3D
	wave_field = get_node_or_null("/root/OceanWaveField")
	_build_ribbon()
	_build_spray()
	if ship:
		last_sample_position = ship.to_global(stern_point)


func _process(delta: float) -> void:
	if ship == null:
		return
	var sunk: Variant = ship.get("is_sunk")
	var is_active := sunk == null or not bool(sunk)
	var velocity: Variant = ship.get("velocity")
	var speed: float = (velocity as Vector3).length() if velocity is Vector3 else 0.0

	var stern_world := ship.to_global(stern_point)
	# Distance-based sampling: a ship that stops (or sinks with stale
	# velocity) stops laying track automatically.
	if is_active and speed >= minimum_speed and stern_world.distance_to(last_sample_position) >= point_spacing:
		# Capture lay-time speed so a slow drift leaves a faint track and a
		# full run leaves a bold one.
		points.append({
			"position": Vector3(stern_world.x, 0.0, stern_world.z),
			"age": 0.0,
			"strength": clampf(speed / full_strength_speed, 0.3, 1.0)
		})
		last_sample_position = stern_world

	for point in points:
		point.age += delta
	while points.size() > 0 and float(points[0].age) > point_lifetime:
		points.remove_at(0)

	_rebuild_ribbon()

	if spray:
		spray.emitting = is_active and speed >= minimum_speed * 1.5
		spray.amount_ratio = clampf(speed / spray_full_speed, 0.25, 1.0)


func _rebuild_ribbon() -> void:
	ribbon_mesh.clear_surfaces()
	if points.size() < 2:
		return
	var world_scale: float = maxf(ship.global_transform.basis.get_scale().x, 0.001)
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(points.size()):
		var point: Dictionary = points[index]
		var previous: Vector3 = points[maxi(index - 1, 0)].position
		var next: Vector3 = points[mini(index + 1, points.size() - 1)].position
		var direction := Vector3(next.x - previous.x, 0.0, next.z - previous.z)
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		var lateral := direction.normalized().cross(Vector3.UP)
		var progress: float = clampf(float(point.age) / point_lifetime, 0.0, 1.0)
		var half_width: float = lerpf(start_width, end_width, progress) * 0.5 * world_scale
		var fade := (1.0 - progress) * foam_alpha * float(point.get("strength", 1.0))
		var position: Vector3 = point.position
		var height: float = surface_offset
		if wave_field:
			height += float(wave_field.sample_height(position))
		ribbon_mesh.surface_set_color(Color(1.0, 1.0, 1.0, fade))
		ribbon_mesh.surface_add_vertex(Vector3(position.x, 0.0, position.z) + lateral * half_width + Vector3.UP * height)
		ribbon_mesh.surface_set_color(Color(1.0, 1.0, 1.0, fade))
		ribbon_mesh.surface_add_vertex(Vector3(position.x, 0.0, position.z) - lateral * half_width + Vector3.UP * height)
	ribbon_mesh.surface_end()


func _build_ribbon() -> void:
	ribbon = MeshInstance3D.new()
	ribbon.name = "WakeRibbon"
	ribbon.top_level = true
	ribbon_mesh = ImmediateMesh.new()
	ribbon.mesh = ribbon_mesh
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.88, 0.97, 0.95, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = material
	add_child(ribbon)
	ribbon.global_transform = Transform3D.IDENTITY


func _build_spray() -> void:
	spray = GPUParticles3D.new()
	spray.name = "BowSpray"
	spray.position = bow_point
	spray.amount = 20
	spray.lifetime = 0.55
	spray.local_coords = false
	spray.emitting = false
	spray.visibility_aabb = AABB(Vector3(-5.0, -2.0, -5.0), Vector3(10.0, 6.0, 10.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.55)
	process_material.spread = 32.0
	process_material.initial_velocity_min = 1.4
	process_material.initial_velocity_max = 2.6
	process_material.gravity = Vector3(0.0, -5.5, 0.0)
	process_material.scale_min = 0.5
	process_material.scale_max = 1.0
	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	fade_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	process_material.color_ramp = fade_texture
	spray.process_material = process_material
	var pass_mesh := QuadMesh.new()
	pass_mesh.size = Vector2(0.15, 0.15)
	var pass_material := StandardMaterial3D.new()
	pass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pass_material.vertex_color_use_as_albedo = true
	pass_material.albedo_color = Color(0.92, 0.99, 0.97, 1.0)
	pass_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pass_mesh.material = pass_material
	spray.draw_pass_1 = pass_mesh
	add_child(spray)
