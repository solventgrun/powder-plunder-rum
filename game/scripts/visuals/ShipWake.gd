extends Node3D
class_name ShipWake

# Foam wake behind a moving ship: a world-space ribbon of fading, widening
# quads laid along the stern's track, plus a speed-keyed bow spray. Lives on
# the ship body (not VisualRoot) so the trail follows the hull's real course
# through the water rather than the bob. The ribbon is a top-level node so
# laid foam stays put in the world while the ship sails on.

const WAKE_FOAM_SHADER := preload("res://game/shaders/ShipWakeFoam.gdshader")

@export var stern_point: Vector3 = Vector3(0.0, 0.0, 2.0)
@export var bow_point: Vector3 = Vector3(0.0, 0.28, -2.2)
# Low enough that AI ships maneuvering under battle sail (galleon ~1-2 u/s)
# still lay a visible trail; only a near-stop goes clean (2026-08-17 playtest:
# "wakes should appear for all vessels").
@export var minimum_speed: float = 0.4
@export var point_spacing: float = 0.9
@export var point_lifetime: float = 4.6
@export var start_width: float = 0.6
@export var end_width: float = 2.8
# Peak per-pixel opacity; the foam shader's lace pattern covers only part of
# the ribbon, so this runs much higher than the old solid-strip alpha did.
@export var foam_alpha: float = 0.92
# A ship under way lays a near-full trail; only a drift reads faint. 6.0 let
# cruising ships (galleon ~2.5) scale every foam term to ~0.4, which is a big
# part of why wakes vanished into the ocean's own foam (2026-08-16 playtest).
@export var full_strength_speed: float = 3.0
# Must clear the CPU wave inversion's worst residual (~0.22u) or stretches
# of ribbon render under the displaced ocean surface and the trail turns
# patchy-to-invisible.
@export var surface_offset: float = 0.24
@export var spray_full_speed: float = 8.0

var ship: Node3D
var wave_field: Node
var ribbon: MeshInstance3D
var ribbon_mesh: ImmediateMesh
var spray: GPUParticles3D
var points: Array[Dictionary] = []
var last_sample_position := Vector3.ZERO
# Live head: while the ship is under way the ribbon's newest edge tracks the
# stern itself every frame, so the wake pours off the hull instead of starting
# at the last laid sample (2026-08-17 playtest: visible gap astern).
var head_active := false
var head_point := Vector3.ZERO
var head_strength := 1.0


func _ready() -> void:
	ship = get_parent() as Node3D
	wave_field = get_node_or_null("/root/OceanWaveField")
	_build_ribbon()
	_build_spray()
	if ship:
		last_sample_position = ship.to_global(stern_point)
		# Visuals build in the ship's _ready, after ours; fit once they exist.
		call_deferred("_fit_to_hull")


# Auto-fit the wake to the hull the ship actually wears: the exported
# stern/bow defaults were tuned on the sloop, and on longer hulls the fresh
# (brightest) stretch of ribbon spawned underneath the ship — a big part of
# why wakes vanished (2026-08-16 playtest).
# Only meshes reaching down to hull level count: masts, yards, sails, and
# especially the aft-streaming masthead streamers all live above deck, and
# including them pushed the stern point (and the whole wake) a ship-length
# behind the hull (2026-08-17 playtest: "wake starts a while after the ship").
const HULL_LEVEL_MAX_Y := 0.4

func _fit_to_hull() -> void:
	if ship == null or not is_inside_tree():
		return
	var visual := ship.get_node_or_null("VisualRoot") as Node3D
	if visual == null:
		return
	var min_z := 999.0
	var max_z := -999.0
	var stack: Array[Node] = [visual]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).visible:
			var mesh_node := node as MeshInstance3D
			var aabb: AABB = mesh_node.get_aabb()
			var rel: Transform3D = ship.global_transform.affine_inverse() * mesh_node.global_transform
			var mesh_min_y := 999.0
			var mesh_min_z := 999.0
			var mesh_max_z := -999.0
			for corner_index in range(8):
				var corner: Vector3 = aabb.position + Vector3(
					aabb.size.x * float(corner_index & 1),
					aabb.size.y * float((corner_index >> 1) & 1),
					aabb.size.z * float((corner_index >> 2) & 1))
				var local := rel * corner
				mesh_min_y = minf(mesh_min_y, local.y)
				mesh_min_z = minf(mesh_min_z, local.z)
				mesh_max_z = maxf(mesh_max_z, local.z)
			if mesh_min_y < HULL_LEVEL_MAX_Y:
				min_z = minf(min_z, mesh_min_z)
				max_z = maxf(max_z, mesh_max_z)
	if max_z <= 0.0:
		return
	stern_point = Vector3(0.0, stern_point.y, max_z + 0.1)
	# Bow spray belongs at the cutwater; with rigging excluded from the scan,
	# min_z is the hull's own stem, so sit nearly on it.
	bow_point = Vector3(0.0, bow_point.y, min_z * 0.92)
	if spray:
		spray.position = bow_point
	last_sample_position = ship.to_global(stern_point)


