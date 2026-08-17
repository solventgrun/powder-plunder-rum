extends Node3D
class_name ShipVisualBuilder

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

const COLOR_TABLE := {
	"black": Color(0.02, 0.018, 0.015, 1.0),
	"blue": Color(0.05, 0.16, 0.46, 1.0),
	"bone": Color(0.86, 0.82, 0.68, 1.0),
	"burgundy": Color(0.48, 0.04, 0.06, 1.0),
	"gold": Color(0.9, 0.68, 0.18, 1.0),
	"navy": Color(0.02, 0.06, 0.2, 1.0),
	"red": Color(0.78, 0.05, 0.04, 1.0),
	"white": Color(0.94, 0.9, 0.82, 1.0)
}

const SAIL_PALETTES := {
	"naval_canvas": Color(0.9, 0.82, 0.62, 1.0),
	"spanish_canvas": Color(0.92, 0.78, 0.58, 1.0),
	"dutch_canvas": Color(0.88, 0.82, 0.66, 1.0),
	"pirate_canvas": Color(0.64, 0.55, 0.42, 1.0)
}

# Flags honor the profile-authored sizes with a modest readability bump; the
# old x1.9 inflation plus global minimums were tuned for featureless
# procedural boxes and dwarfed the mesh fleet. The skull keeps a legibility
# floor that scales with the ship instead of one global minimum.
const FLAG_SIZE_MULTIPLIER := 1.3
const FLAG_SKULL_MIN_WIDTH := 0.6  # x profile scale
const FLAG_WAVE_COUNT := 1.3  # wavelengths along the fly
const FLAG_WAVE_SPEED := 8.0  # radians per flag-second
const FLAG_RIPPLE_DEPTH := 0.12  # z swing at the fly tip, x flag width
const FLAG_FLAP_DEPTH := 0.06  # y flap at the fly tip, x flag height

# Chain-shot damage reads on the canvas itself: an alpha-scissor threshold
# rising with tatter eats shot holes through the sail texture. The old
# height-only shrink was invisible at gameplay distance (2026-08-16 playtest).
const SAIL_TATTER_MAX_CUT := 0.72  # alpha-scissor threshold at zero sail
# Cut fraction over tatter, piecewise linear. Hole area grows ~quadratically
# with the cut, so the curve rises fast early (first volleys punch visible
# pockmarks), nearly plateaus through the middle (a 60%-damaged sail reads
# holed, not destroyed — 2026-08-17 playtest), then surges to full shred.
const SAIL_TATTER_CURVE: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(0.25, 0.5),
	Vector2(0.6, 0.62),
	Vector2(0.85, 0.8),
	Vector2(1.0, 1.0),
]
const SAIL_SCORCH := Color(0.36, 0.31, 0.26, 1.0)

# Mast break: the GLB mast assemblies pivot at their deck feet, so the whole
# rig — spars, yards, canvas, rigging — topples overboard per assembly.
const MAST_ASSEMBLY_NAMES := ["ForemastAssembly", "MainmastAssembly", "MizzenAssembly"]
const MAST_FALL_SECONDS := 1.15
const MAST_FALL_STAGGER := 0.45
const MAST_FALL_ROLL_DEGREES := 78.0
const MAST_FALL_PITCH_DEGREES := 14.0

var generated_root: Node3D
var model_visual: Node3D
var sail_nodes: Array[Node3D] = []
var sail_canvas_materials: Array[StandardMaterial3D] = []
var sail_base_color: Color = Color.WHITE
var masts_toppled := false
var mast_fall_tweens: Array[Tween] = []
var flag_nodes: Array[Node3D] = []
var damage_overlay: MeshInstance3D
var fire_socket_positions: Dictionary = {}
var current_profile: Dictionary = {}
var flag_time: float = 0.0
var flag_wind_system: Node
var searched_flag_wind := false
var fire_root: Node3D
var fire_flames: Array[MeshInstance3D] = []
var fire_time: float = 0.0


func _process(delta: float) -> void:
	_animate_fire(delta)
	if flag_nodes.is_empty():
		return
	var wind := _resolve_flag_wind_system()
	var wind_factor := 1.0
	var stream_direction := Vector3.ZERO
	if wind != null:
		stream_direction = wind.get_wind_direction()
		if wind.has_method("get_wind_speed_factor"):
			wind_factor = clampf(float(wind.call("get_wind_speed_factor")), 0.0, 1.6)
	# Flutter pace follows wind strength; windless ships still stir gently.
	flag_time += delta * (0.55 + 0.45 * wind_factor)
	for flag in flag_nodes:
		if not is_instance_valid(flag):
			continue
		if stream_direction.length_squared() > 0.0001:
			var parent := flag.get_parent() as Node3D
			var local_direction: Vector3 = parent.global_transform.basis.inverse() * stream_direction
			local_direction.y = 0.0
			if local_direction.length_squared() > 0.0001:
				# The flag's local +X is the fly direction; yaw it downwind
				# around the staff. Roll/pitch inherit from the hull like a
				# real staff-mounted ensign.
				var target_yaw := atan2(-local_direction.z, local_direction.x)
				flag.rotation.y = lerp_angle(flag.rotation.y, target_yaw, 1.0 - exp(-5.0 * delta))
		_apply_flag_ripple(flag)


# Flame quads breathe on two beat frequencies so the fire never loops
# visibly; taller pulse than wide reads as licking flame.
func _animate_fire(delta: float) -> void:
	if fire_flames.is_empty():
		return
	fire_time += delta
	for flame in fire_flames:
		if not is_instance_valid(flame):
			continue
		var phase: float = flame.get_meta("flame_phase", 0.0)
		var breadth := 1.0 + 0.14 * sin(fire_time * 11.0 + phase)
		var height := 1.0 + 0.26 * sin(fire_time * 17.0 + phase * 1.7)
		flame.scale = Vector3(breadth, height, 1.0)


# Battle ships and the overworld player expose a wind_system property;
# overworld NPCs carry none and keep their aft-streaming default, the same
# graceful degradation wind-heel uses.
func _resolve_flag_wind_system() -> Node:
	if searched_flag_wind:
		return flag_wind_system
	searched_flag_wind = true
	var node: Node = get_parent()
	while node != null:
		var candidate: Variant = node.get("wind_system")
		if candidate is Node:
			flag_wind_system = candidate
			break
		node = node.get_parent()
	return flag_wind_system


