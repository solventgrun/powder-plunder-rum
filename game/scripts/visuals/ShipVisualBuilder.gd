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

var generated_root: Node3D
var sail_nodes: Array[Node3D] = []
var flag_nodes: Array[Node3D] = []
var flag_billboard_nodes: Array[Node3D] = []
var damage_overlay: MeshInstance3D
var fire_socket_positions: Dictionary = {}
var current_profile: Dictionary = {}


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for flag in flag_billboard_nodes:
		if flag == null:
			continue
		var direction := camera.global_position - flag.global_position
		if direction.length_squared() <= 0.001:
			continue
		flag.look_at(camera.global_position, Vector3.UP)


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

	_apply_hull(current_profile.get("hull", {}), faction_id)
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
	if damage_overlay == null:
		return
	var states: Dictionary = current_profile.get("visual_states", {})
	var light_threshold := float(states.get("light_damage_threshold", 0.7))
	var heavy_threshold := float(states.get("heavy_damage_threshold", 0.35))
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


func set_fire_state(_is_burning: bool, _severity: String) -> void:
	pass


func set_mast_broken(is_broken: bool) -> void:
	for sail in sail_nodes:
		sail.visible = not is_broken


func _clear_generated() -> void:
	sail_nodes.clear()
	flag_nodes.clear()
	flag_billboard_nodes.clear()
	fire_socket_positions.clear()
	damage_overlay = null
	if generated_root:
		generated_root.queue_free()
		generated_root = null


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
		mesh_instance.material_override = _standard_material(sail_color, 0.92, true)
		# Default trim matches the controllers' default; ships that never call
		# update_sail_trim (enemy battle ships) still read as filled.
		_apply_sail_billow(mesh_instance, 0.85)
		generated_root.add_child(mesh_instance)
		sail_nodes.append(mesh_instance)


func _build_flags(flags: Dictionary, flag: Dictionary) -> void:
	var flag_ids := flags.keys()
	flag_ids.sort()
	for flag_id in flag_ids:
		var flag_config: Dictionary = flags[flag_id]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Flag_%s" % flag_id
		var flag_size := _parse_vec2(str(flag_config.get("size", "[0.6, 0.35]")))
		var pattern := str(flag.get("pattern", "field"))
		var minimum_size := Vector2(1.55, 0.9) if pattern == "skull" else Vector2(1.2, 0.68)
		flag_size = Vector2(maxf(flag_size.x * 1.9, minimum_size.x), maxf(flag_size.y * 1.9, minimum_size.y))
		mesh_instance.mesh = _make_flag_mesh(flag_size)
		var flag_position := _parse_vec3(str(flag_config.get("position", "[0.0, 1.4, 1.4]")))
		flag_position.x += 0.82
		flag_position.y += 0.42
		mesh_instance.position = flag_position
		mesh_instance.rotation_degrees = Vector3(0.0, -35.0, -4.0)
		mesh_instance.material_override = _make_flag_material(flag)
		generated_root.add_child(mesh_instance)
		flag_nodes.append(mesh_instance)
		flag_billboard_nodes.append(mesh_instance)


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


func _make_flag_mesh(size: Vector2) -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-size.x * 0.5, -size.y * 0.5, 0.0),
		Vector3(size.x * 0.5, -size.y * 0.5, 0.0),
		Vector3(size.x * 0.48, size.y * 0.5, 0.08),
		Vector3(-size.x * 0.48, size.y * 0.5, 0.08)
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0)
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
	var material := _standard_material(Color.WHITE, 0.9, true)
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