func _process(delta: float) -> void:
	if ship == null:
		return
	var sunk: Variant = ship.get("is_sunk")
	var is_active := sunk == null or not bool(sunk)
	var velocity: Variant = ship.get("velocity")
	var speed: float = (velocity as Vector3).length() if velocity is Vector3 else 0.0

	var stern_world := ship.to_global(stern_point)
	head_active = is_active and speed >= minimum_speed
	head_point = Vector3(stern_world.x, 0.0, stern_world.z)
	head_strength = clampf(speed / full_strength_speed, 0.3, 1.0)
	# Distance-based sampling: a ship that stops (or sinks with stale
	# velocity) stops laying track automatically.
	if head_active and stern_world.distance_to(last_sample_position) >= point_spacing:
		# Capture lay-time speed so a slow drift leaves a faint track and a
		# full run leaves a bold one.
		points.append({
			"position": head_point,
			"age": 0.0,
			"strength": head_strength
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
	# While under way, a synthetic head point at the stern itself closes the
	# gap between the last laid sample and the hull.
	var draw_points := points
	if head_active and not points.is_empty():
		draw_points = points.duplicate()
		draw_points.append({"position": head_point, "age": 0.0, "strength": head_strength})
	if draw_points.size() < 2:
		return
	var world_scale: float = maxf(ship.global_transform.basis.get_scale().x, 0.001)
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(draw_points.size()):
		var point: Dictionary = draw_points[index]
		var previous: Vector3 = draw_points[maxi(index - 1, 0)].position
		var next: Vector3 = draw_points[mini(index + 1, draw_points.size() - 1)].position
		var direction := Vector3(next.x - previous.x, 0.0, next.z - previous.z)
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		var lateral := direction.normalized().cross(Vector3.UP)
		var progress: float = clampf(float(point.age) / point_lifetime, 0.0, 1.0)
		# Ease-out spread: turbulence widens fast, then coasts.
		var half_width: float = lerpf(start_width, end_width, sqrt(progress)) * 0.5 * world_scale
		# Age fade in alpha, lay strength in red: the shader dims gently with
		# strength instead of multiplying the whole pattern away — a slow ship
		# lays a shorter, calmer wake, not an invisible one.
		var life := 1.0 - progress
		var lay := float(point.get("strength", 1.0))
		var position: Vector3 = point.position
		var height: float = surface_offset
		if wave_field:
			height += float(wave_field.sample_height(position))
		var along := float(index) * point_spacing * 0.15
		ribbon_mesh.surface_set_color(Color(lay, 1.0, 1.0, life))
		ribbon_mesh.surface_set_uv(Vector2(0.0, along))
		ribbon_mesh.surface_add_vertex(Vector3(position.x, 0.0, position.z) + lateral * half_width + Vector3.UP * height)
		ribbon_mesh.surface_set_color(Color(lay, 1.0, 1.0, life))
		ribbon_mesh.surface_set_uv(Vector2(1.0, along))
		ribbon_mesh.surface_add_vertex(Vector3(position.x, 0.0, position.z) - lateral * half_width + Vector3.UP * height)
	ribbon_mesh.surface_end()


func _build_ribbon() -> void:
	ribbon = MeshInstance3D.new()
	ribbon.name = "WakeRibbon"
	ribbon.top_level = true
	ribbon_mesh = ImmediateMesh.new()
	ribbon.mesh = ribbon_mesh
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = WAKE_FOAM_SHADER
	material.set_shader_parameter("max_opacity", foam_alpha)
	# Draw after the ocean surface so near-coplanar stretches never lose the
	# depth fight against the displaced water.
	material.render_priority = 1
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