func apply_visuals(ship_record: Dictionary, stats: Resource) -> void:
	if stats == null:
		return

	var ship_types := ContentCatalog.load_ship_types()
	var visual_profiles := ContentCatalog.load_ship_visual_profiles()
	var factions := ContentCatalog.load_factions()
	var flags := ContentCatalog.load_flags()
	var ship_type: Dictionary = ship_types.get(str(stats.get("ship_type_id")), {})
	var profile_id := str(stats.get("visual_profile_id"))
	if profile_id.is_empty():
		profile_id = str(ship_type.get("visual_profile", ""))
	current_profile = visual_profiles.get(profile_id, {})
	if current_profile.is_empty():
		return

	_clear_generated()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedVisuals"
	add_child(generated_root)

	var faction_id := str(ship_record.get("faction", "pirates"))
	var faction: Dictionary = factions.get(faction_id, factions.get("pirates", {}))
	var flag: Dictionary = flags.get(str(faction.get("flag", "jolly_roger")), flags.get("jolly_roger", {}))
	var sail_color := _sail_color(str(faction.get("sail_palette", "naval_canvas")), str(ship_record.get("visual_variant", "")))
	sail_base_color = sail_color

	var hull_config: Dictionary = current_profile.get("hull", {})
	if str(hull_config.get("mode", "procedural")) == "mesh" and _apply_mesh_visual(hull_config, sail_color):
		# Model-carried hull/masts/sails/rigging (ADR 0010); flags stay
		# procedural, attached at the model's Anchor_Flag_* empties.
		_build_flags(current_profile.get("flags", {}), flag, _flag_anchor_positions())
		_cache_visual_state_sockets(current_profile.get("visual_states", {}))
		_override_fire_sockets_from_anchors()
	else:
		_apply_hull(hull_config, faction_id)
		_build_masts(current_profile.get("masts", {}))
		_build_sails(current_profile.get("sails", {}), sail_color)
		_build_flags(current_profile.get("flags", {}), flag)
		_cache_visual_state_sockets(current_profile.get("visual_states", {}))
	set_damage_fraction(1.0)


func update_sail_trim(trim: float) -> void:
	for sail in sail_nodes:
		var fullness := lerpf(0.55, 1.0, clampf(trim, 0.0, 1.0))
		sail.scale.x = fullness
		sail.rotation_degrees.y = lerpf(-7.0, 6.0, trim)
		_apply_sail_billow(sail, trim)


func set_damage_fraction(hull_fraction: float) -> void:
	var states: Dictionary = current_profile.get("visual_states", {})
	var light_threshold := float(states.get("light_damage_threshold", 0.7))
	var heavy_threshold := float(states.get("heavy_damage_threshold", 0.35))
	# Progressive listing replaces the translucent overlay box (which wrapped
	# visibly around mesh hulls): ramps from the light-damage threshold to a
	# full wounded lean at zero hull, composed by ShipWaveMotion on VisualRoot.
	var severity := 0.0
	if light_threshold > 0.001:
		severity = clampf((light_threshold - hull_fraction) / light_threshold, 0.0, 1.0)
	var motion := get_parent()
	if motion and motion.has_method("set_damage_list"):
		motion.call("set_damage_list", severity)
	if damage_overlay == null:
		return
	# Procedural-fallback ships keep the old overlay cue.
	if hull_fraction <= heavy_threshold:
		damage_overlay.visible = true
		damage_overlay.scale = Vector3(1.04, 1.05, 1.04)
		damage_overlay.transparency = 0.42
	elif hull_fraction <= light_threshold:
		damage_overlay.visible = true
		damage_overlay.scale = Vector3(1.02, 1.03, 1.02)
		damage_overlay.transparency = 0.68
	else:
		damage_overlay.visible = false


func get_fire_socket_position(socket_id: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return fire_socket_positions.get(socket_id, fallback)


# Severity-scaled shipboard fire at the fire sockets: flickering flame
# billboards, rising embers, and a leaning black smoke column. Severities
# come from the fire levels (ADR 0007): small / medium / large; large also
# ignites the rigging at the sail socket.
const FIRE_INTENSITIES := {"small": 0.6, "medium": 1.0, "large": 1.45}


func set_fire_state(is_burning: bool, severity: String) -> void:
	if not is_burning:
		if fire_root:
			fire_root.queue_free()
			fire_root = null
			fire_flames.clear()
		return
	if fire_root == null:
		_build_fire_visual()
	var intensity: float = FIRE_INTENSITIES.get(severity, 1.0)
	for cluster_name in ["DeckFire", "SailFire"]:
		var cluster := fire_root.get_node_or_null(cluster_name) as Node3D
		if cluster == null:
			continue
		cluster.scale = Vector3.ONE * intensity
		if cluster_name == "SailFire":
			cluster.visible = severity == "large"
		for child in cluster.get_children():
			if child is GPUParticles3D:
				child.amount_ratio = clampf(0.45 + 0.4 * intensity, 0.0, 1.0)


func _build_fire_visual() -> void:
	fire_root = Node3D.new()
	fire_root.name = "FireVisual"
	add_child(fire_root)
	_build_fire_cluster("DeckFire", get_fire_socket_position("deck_fire_main", Vector3(0.0, 0.65, 0.0)), true)
	_build_fire_cluster("SailFire", get_fire_socket_position("sail_fire_main", Vector3(0.0, 1.6, 0.0)), false)


func _build_fire_cluster(cluster_name: String, cluster_position: Vector3, with_smoke: bool) -> void:
	var cluster := Node3D.new()
	cluster.name = cluster_name
	cluster.position = cluster_position
	fire_root.add_child(cluster)
	_add_flame_quad(cluster, Vector2(0.95, 1.4), Color(1.0, 0.42, 0.06, 0.95), Vector3(0.0, 0.5, 0.0))
	_add_flame_quad(cluster, Vector2(0.5, 0.8), Color(1.0, 0.85, 0.32, 0.95), Vector3(0.05, 0.38, 0.05))
	cluster.add_child(_make_ember_particles())
	if with_smoke:
		cluster.add_child(_make_fire_smoke_particles())


func _add_flame_quad(cluster: Node3D, size: Vector2, color: Color, at: Vector3) -> void:
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var quad := QuadMesh.new()
	quad.size = size
	flame.mesh = quad
	flame.position = at
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.albedo_texture = EffectSprites.puff_texture()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	flame.material_override = material
	flame.set_meta("flame_phase", float(fire_flames.size()) * 1.9)
	cluster.add_child(flame)
	fire_flames.append(flame)


func _make_ember_particles() -> GPUParticles3D:
	var embers := GPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 22
	embers.lifetime = 0.9
	embers.local_coords = false
	embers.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 8.0, 6.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 24.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.4
	process.gravity = Vector3(0.0, 0.6, 0.0)
	process.scale_min = 0.35
	process.scale_max = 0.7
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.78, 0.3, 0.95))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	embers.process_material = process
	var pass_mesh := QuadMesh.new()
	pass_mesh.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = EffectSprites.puff_texture()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pass_mesh.material = material
	embers.draw_pass_1 = pass_mesh
	return embers


