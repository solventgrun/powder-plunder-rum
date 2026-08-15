"""Scene and mesh primitives shared by all ship generators.

House-style helpers: soft-beveled cubes, weighted normals everywhere, tapered
spars, multi-point rope-ready polylines. add_panel_frame/add_window expect the
standard materials dict keys ("gold", "red_paint", "black").
"""
import bmesh
import bpy
from mathutils import Matrix, Vector


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_cube(name, loc, scale, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material:
        obj.data.materials.append(material)
    if bevel > 0:
        mod = obj.modifiers.new("soft bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_ellipsoid(name, loc, scale, material, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    if material:
        obj.data.materials.append(material)
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_panel_frame(name, center, width, height, depth, materials, frame="gold", inset="red_paint"):
    x, y, z = center
    frame_mat = materials[frame]
    inset_mat = materials[inset]
    add_cube(f"{name}_inset", (x, y, z), (width, height, depth), inset_mat, 0.006)
    add_cube(f"{name}_top", (x, y + height * 0.5, z + depth * 0.02), (width + 0.06, 0.026, depth * 1.16), frame_mat, 0.006)
    add_cube(f"{name}_bottom", (x, y - height * 0.5, z + depth * 0.02), (width + 0.06, 0.026, depth * 1.16), frame_mat, 0.006)
    add_cube(f"{name}_left", (x - width * 0.5, y, z + depth * 0.025), (0.026, height + 0.040, depth * 1.18), frame_mat, 0.006)
    add_cube(f"{name}_right", (x + width * 0.5, y, z + depth * 0.025), (0.026, height + 0.040, depth * 1.18), frame_mat, 0.006)


def recalc_outward_normals(mesh):
    # from_pydata does not guarantee consistent winding; inverted faces make the
    # bevel modifier flare rims outward into curled corner spikes.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()


def add_tapered_box(name, loc, bottom_width, top_width, height, depth, material, bevel=0.0):
    x0 = bottom_width * 0.5
    x1 = top_width * 0.5
    y0 = height * 0.5
    z0 = depth * 0.5
    verts = [
        (-x0, -y0, -z0), (x0, -y0, -z0), (x0, -y0, z0), (-x0, -y0, z0),
        (-x1, y0, -z0), (x1, y0, -z0), (x1, y0, z0), (-x1, y0, z0),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    recalc_outward_normals(mesh)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if bevel > 0:
        mod = obj.modifiers.new("soft bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_stern_gallery_tier(
    name,
    y_bottom,
    y_top,
    z_front,
    z_back,
    front_bottom_width,
    back_bottom_width,
    front_top_width,
    back_top_width,
    material,
    bevel=0.0,
):
    cols = [-1.0, -0.5, 0.0, 0.5, 1.0]
    verts = []
    idx = {}
    for depth in (0, 1):
        for level, y in enumerate((y_bottom, y_top)):
            for col, u in enumerate(cols):
                if depth == 0:
                    width = front_bottom_width if level == 0 else front_top_width
                    z = z_front
                else:
                    width = back_bottom_width if level == 0 else back_top_width
                    curve = 0.0
                    rake = 0.0
                    z = z_back + curve + rake
                idx[(depth, level, col)] = len(verts)
                verts.append((u * width * 0.5, y, z))

    faces = []
    for depth in (0, 1):
        for col in range(len(cols) - 1):
            face = (
                idx[(depth, 0, col)],
                idx[(depth, 0, col + 1)],
                idx[(depth, 1, col + 1)],
                idx[(depth, 1, col)],
            )
            faces.append(face if depth == 0 else tuple(reversed(face)))
    for level in (0, 1):
        for col in range(len(cols) - 1):
            faces.append((
                idx[(0, level, col)],
                idx[(1, level, col)],
                idx[(1, level, col + 1)],
                idx[(0, level, col + 1)],
            ))
    for side_col in (0, len(cols) - 1):
        faces.append((
            idx[(0, 0, side_col)],
            idx[(0, 1, side_col)],
            idx[(1, 1, side_col)],
            idx[(1, 0, side_col)],
        ))

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    recalc_outward_normals(mesh)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if bevel > 0:
        mod = obj.modifiers.new("soft bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_cylinder_between(name, start, end, radius, material, vertices=16):
    start = Vector(start)
    end = Vector(end)
    mid = (start + end) * 0.5
    length = (end - start).length
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
    if material:
        obj.data.materials.append(material)
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_spar(name, start, end, radius_base, radius_tip, material, vertices=14):
    # Tapered spar (mast, topmast, lateen yard): a cone frustum between two points.
    start = Vector(start)
    end = Vector(end)
    mid = (start + end) * 0.5
    length = (end - start).length
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius_base, radius2=radius_tip, depth=length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
    if material:
        obj.data.materials.append(material)
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_polyline(name, points, radius, material):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (co[0], co[1], co[2], 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    if material:
        curve.materials.append(material)
    return obj


def add_window(name, loc, size, materials):
    gold = materials["gold"]
    black = materials["black"]
    red = materials["red_paint"]
    add_cube(f"{name}_gold_outer", loc, (size[0] * 1.18, size[1] * 1.16, size[2]), gold, 0.008)
    add_cube(f"{name}_red_inner_frame", (loc[0], loc[1], loc[2] + size[2] * 0.18), (size[0], size[1] * 0.92, size[2] * 1.12), red, 0.008)
    add_cube(f"{name}_dark_glass", (loc[0], loc[1], loc[2] + size[2] * 0.42), (size[0] * 0.62, size[1] * 0.62, size[2] * 1.18), black, 0.004)


def add_surface_cube(name, frame, local_offset, size, material, bevel=0.0):
    # A cube oriented to a hull surface frame: local x runs outboard along the
    # surface normal, y up the skin, z along the hull.
    origin, e_x, e_y, e_z = frame
    loc = origin + e_x * local_offset[0] + e_y * local_offset[1] + e_z * local_offset[2]
    obj = add_cube(name, tuple(loc), size, material, bevel)
    obj.rotation_euler = Matrix((e_x, e_y, e_z)).transposed().to_euler()
    return obj
