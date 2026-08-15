extends StaticBody3D
class_name JamaicaIsland

@export var land_color: Color = Color(0.13, 0.48, 0.22, 1.0)
@export var shoreline_color: Color = Color(0.84, 0.72, 0.36, 1.0)
# Must stay above the ocean's maximum wave crest (wave_height in
# StylizedOceanMaterial.tres) or wave peaks rise through the land.
@export var land_height: float = 0.75

var outline: PackedVector2Array = PackedVector2Array([
	Vector2(-82.0, -12.0),
	Vector2(-62.0, -24.0),
	Vector2(-34.0, -28.0),
	Vector2(0.0, -22.0),
	Vector2(36.0, -10.0),
	Vector2(82.0, 14.0),
	Vector2(66.0, 30.0),
	Vector2(24.0, 38.0),
	Vector2(-20.0, 32.0),
	Vector2(-58.0, 20.0),
	Vector2(-88.0, 4.0)
])


func _ready() -> void:
	_build_land_mesh()
	_build_land_collision()


func get_outline_points() -> PackedVector2Array:
	return outline


func _build_land_mesh() -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()

	vertices.append(Vector3(0.0, land_height, 4.0))
	colors.append(land_color)
	for point in outline:
		vertices.append(Vector3(point.x, land_height, point.y))
		colors.append(land_color)

	for index in range(1, outline.size()):
		indices.append(0)
		indices.append(index)
		indices.append(index + 1)
	indices.append(0)
	indices.append(outline.size())
	indices.append(1)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.albedo_color = land_color
	material.vertex_color_use_as_albedo = true

	var land_mesh := MeshInstance3D.new()
	land_mesh.name = "LandMesh"
	land_mesh.mesh = mesh
	land_mesh.material_override = material
	add_child(land_mesh)

	var shoreline := MeshInstance3D.new()
	shoreline.name = "Shoreline"
	shoreline.mesh = _build_shoreline_mesh()
	var shore_material := StandardMaterial3D.new()
	shore_material.albedo_color = shoreline_color
	shoreline.material_override = shore_material
	add_child(shoreline)


func _build_shoreline_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var width := 3.0

	for index in range(outline.size()):
		var point := outline[index]
		var previous := outline[(index - 1 + outline.size()) % outline.size()]
		var next := outline[(index + 1) % outline.size()]
		var tangent := (next - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		vertices.append(Vector3(point.x, land_height + 0.01, point.y))
		vertices.append(Vector3(point.x + normal.x * width, land_height + 0.01, point.y + normal.y * width))

	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		indices.append(index * 2)
		indices.append(next_index * 2)
		indices.append(index * 2 + 1)
		indices.append(index * 2 + 1)
		indices.append(next_index * 2)
		indices.append(next_index * 2 + 1)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_land_collision() -> void:
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for point in outline:
		points.append(Vector3(point.x, -0.35, point.y))
		points.append(Vector3(point.x, 1.2, point.y))
	shape.points = points

	var collision := CollisionShape3D.new()
	collision.name = "LandCollision"
	collision.shape = shape
	add_child(collision)