func _make_fire_smoke_particles() -> GPUParticles3D:
	var smoke := GPUParticles3D.new()
	smoke.name = "FireSmoke"
	smoke.amount = 46
	smoke.lifetime = 3.2
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-5.0, -1.0, -5.0), Vector3(10.0, 14.0, 10.0))
	var process := ParticleProcessMaterial.new()
	# Canted column: hot smoke leans off vertical so the fire reads at
	# gameplay distance instead of hiding behind the sails.
	process.direction = Vector3(0.4, 1.0, 0.12)
	process.spread = 10.0
	process.initial_velocity_min = 1.3
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0.0, 0.5, 0.0)
	process.scale_min = 1.0
	process.scale_max = 2.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.09, 0.08, 0.07, 0.85))
	ramp.set_color(1, Color(0.16, 0.15, 0.14, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	smoke.process_material = process
	var pass_mesh := QuadMesh.new()
	pass_mesh.size = Vector2(1.1, 1.1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = EffectSprites.puff_texture()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pass_mesh.material = material
	smoke.draw_pass_1 = pass_mesh
	return smoke


# Chain shot reads on the canvas: the alpha-scissor cut rises with tatter and
# eats growing shot holes through the cloth, backed by scorch darkening and a
# modest shrink toward the yards. Height-only scale so trim's width animation
# composes.
func set_sail_fraction(sail_fraction: float) -> void:
	var tatter := 1.0 - clampf(sail_fraction, 0.0, 1.0)
	for sail in sail_nodes:
		sail.scale.y = lerpf(1.0, 0.7, tatter)
	var cut_fraction := _tatter_cut_fraction(tatter)
	for material in sail_canvas_materials:
		material.alpha_scissor_threshold = SAIL_TATTER_MAX_CUT * cut_fraction
		material.albedo_color = sail_base_color.lerp(SAIL_SCORCH, cut_fraction * 0.5)


static func _tatter_cut_fraction(tatter: float) -> float:
	var t := clampf(tatter, 0.0, 1.0)
	for index in range(1, SAIL_TATTER_CURVE.size()):
		var segment_end := SAIL_TATTER_CURVE[index]
		if t <= segment_end.x:
			var segment_start := SAIL_TATTER_CURVE[index - 1]
			var span := maxf(segment_end.x - segment_start.x, 0.0001)
			return lerpf(segment_start.y, segment_end.y, (t - segment_start.x) / span)
	return 1.0


# Sail canvas with the shared tatter noise in its alpha channel. At threshold
# zero every texel survives, so an undamaged sail renders exactly as before;
# set_sail_fraction raises the cut. Triplanar so the flattened model sails
# need no UV layout, two-sided so holes read from both faces of the canvas.
func _make_sail_canvas_material(sail_color: Color) -> StandardMaterial3D:
	var material := _standard_material(sail_color, 0.9, true)
	material.albedo_texture = EffectSprites.canvas_tatter_texture()
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(2.2, 2.2, 2.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.0
	sail_canvas_materials.append(material)
	return material


# The masts actually come down (2026-08-16 playtest): each mast assembly
# topples overboard around its deck-foot pivot in a staggered accelerating
# fall, alternating sides, with foam where the masthead strikes the water.
# Procedural-fallback ships keep the old cue (sails vanish; the combat
# component lays the box mast over).
func set_mast_broken(is_broken: bool) -> void:
	if model_visual == null:
		for sail in sail_nodes:
			sail.visible = not is_broken
		return
	if not is_broken:
		_reset_mast_fall()
		return
	if masts_toppled:
		return
	masts_toppled = true
	var assemblies := _find_mast_assemblies()
	for index in range(assemblies.size()):
		_topple_mast(assemblies[index], index)
	# Masthead flags and streamers aren't children of the assemblies (flags
	# are builder-owned at anchor positions, streamers live in the GLB's Flags
	# group), so they'd hover where the masthead used to be. They go down with
	# the rig instead; only the stern ensign keeps flying.
	_set_masthead_canvas_visible(false)


func _set_masthead_canvas_visible(is_visible: bool) -> void:
	for flag in flag_nodes:
		if is_instance_valid(flag) and str(flag.get_meta("flag_anchor", "")) == "main":
			flag.visible = is_visible
	if model_visual:
		for streamer in _find_mesh_children(model_visual, "Streamer_"):
			streamer.visible = is_visible


func _find_mast_assemblies() -> Array[Node3D]:
	var found: Array[Node3D] = []
	if model_visual == null:
		return found
	for assembly_name in MAST_ASSEMBLY_NAMES:
		var node := _find_node_named(model_visual, assembly_name)
		if node:
			found.append(node)
	return found


func _topple_mast(assembly: Node3D, index: int) -> void:
	# Alternate fall sides so a multi-mast wreck sprawls instead of stacking.
	var side := 1.0 if index % 2 == 0 else -1.0
	var tween := create_tween()
	mast_fall_tweens.append(tween)
	tween.tween_interval(0.15 + MAST_FALL_STAGGER * float(index))
	# Accelerating timber fall past the resting angle, then a short rebound
	# settle as the rig fetches up on the rail and its own rigging.
	tween.tween_property(assembly, "rotation_degrees",
		Vector3(-MAST_FALL_PITCH_DEGREES, 0.0, (MAST_FALL_ROLL_DEGREES + 7.0) * side),
		MAST_FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(assembly, "rotation_degrees",
		Vector3(-MAST_FALL_PITCH_DEGREES, 0.0, MAST_FALL_ROLL_DEGREES * side),
		0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_splash_fallen_mast.bind(assembly))


# Masthead water contact: the assembly pivot sits at the deck foot, so the
# fallen tip lies a rig-height away along the toppled local up axis.
func _splash_fallen_mast(assembly: Node3D) -> void:
	if not is_inside_tree() or not is_instance_valid(assembly):
		return
	var height := _estimate_assembly_height(assembly)
	var tip := assembly.global_position + assembly.global_transform.basis.y.normalized() * height
	FoamRingEffect.spawn(get_parent(), Vector3(tip.x, 0.0, tip.z), 0.5, 3.4, 1.1, 0.0, 0.6)
	FollowCamera.add_trauma_at(self, tip, 0.35, 60.0)


func _estimate_assembly_height(assembly: Node3D) -> float:
	var top := 0.0
	for child in assembly.get_children():
		if child is MeshInstance3D:
			var aabb: AABB = (child as MeshInstance3D).get_aabb()
			top = maxf(top, child.position.y + aabb.end.y)
	return maxf(top, 1.0) * assembly.global_transform.basis.get_scale().y


func _reset_mast_fall() -> void:
	if not masts_toppled:
		return
	masts_toppled = false
	for tween in mast_fall_tweens:
		if tween.is_valid():
			tween.kill()
	mast_fall_tweens.clear()
	for assembly in _find_mast_assemblies():
		assembly.rotation_degrees = Vector3.ZERO
	_set_masthead_canvas_visible(true)


func _clear_generated() -> void:
	sail_nodes.clear()
	sail_canvas_materials.clear()
	flag_nodes.clear()
	fire_socket_positions.clear()
	# Kill in-flight mast falls before their target assemblies are freed.
	masts_toppled = false
	for tween in mast_fall_tweens:
		if tween.is_valid():
			tween.kill()
	mast_fall_tweens.clear()
	# Fire visuals anchor to socket positions of the outgoing visuals; a
	# rebuilt ship starts unlit (combat re-lights on the next state change).
	if fire_root:
		fire_root.queue_free()
		fire_root = null
	fire_flames.clear()
	damage_overlay = null
	model_visual = null
	if generated_root:
		generated_root.queue_free()
		generated_root = null
	# Mesh mode hides the scene's primitive placeholders; restore them so a
	# rebuild into procedural mode starts from the normal state.
	for placeholder_name in ["Hull", "Bow", "Mast"]:
		var placeholder := get_parent().get_node_or_null(placeholder_name) as Node3D
		if placeholder:
			placeholder.visible = true


func _apply_mesh_visual(hull: Dictionary, sail_color: Color) -> bool:
	var scene_path := str(hull.get("scene", ""))
	if scene_path.is_empty():
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("ShipVisualBuilder: mesh visual scene not found: %s" % scene_path)
		return false
	model_visual = packed.instantiate() as Node3D
	model_visual.name = "ModelVisual"
	generated_root.add_child(model_visual)

	for placeholder_name in ["Hull", "Bow", "Mast"]:
		var placeholder := get_parent().get_node_or_null(placeholder_name) as Node3D
		if placeholder:
			placeholder.visible = false
			# The scene-file placeholder transforms (e.g. the Bow prism's 45°)
			# are procedural-path staging; neutralize them like _apply_hull does.
			placeholder.rotation_degrees = Vector3.ZERO

	# Model sails (Sail_* meshes) join sail_nodes so faction tint, mast break,
	# and trim keep working; the neutral canvas material takes the tint.
	var sail_material := _make_sail_canvas_material(sail_color)
	for sail in _find_mesh_children(model_visual, "Sail_"):
		sail.material_override = sail_material
		sail_nodes.append(sail)

	# No damage overlay in mesh mode: the box wrapped visibly around detailed
	# hulls. Damage reads through the progressive list (set_damage_fraction).
	return true


func _find_mesh_children(root: Node, prefix: String) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D and root.name.begins_with(prefix):
		found.append(root)
	for child in root.get_children():
		found.append_array(_find_mesh_children(child, prefix))
	return found


func _find_node_named(root: Node, target_name: String) -> Node3D:
	if root.name == target_name and root is Node3D:
		return root
	for child in root.get_children():
		var found := _find_node_named(child, target_name)
		if found:
			return found
	return null


# Position of a node inside the model, accumulated without needing the ship to
# be in the scene tree yet; the model instance sits at the builder's origin, so
# this equals the builder-local position the flag/fire systems expect.
func _position_in_model(node: Node3D) -> Vector3:
	var accumulated := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != model_visual:
		if current is Node3D:
			accumulated = (current as Node3D).transform * accumulated
		current = current.get_parent()
	return accumulated.origin


func _flag_anchor_positions() -> Dictionary:
	var anchors := {}
	if model_visual == null:
		return anchors
	var stern := _find_node_named(model_visual, "Anchor_Flag_Stern")
	if stern:
		anchors["stern"] = _position_in_model(stern)
	var main := _find_node_named(model_visual, "Anchor_Flag_Main")
	if main:
		anchors["main"] = _position_in_model(main)
	return anchors


func _override_fire_sockets_from_anchors() -> void:
	if model_visual == null:
		return
	var mapping := {"deck_fire_main": "Anchor_Fire_Deck", "sail_fire_main": "Anchor_Fire_Sail"}
	for socket_id in mapping:
		var anchor := _find_node_named(model_visual, mapping[socket_id])
		if anchor:
			fire_socket_positions[socket_id] = _position_in_model(anchor)


func _apply_hull(hull: Dictionary, faction_id: String) -> void:
	var length := float(hull.get("length", 3.25))
	var width := float(hull.get("width", 1.45))
	var height := float(hull.get("height", 0.55))
	var bow_length := float(hull.get("bow_length", 1.0))
	var stern_height := float(hull.get("stern_height", 0.0))
	var hull_color := _hull_color(faction_id)

	var hull_node := get_parent().get_node_or_null("Hull") as MeshInstance3D
	if hull_node:
		var hull_mesh := BoxMesh.new()
		hull_mesh.size = Vector3(width, height, length)
		hull_node.mesh = hull_mesh
		hull_node.position = Vector3(0.0, height * 0.62, 0.0)
		hull_node.material_override = _standard_material(hull_color, 0.72)

	var bow_node := get_parent().get_node_or_null("Bow") as MeshInstance3D
	if bow_node:
		bow_node.mesh = _make_bow_mesh(width, height, bow_length)
		bow_node.position = Vector3(0.0, height * 0.62 + 0.003, -(length + bow_length) * 0.5 - 0.003)
		bow_node.rotation_degrees = Vector3.ZERO
		bow_node.material_override = _standard_material(hull_color.lightened(0.12), 0.72)

	if stern_height > 0.0:
		var stern := MeshInstance3D.new()
		stern.name = "SternCastle"
		var stern_mesh := BoxMesh.new()
		stern_mesh.size = Vector3(width * 0.82, stern_height, minf(0.72, length * 0.22))
		stern.mesh = stern_mesh
		stern.position = Vector3(0.0, height + stern_height * 0.5, length * 0.42)
		stern.material_override = _standard_material(hull_color.darkened(0.08), 0.76)
		generated_root.add_child(stern)

	_add_damage_overlay(width, height, length)


func _add_damage_overlay(width: float, height: float, length: float) -> void:
	damage_overlay = MeshInstance3D.new()
	damage_overlay.name = "DamageOverlay"
	var damage_mesh := BoxMesh.new()
	damage_mesh.size = Vector3(width, height * 0.7, length * 0.82)
	damage_overlay.mesh = damage_mesh
	damage_overlay.position = Vector3(0.0, height * 0.72, 0.04)
	damage_overlay.material_override = _standard_material(Color(0.04, 0.03, 0.025, 1.0), 0.95)
	damage_overlay.visible = false
	generated_root.add_child(damage_overlay)


func _build_masts(masts: Dictionary) -> void:
	var sorted_ids := masts.keys()
	sorted_ids.sort()
	var first := true
	for mast_id in sorted_ids:
		var mast: Dictionary = masts[mast_id]
		var mast_node := get_parent().get_node_or_null("Mast") as MeshInstance3D if first else null
		if mast_node == null:
			mast_node = MeshInstance3D.new()
			mast_node.name = "Mast_%s" % mast_id
			generated_root.add_child(mast_node)
		var height := float(mast.get("height", 2.4))
		var thickness := float(mast.get("thickness", 0.14))
		var mast_mesh := BoxMesh.new()
		mast_mesh.size = Vector3(thickness, height, thickness)
		mast_node.mesh = mast_mesh
		var base := _parse_vec3(str(mast.get("position", "[0.0, 0.35, 0.0]")))
		mast_node.position = base + Vector3(0.0, height * 0.5, 0.0)
		mast_node.rotation_degrees = Vector3.ZERO
		mast_node.material_override = _standard_material(Color(0.56, 0.36, 0.18, 1.0), 0.8)
		first = false


func _build_sails(sails: Dictionary, sail_color: Color) -> void:
	var sail_ids := sails.keys()
	sail_ids.sort()
	for sail_id in sail_ids:
		var sail: Dictionary = sails[sail_id]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Sail_%s" % sail_id
		mesh_instance.set_meta("sail_geometry", _build_sail_geometry(str(sail.get("type", "square")), _parse_vec2(str(sail.get("size", "[1.0, 1.0]")))))
		mesh_instance.position = _parse_vec3(str(sail.get("position", "[0.0, 1.2, 0.0]")))
		mesh_instance.material_override = _make_sail_canvas_material(sail_color)
		# Default trim matches the controllers' default; ships that never call
		# update_sail_trim (enemy battle ships) still read as filled.
		_apply_sail_billow(mesh_instance, 0.85)
		generated_root.add_child(mesh_instance)
		sail_nodes.append(mesh_instance)


func _build_flags(flags: Dictionary, flag: Dictionary, anchors: Dictionary = {}) -> void:
	var flag_ids := flags.keys()
	flag_ids.sort()
	var profile_scale := float(current_profile.get("scale", 1.0))
	var pattern := str(flag.get("pattern", "field"))
	var flag_index := 0
	for flag_id in flag_ids:
		var flag_config: Dictionary = flags[flag_id]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Flag_%s" % flag_id
		var flag_size := _parse_vec2(str(flag_config.get("size", "[0.6, 0.35]"))) * FLAG_SIZE_MULTIPLIER
		if pattern == "skull" and flag_size.x < FLAG_SKULL_MIN_WIDTH * profile_scale:
			flag_size *= FLAG_SKULL_MIN_WIDTH * profile_scale / flag_size.x
		mesh_instance.set_meta("flag_geometry", _build_flag_geometry(flag_size))
		# Desynchronize the ripple across a ship's flags.
		mesh_instance.set_meta("flag_phase", float(flag_index) * 2.4)
		# The node origin is the staff: the hoist edge sits at local x=0 and
		# the canvas spans upward, so wind yaw pivots around the pole. Anchors
		# (and the procedural-path profile positions) mark the flag's foot.
		var anchor_key := "stern" if "stern" in str(flag_id) else "main"
		# Masthead flags go down with their mast on a break; the stern ensign
		# flies from the sterncastle staff and survives.
		mesh_instance.set_meta("flag_anchor", anchor_key)
		if anchors.has(anchor_key):
			mesh_instance.position = anchors[anchor_key]
		else:
			mesh_instance.position = _parse_vec3(str(flag_config.get("position", "[0.0, 1.4, 1.4]")))
		# Stream aft until the wind takes it (and forever on windless NPCs).
		mesh_instance.rotation.y = -PI * 0.5
		mesh_instance.material_override = _make_flag_material(flag)
		_apply_flag_ripple(mesh_instance)
		generated_root.add_child(mesh_instance)
		flag_nodes.append(mesh_instance)
		flag_index += 1


func _cache_visual_state_sockets(states: Dictionary) -> void:
	for key in states.keys():
		if key.ends_with("_fire_main"):
			fire_socket_positions[key] = _parse_vec3(str(states[key]))


# Subdivided sail geometry with per-vertex billow weights (0 at the fixed
# edges, 1 mid-canvas) so _apply_sail_billow can puff the canvas bow-ward.
func _build_sail_geometry(sail_type: String, size: Vector2) -> Dictionary:
	var width := size.x
	var height := size.y
	if sail_type == "triangular":
		return _build_triangle_sail([
			Vector3(-width * 0.5, -height * 0.5, 0.0),
			Vector3(width * 0.5, -height * 0.5, 0.0),
			Vector3(width * 0.5, height * 0.5, 0.08)
		], [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)], size)
	if sail_type == "lateen":
		return _build_triangle_sail([
			Vector3(-width * 0.55, -height * 0.48, 0.0),
			Vector3(width * 0.55, -height * 0.3, 0.0),
			Vector3(width * 0.35, height * 0.5, 0.08)
		], [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.82, 0.0)], size)
	if sail_type == "fore_aft":
		return _build_quad_sail([
			Vector3(-width * 0.45, -height * 0.5, 0.0),
			Vector3(width * 0.5, -height * 0.45, 0.0),
			Vector3(width * 0.32, height * 0.5, 0.1),
			Vector3(-width * 0.32, height * 0.42, 0.04)
		], size)
	return _build_quad_sail([
		Vector3(-width * 0.5, -height * 0.5, 0.0),
		Vector3(width * 0.5, -height * 0.5, 0.0),
		Vector3(width * 0.48, height * 0.5, 0.08),
		Vector3(-width * 0.48, height * 0.5, 0.08)
	], size)


# Corners ordered bottom-left, bottom-right, top-right, top-left.
func _build_quad_sail(corners: Array, size: Vector2) -> Dictionary:
	const COLS := 7
	const ROWS := 5
	var vertices := PackedVector3Array()
	var weights := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(ROWS + 1):
		var v := float(row) / float(ROWS)
		for col in range(COLS + 1):
			var u := float(col) / float(COLS)
			var bottom: Vector3 = corners[0].lerp(corners[1], u)
			var top: Vector3 = corners[3].lerp(corners[2], u)
			vertices.append(bottom.lerp(top, v))
			weights.append(sin(PI * u) * sin(PI * v))
			uvs.append(Vector2(u, 1.0 - v))
	for row in range(ROWS):
		for col in range(COLS):
			var index := row * (COLS + 1) + col
			indices.append_array(PackedInt32Array([
				index, index + 1, index + COLS + 2,
				index, index + COLS + 2, index + COLS + 1
			]))
	return {
		"base_vertices": vertices,
		"weights": weights,
		"uvs": uvs,
		"indices": indices,
		"max_billow": minf(size.x, size.y) * 0.42
	}


# Corners ordered so index 2 is the apex; rows subdivide apex-to-foot.
func _build_triangle_sail(corners: Array, corner_uvs: Array, size: Vector2) -> Dictionary:
	const ROWS := 5
	var apex: Vector3 = corners[2]
	var apex_uv: Vector2 = corner_uvs[2]
	var vertices := PackedVector3Array()
	var weights := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_offsets: Array[int] = []
	for row in range(ROWS + 1):
		row_offsets.append(vertices.size())
		for col in range(row + 1):
			var lambda_apex := 1.0 - float(row) / float(ROWS)
			var lambda_left := (float(row) - float(col)) / float(ROWS)
			var lambda_right := float(col) / float(ROWS)
			vertices.append(apex * lambda_apex + corners[0] * lambda_left + corners[1] * lambda_right)
			weights.append(27.0 * lambda_apex * lambda_left * lambda_right)
			uvs.append(apex_uv * lambda_apex + corner_uvs[0] * lambda_left + corner_uvs[1] * lambda_right)
	for row in range(ROWS):
		for col in range(row + 1):
			indices.append_array(PackedInt32Array([
				row_offsets[row] + col, row_offsets[row + 1] + col, row_offsets[row + 1] + col + 1
			]))
			if col < row:
				indices.append_array(PackedInt32Array([
					row_offsets[row] + col, row_offsets[row + 1] + col + 1, row_offsets[row] + col + 1
				]))
	return {
		"base_vertices": vertices,
		"weights": weights,
		"uvs": uvs,
		"indices": indices,
		"max_billow": minf(size.x, size.y) * 0.34
	}


func _apply_sail_billow(mesh_instance: MeshInstance3D, trim: float) -> void:
	var data: Dictionary = mesh_instance.get_meta("sail_geometry", {})
	if data.is_empty():
		return
	var base: PackedVector3Array = data.base_vertices
	var weights: PackedFloat32Array = data.weights
	# Eased sails hang slack; trimmed-in sails fill. Billow is toward the bow
	# (-Z), the direction the prevailing wind presses the canvas.
	var depth: float = float(data.max_billow) * lerpf(0.3, 1.0, clampf(trim, 0.0, 1.0))
	var vertices := PackedVector3Array()
	vertices.resize(base.size())
	for index in range(base.size()):
		var vertex := base[index]
		vertex.z -= weights[index] * depth
		vertices[index] = vertex
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _compute_smooth_normals(vertices, data.indices)
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null:
		mesh = ArrayMesh.new()
		mesh_instance.mesh = mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# Area-weighted smooth normals; without these the rebuilt surface has no
# normal data and the billow gets no shading, which is what made it invisible
# in the 2026-08-13 playtest.
func _compute_smooth_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for triangle_start in range(0, indices.size(), 3):
		var a := indices[triangle_start]
		var b := indices[triangle_start + 1]
		var c := indices[triangle_start + 2]
		var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		normals[a] += face
		normals[b] += face
		normals[c] += face
	for index in range(normals.size()):
		var normal := normals[index]
		normals[index] = normal.normalized() if normal.length_squared() > 0.000001 else Vector3(0.0, 0.0, 1.0)
	return normals


# Subdivided flag canvas: hoist at x=0, fly toward +X, foot at y=0. "reach"
# is each vertex's 0..1 distance from the hoist — the ripple envelope, zero
# at the staff so the attached edge never tears free.
func _build_flag_geometry(size: Vector2) -> Dictionary:
	const COLS := 10
	const ROWS := 4
	var vertices := PackedVector3Array()
	var reach := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(ROWS + 1):
		var v := float(row) / float(ROWS)
		for col in range(COLS + 1):
			var u := float(col) / float(COLS)
			vertices.append(Vector3(u * size.x, (1.0 - v) * size.y, 0.0))
			reach.append(u)
			uvs.append(Vector2(u, v))
	for row in range(ROWS):
		for col in range(COLS):
			var index := row * (COLS + 1) + col
			indices.append_array(PackedInt32Array([
				index, index + 1, index + COLS + 2,
				index, index + COLS + 2, index + COLS + 1
			]))
	return {
		"base_vertices": vertices,
		"reach": reach,
		"uvs": uvs,
		"indices": indices,
		"width": size.x,
		"height": size.y
	}


# Traveling wave from hoist to fly, amplitude growing with reach, plus a
# smaller vertical flap. Same hard-won rule as the sail billow: the rebuilt
# surface needs explicit normals or the deformation gets no shading.
func _apply_flag_ripple(mesh_instance: MeshInstance3D) -> void:
	var data: Dictionary = mesh_instance.get_meta("flag_geometry", {})
	if data.is_empty():
		return
	var base: PackedVector3Array = data.base_vertices
	var reach: PackedFloat32Array = data.reach
	var phase: float = float(mesh_instance.get_meta("flag_phase", 0.0))
	var width: float = data.width
	var height: float = data.height
	var vertices := PackedVector3Array()
	vertices.resize(base.size())
	for index in range(base.size()):
		var vertex := base[index]
		var along := reach[index]
		var wave := TAU * FLAG_WAVE_COUNT * along - FLAG_WAVE_SPEED * flag_time + phase
		vertex.z += width * FLAG_RIPPLE_DEPTH * along * sin(wave)
		vertex.y += height * FLAG_FLAP_DEPTH * along * sin(wave * 0.7 + 1.3)
		vertices[index] = vertex
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _compute_smooth_normals(vertices, data.indices)
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null:
		mesh = ArrayMesh.new()
		mesh_instance.mesh = mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _make_bow_mesh(width: float, height: float, length: float) -> ArrayMesh:
	var half_width := width * 0.5
	var half_height := height * 0.5
	var half_length := length * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width, -half_height, half_length),
		Vector3(half_width, -half_height, half_length),
		Vector3(half_width, half_height, half_length),
		Vector3(-half_width, half_height, half_length),
		Vector3(0.0, -half_height, -half_length),
		Vector3(0.0, half_height, -half_length)
	])
	var indices := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		0, 4, 1,
		3, 2, 5,
		0, 3, 5, 0, 5, 4,
		1, 4, 5, 1, 5, 2
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_flag_material(flag: Dictionary) -> StandardMaterial3D:
	var image := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	var primary := _named_color(str(flag.get("primary_color", "black")))
	var secondary := _named_color(str(flag.get("secondary_color", "white")))
	var accent := _named_color(str(flag.get("accent_color", "gold")))
	var pattern := str(flag.get("pattern", "field"))
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			image.set_pixel(x, y, _flag_pixel(pattern, x, y, image.get_width(), image.get_height(), primary, secondary, accent))
	var texture := ImageTexture.create_from_image(image)
	# Shaded (not unshaded) so the ripple's normals actually read as folds;
	# the chunky NEAREST texture stays per ADR 0010. The emission lift fakes
	# cloth translucency: without it the shadow side goes sky-gray and the
	# faction read flips with the sun.
	var material := _standard_material(Color.WHITE, 0.9, true)
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.emission_enabled = true
	material.emission_texture = texture
	material.emission = Color(0.4, 0.4, 0.4)
	return material


func _add_flag_emblem(flag_node: MeshInstance3D, flag: Dictionary, flag_size: Vector2) -> void:
	var pattern := str(flag.get("pattern", "field"))
	var primary := _named_color(str(flag.get("primary_color", "black")))
	var secondary := _named_color(str(flag.get("secondary_color", "white")))
	var accent := _named_color(str(flag.get("accent_color", "gold")))
	if pattern == "skull":
		_add_skull_emblem(flag_node, flag_size, secondary, primary)
	elif pattern == "diagonal_cross":
		_add_cross_emblem(flag_node, flag_size, secondary)
	elif pattern == "english_red_ensign":
		_add_canton_cross_emblem(flag_node, flag_size, secondary, accent)
	elif pattern == "tricolor_horizontal":
		_add_flag_stripe(flag_node, flag_size, Vector2.ZERO, Vector2(flag_size.x * 0.9, flag_size.y * 0.18), secondary)
	else:
		_add_flag_stripe(flag_node, flag_size, Vector2.ZERO, Vector2(flag_size.x * 0.55, flag_size.y * 0.16), accent if accent != primary else secondary)


func _add_skull_emblem(flag_node: Node3D, flag_size: Vector2, mark_color: Color, cutout_color: Color) -> void:
	var skull := _make_emblem_disc("Emblem_Skull", Vector2(flag_size.x * 0.34, flag_size.y * 0.34), mark_color)
	skull.position = Vector3(0.0, 0.02, 0.014)
	flag_node.add_child(skull)
	var jaw := _make_emblem_box("Emblem_Jaw", Vector2(flag_size.x * 0.16, flag_size.y * 0.16), mark_color)
	jaw.position = Vector3(0.0, -flag_size.y * 0.18, 0.016)
	flag_node.add_child(jaw)
	for offset in [Vector2(-flag_size.x * 0.08, 0.04), Vector2(flag_size.x * 0.08, 0.04)]:
		var eye := _make_emblem_disc("Emblem_Eye", Vector2(flag_size.x * 0.08, flag_size.y * 0.08), cutout_color)
		eye.position = Vector3(offset.x, offset.y, 0.018)
		flag_node.add_child(eye)
	for rotation in [-38.0, 38.0]:
		var bone := _make_emblem_box("Emblem_Bone", Vector2(flag_size.x * 0.78, flag_size.y * 0.08), mark_color)
		bone.rotation_degrees.z = rotation
		bone.position = Vector3(0.0, -flag_size.y * 0.05, 0.012)
		flag_node.add_child(bone)


func _add_cross_emblem(flag_node: Node3D, flag_size: Vector2, mark_color: Color) -> void:
	for rotation in [-36.0, 36.0]:
		var stripe := _make_emblem_box("Emblem_DiagonalCross", Vector2(flag_size.x * 1.12, flag_size.y * 0.16), mark_color)
		stripe.rotation_degrees.z = rotation
		stripe.position = Vector3(0.0, 0.0, 0.014)
		flag_node.add_child(stripe)


func _add_canton_cross_emblem(flag_node: Node3D, flag_size: Vector2, mark_color: Color, field_color: Color) -> void:
	var canton := _make_emblem_box("Emblem_Canton", Vector2(flag_size.x * 0.42, flag_size.y * 0.42), field_color)
	canton.position = Vector3(-flag_size.x * 0.24, flag_size.y * 0.18, 0.012)
	flag_node.add_child(canton)
	var vertical := _make_emblem_box("Emblem_CantonCross", Vector2(flag_size.x * 0.08, flag_size.y * 0.42), mark_color)
	vertical.position = Vector3(-flag_size.x * 0.24, flag_size.y * 0.18, 0.014)
	flag_node.add_child(vertical)
	var horizontal := _make_emblem_box("Emblem_CantonCross", Vector2(flag_size.x * 0.42, flag_size.y * 0.08), mark_color)
	horizontal.position = Vector3(-flag_size.x * 0.24, flag_size.y * 0.18, 0.016)
	flag_node.add_child(horizontal)


func _add_flag_stripe(flag_node: Node3D, flag_size: Vector2, offset: Vector2, stripe_size: Vector2, color: Color) -> void:
	var stripe := _make_emblem_box("Emblem_Stripe", stripe_size, color)
	stripe.position = Vector3(offset.x, offset.y, 0.014)
	flag_node.add_child(stripe)


func _make_emblem_box(node_name: String, size: Vector2, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.rotation_degrees.x = 0.0
	node.material_override = _emblem_material(color)
	return node


func _make_emblem_disc(node_name: String, size: Vector2, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 4
	node.mesh = mesh
	node.scale = Vector3(size.x, size.y, 0.02)
	node.rotation_degrees.x = 90.0
	node.material_override = _emblem_material(color)
	return node


func _emblem_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _flag_pixel(pattern: String, x: int, y: int, width: int, height: int, primary: Color, secondary: Color, accent: Color) -> Color:
	if pattern == "tricolor_horizontal":
		if y < height / 3:
			return primary
		if y < height * 2 / 3:
			return secondary
		return accent
	if pattern == "diagonal_cross":
		var on_cross := absf(float(y) - float(x) * float(height) / float(width)) < 3.0 or absf(float(y) - float(height - 1 - x * height / width)) < 3.0
		return secondary if on_cross else primary
	if pattern == "english_red_ensign":
		if x < width / 3 and y < height / 2:
			if abs(x - width / 6) < 2 or abs(y - height / 4) < 2:
				return secondary
			return accent
		return primary
	if pattern == "skull":
		var border := x < 4 or y < 4 or x >= width - 4 or y >= height - 4
		var cx := width / 2
		var cy := height / 2 - 3
		var skull: bool = pow(float(x - cx) / 18.0, 2.0) + pow(float(y - cy) / 15.0, 2.0) < 1.0
		var jaw: bool = abs(x - cx) < 10 and y > cy + 9 and y < cy + 22
		var eye_left: bool = pow(float(x - (cx - 7)) / 4.5, 2.0) + pow(float(y - (cy - 2)) / 4.0, 2.0) < 1.0
		var eye_right: bool = pow(float(x - (cx + 7)) / 4.5, 2.0) + pow(float(y - (cy - 2)) / 4.0, 2.0) < 1.0
		var nose: bool = abs(x - cx) < 3 and y > cy + 3 and y < cy + 12
		var bone_a: bool = abs(float(y) - (float(height) - float(x) * float(height) / float(width))) < 4.0 and x > 12 and x < width - 12
		var bone_b: bool = abs(float(y) - (float(x) * float(height) / float(width))) < 4.0 and x > 12 and x < width - 12
		var bone_caps: bool = false
		for cap in [
			Vector2(width * 0.18, height * 0.18),
			Vector2(width * 0.82, height * 0.82),
			Vector2(width * 0.18, height * 0.82),
			Vector2(width * 0.82, height * 0.18)
		]:
			if Vector2(x, y).distance_to(cap) < 5.5:
				bone_caps = true
		if border:
			return secondary
		if eye_left or eye_right or nose:
			return primary
		return secondary if skull or jaw or bone_a or bone_b or bone_caps else primary
	return primary


func _standard_material(color: Color, roughness: float, two_sided: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _hull_color(faction_id: String) -> Color:
	if faction_id == "spain":
		return Color(0.5, 0.2, 0.08, 1.0)
	if faction_id == "france":
		return Color(0.38, 0.24, 0.12, 1.0)
	if faction_id == "dutch":
		return Color(0.42, 0.26, 0.12, 1.0)
	if faction_id == "england":
		return Color(0.44, 0.18, 0.08, 1.0)
	return Color(0.24, 0.18, 0.13, 1.0)


func _sail_color(palette_id: String, variant: String) -> Color:
	var color: Color = SAIL_PALETTES.get(palette_id, SAIL_PALETTES.naval_canvas)
	if variant == "worn":
		color = color.darkened(0.16)
	elif variant == "patrol":
		color = color.lightened(0.06)
	return color


func _named_color(color_id: String) -> Color:
	return COLOR_TABLE.get(color_id, Color.WHITE)


func _parse_vec2(text: String) -> Vector2:
	var parts := _parse_number_list(text)
	return Vector2(float(parts[0]) if parts.size() > 0 else 0.0, float(parts[1]) if parts.size() > 1 else 0.0)


func _parse_vec3(text: String) -> Vector3:
	var parts := _parse_number_list(text)
	return Vector3(
		float(parts[0]) if parts.size() > 0 else 0.0,
		float(parts[1]) if parts.size() > 1 else 0.0,
		float(parts[2]) if parts.size() > 2 else 0.0
	)


func _parse_number_list(text: String) -> Array[float]:
	var clean := text.strip_edges().trim_prefix("[").trim_suffix("]")
	var numbers: Array[float] = []
	for part in clean.split(",", false):
		var trimmed := part.strip_edges()
		if trimmed.is_valid_float():
			numbers.append(float(trimmed))
	return numbers
