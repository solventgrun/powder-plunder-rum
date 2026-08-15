import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


OUT_DIR = Path(__file__).resolve().parent


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, roughness=0.72, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


def wood_mat(name, base, grain, dark_line):
    material = mat(name, base, 0.78)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")

    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (0.85, 2.8, 10.0)
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    noise.inputs["Detail"].default_value = 13.0
    noise.inputs["Roughness"].default_value = 0.62
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.22
    ramp.color_ramp.elements[0].color = dark_line
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = grain
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.055
    bump.inputs["Distance"].default_value = 0.075

    links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return material


def gold_mat(name):
    material = mat(name, (0.78, 0.56, 0.20, 1), 0.58, 0.28)
    nodes = material.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Specular IOR Level"].default_value = 0.48
    return material


def paint_mat(name, base, highlight, shadow):
    material = mat(name, base, 0.54)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")

    coord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.0
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.56
    wave = nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 26.0
    wave.inputs["Distortion"].default_value = 4.0
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.10
    ramp.color_ramp.elements[0].color = shadow
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = highlight
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["Factor"].default_value = 0.045
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.030
    bump.inputs["Distance"].default_value = 0.055

    links.new(coord.outputs["Generated"], noise.inputs["Vector"])
    links.new(coord.outputs["Generated"], wave.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["A"])
    links.new(wave.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return material


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


def add_hull_side_box(name, side, z, t, size, material, offset=0.055, bevel=0.0):
    x, y, _ = side_point(z, side, t, offset)
    return add_cube(name, (x, y, z), size, material, bevel)


def add_side_gunport(name, side, z, t, materials, size=0.16, offset=0.060):
    gold = materials["gold"]
    red = materials["red_paint"]
    black = materials["black"]
    x, y, _ = side_point(z, side, t, offset)
    add_cube(f"{name}_wood_recess", (x - side * 0.010, y, z), (0.036, size * 1.14, size * 1.26), materials["dark_wood"], 0.006)
    add_cube(f"{name}_structural_lintel", (x - side * 0.004, y + size * 0.55, z), (0.030, 0.024, size * 1.22), gold, 0.004)
    add_cube(f"{name}_structural_sill", (x - side * 0.004, y - size * 0.55, z), (0.030, 0.024, size * 1.22), gold, 0.004)
    add_cube(f"{name}_red_reveal", (x, y, z), (0.036, size * 0.82, size * 0.90), red, 0.006)
    add_cube(f"{name}_dark_port", (x + side * 0.010, y, z), (0.042, size * 0.46, size * 0.54), black, 0.003)


def add_shaped_deck(name, z_values, materials, t=0.985, inset=0.020, lift=0.050):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    verts = []
    for z in z_values:
        left = side_point(z, -1, t, -inset)
        right = side_point(z, 1, t, -inset)
        y = max(left[1], right[1]) + lift
        verts.append((left[0], y, z))
        verts.append((right[0], y, z))

    faces = []
    for i in range(len(z_values) - 1):
        faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(wood)
    obj.modifiers.new("deck weighted normals", "WEIGHTED_NORMAL")
    bevel = obj.modifiers.new("soft shaped deck edge", "BEVEL")
    bevel.width = 0.018
    bevel.segments = 2

    for z in z_values[1:-1:2]:
        left = side_point(z, -1, t, -inset - 0.030)
        right = side_point(z, 1, t, -inset - 0.030)
        y = max(left[1], right[1]) + lift + 0.018
        add_cube(f"{name}_plank_separator_{z:.2f}", (0, y, z), (abs(right[0] - left[0]), 0.014, 0.018), dark, 0.002)

    return obj


def add_stern_stairs(side, materials):
    dark = materials["dark_wood"]
    gold = materials["gold"]
    # Broad readable treads climbing beside the quarterdeck without the previous flare.
    steps = [
        (0.58, 1.04, 0.74, 0.42),
        (0.60, 1.13, 0.92, 0.42),
        (0.62, 1.23, 1.10, 0.42),
        (0.62, 1.34, 1.28, 0.40),
        (0.60, 1.46, 1.46, 0.38),
        (0.58, 1.58, 1.64, 0.36),
        (0.56, 1.70, 1.80, 0.34),
    ]
    for i, (x_abs, y, z, width) in enumerate(steps):
        add_cube(f"stern_sweeping_stair_tread_{side}_{i}", (side * x_abs, y, z), (width, 0.062, 0.18), dark, 0.014)
        add_cube(f"stern_sweeping_stair_gold_nose_{side}_{i}", (side * x_abs, y + 0.043, z - 0.068), (width * 0.90, 0.016, 0.024), gold, 0.005)
        add_cube(f"stern_sweeping_stair_solid_riser_{side}_{i}", (side * x_abs, y - 0.070, z - 0.078), (width * 0.94, 0.115, 0.028), dark, 0.006)

    for rail_side, lateral in (("outer", 0.50), ("inner", -0.50)):
        verts = []
        faces = []
        for i, (x_abs, y, z, width) in enumerate(steps):
            x = side * (x_abs + width * lateral)
            verts.append((x, y + 0.010, z - 0.090))
            verts.append((x, y - 0.155, z - 0.090))
            if i:
                a = (i - 1) * 2
                b = i * 2
                faces.append((a, b, b + 1, a + 1))
        mesh = bpy.data.meshes.new(f"stern_stair_{rail_side}_solid_cheek_{side}Mesh")
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(f"stern_stair_{rail_side}_solid_cheek_{side}", mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(dark)
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
        bevel = obj.modifiers.new("soft bevel", "BEVEL")
        bevel.width = 0.010
        bevel.segments = 2

    # Broad side skirts hide the open side of the steps while leaving the
    # individual treads readable from elevated gameplay angles.
    for skirt_side, lateral, height in (("outer", 0.56, 0.28), ("inner", -0.56, 0.22)):
        verts = []
        faces = []
        for i, (x_abs, y, z, width) in enumerate(steps):
            x = side * (x_abs + width * lateral)
            verts.append((x, y + 0.018, z - 0.120))
            verts.append((x, y - height, z - 0.120))
            if i:
                a = (i - 1) * 2
                b = i * 2
                faces.append((a, b, b + 1, a + 1))
        mesh = bpy.data.meshes.new(f"stern_stair_{skirt_side}_architectural_skirt_{side}Mesh")
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(f"stern_stair_{skirt_side}_architectural_skirt_{side}", mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(dark)
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
        bevel = obj.modifiers.new("soft bevel", "BEVEL")
        bevel.width = 0.014
        bevel.segments = 2

    add_polyline(
        f"stern_stair_outer_gold_skirt_trim_{side}",
        [(side * (x_abs + width * 0.56), y + 0.030, z - 0.118) for x_abs, y, z, width in steps],
        0.007,
        gold,
    )

    add_polyline(
        f"stern_stair_curved_outer_wood_handrail_{side}",
        [(side * (x_abs + width * 0.50), y + 0.15, z) for x_abs, y, z, width in steps],
        0.026,
        dark,
    )
    add_polyline(
        f"stern_stair_curved_inner_wood_handrail_{side}",
        [(side * (x_abs - width * 0.48), y + 0.12, z) for x_abs, y, z, width in steps],
        0.022,
        dark,
    )
    add_polyline(
        f"stern_stair_gold_handrail_face_{side}",
        [(side * (x_abs + width * 0.50), y + 0.18, z) for x_abs, y, z, width in steps],
        0.007,
        gold,
    )
    add_cube(f"stern_stair_recessed_level_landing_{side}", (side * 0.52, 1.68, 1.98), (0.40, 0.070, 0.34), dark, 0.014)
    add_cube(f"stern_stair_landing_gold_nose_{side}", (side * 0.52, 1.725, 1.82), (0.36, 0.014, 0.030), gold, 0.004)
    add_cube(f"stern_stair_landing_inner_block_{side}", (side * 0.38, 1.64, 2.08), (0.12, 0.052, 0.16), dark, 0.010)


def add_stern_second_level_rail(materials):
    dark = materials["dark_wood"]
    gold = materials["gold"]
    for side in (-1, 1):
        post_points = [
            (side * 0.64, 1.66, 1.84),
            (side * 0.60, 1.66, 2.02),
            (side * 0.55, 1.66, 2.20),
            (side * 0.48, 1.66, 2.36),
        ]
        for i, (x, y, z) in enumerate(post_points):
            add_cylinder_between(f"stern_second_level_rail_post_{side}_{i}", (x, y, z), (x, y + 0.24, z), 0.020, dark, 10)
            add_ellipsoid(f"stern_second_level_rail_gold_cap_{side}_{i}", (x, y + 0.255, z), (0.018, 0.012, 0.018), gold, 10, 4)
        top = [(x, y + 0.24, z) for x, y, z in post_points]
        mid = [(x, y + 0.12, z) for x, y, z in post_points]
        add_polyline(f"stern_second_level_top_rail_{side}", top, 0.026, dark)
        add_polyline(f"stern_second_level_mid_rail_{side}", mid, 0.015, dark)


def add_stern_side_window(name, side, loc, size, materials):
    gold = materials["gold"]
    black = materials["black"]
    red = materials["red_paint"]
    x, y, z = loc
    add_cube(f"{name}_side_gold_frame", (x, y, z), (size[0], size[1] * 1.18, size[2] * 1.16), gold, 0.006)
    add_cube(f"{name}_side_red_reveal", (x + side * size[0] * 0.12, y, z), (size[0] * 1.18, size[1], size[2]), red, 0.006)
    add_cube(f"{name}_side_dark_glass", (x + side * size[0] * 0.30, y, z), (size[0] * 1.26, size[1] * 0.58, size[2] * 0.58), black, 0.004)


def add_stern_window_bay(name, center, width, height, materials):
    x, y, z = center
    gold = materials["gold"]
    dark = materials["dark_wood"]
    black = materials["black"]
    red = materials["red_paint"]
    add_cube(f"{name}_deep_recess", (x, y, z - 0.010), (width * 1.18, height * 1.15, 0.050), dark, 0.010)
    add_cube(f"{name}_painted_back", (x, y, z + 0.012), (width, height * 0.96, 0.034), red, 0.008)
    add_cube(f"{name}_glass", (x, y, z + 0.038), (width * 0.58, height * 0.58, 0.034), black, 0.006)
    add_cube(f"{name}_top_arch_lintel", (x, y + height * 0.42, z + 0.050), (width * 1.18, 0.026, 0.050), gold, 0.006)
    add_cube(f"{name}_bottom_sill", (x, y - height * 0.48, z + 0.050), (width * 1.14, 0.022, 0.048), gold, 0.005)
    add_cube(f"{name}_left_mullion", (x - width * 0.46, y, z + 0.052), (0.022, height * 1.02, 0.048), gold, 0.005)
    add_cube(f"{name}_right_mullion", (x + width * 0.46, y, z + 0.052), (0.022, height * 1.02, 0.048), gold, 0.005)
    add_ellipsoid(f"{name}_arched_crown", (x, y + height * 0.53, z + 0.052), (width * 0.54, 0.030, 0.030), gold, 14, 6)


def add_rect_stern_window(name, center, size, materials):
    x, y, z = center
    width, height = size
    gold = materials["gold"]
    dark = materials["dark_wood"]
    black = materials["black"]
    add_cube(f"{name}_deep_rect_recess", (x, y, z), (width * 1.18, height * 1.16, 0.050), dark, 0.004)
    add_cube(f"{name}_dark_rect_glass", (x, y, z + 0.032), (width * 0.72, height * 0.78, 0.040), black, 0.003)
    add_cube(f"{name}_top_rect_lintel", (x, y + height * 0.54, z + 0.050), (width * 1.18, 0.020, 0.050), gold, 0.004)
    add_cube(f"{name}_bottom_rect_sill", (x, y - height * 0.54, z + 0.050), (width * 1.12, 0.020, 0.050), gold, 0.004)
    add_cube(f"{name}_left_rect_jamb", (x - width * 0.54, y, z + 0.050), (0.018, height * 1.08, 0.050), gold, 0.004)
    add_cube(f"{name}_right_rect_jamb", (x + width * 0.54, y, z + 0.050), (0.018, height * 1.08, 0.050), gold, 0.004)


def add_stern_door(name, center, size, materials):
    x, y, z = center
    width, height = size
    dark = materials["dark_wood"]
    gold = materials["gold"]
    black = materials["black"]
    add_cube(f"{name}_dark_door_panel", (x, y, z), (width, height, 0.050), dark, 0.006)
    add_cube(f"{name}_shadow_gap", (x, y, z + 0.036), (width * 0.72, height * 0.74, 0.032), black, 0.004)
    add_cube(f"{name}_gold_header", (x, y + height * 0.54, z + 0.050), (width * 1.20, 0.024, 0.052), gold, 0.004)
    add_cube(f"{name}_gold_left_jamb", (x - width * 0.55, y, z + 0.050), (0.020, height * 1.08, 0.052), gold, 0.004)
    add_cube(f"{name}_gold_right_jamb", (x + width * 0.55, y, z + 0.050), (0.020, height * 1.08, 0.052), gold, 0.004)


def add_sterncastle_anchor(materials):
    dark = materials["dark_wood"]
    red = materials["red_paint"]
    gold = materials["gold"]
    black = materials["black"]
    add_tapered_box("Sterncastle_integrated_dark_plinth", (0, 1.04, 2.05), 1.04, 0.92, 0.20, 0.42, dark, 0.030)
    add_tapered_box("Sterncastle_lower_red_root_fairing", (0, 1.18, 2.06), 1.00, 0.88, 0.28, 0.38, red, 0.030)
    add_cube("Sterncastle_shadow_contact_band", (0, 0.94, 2.04), (1.08, 0.045, 0.48), black, 0.010)
    add_cube("Sterncastle_gold_contact_trim", (0, 1.33, 2.05), (0.96, 0.020, 0.42), gold, 0.005)
    for side in (-1, 1):
        add_cube(f"Sterncastle_side_deep_attachment_wall_{side}", (side * 0.48, 1.23, 2.04), (0.080, 0.44, 0.42), dark, 0.022)


def add_mast_stub(name, z, height, radius, materials):
    dark = materials["dark_wood"]
    gold = materials["gold"]
    black = materials["black"]
    _, deck_y, _ = side_point(z, 1, 0.985, -0.020)
    base_y = deck_y - 0.075
    top_y = deck_y + height
    add_cylinder_between(f"MastBase_{name}", (0, base_y, z), (0, top_y, z), radius, dark, 18)
    add_cube(f"MastPartner_dark_socket_{name}", (0, deck_y + 0.015, z), (radius * 3.4, 0.060, radius * 3.4), dark, 0.014)
    add_cube(f"MastPartner_shadow_recess_{name}", (0, deck_y + 0.052, z), (radius * 2.45, 0.020, radius * 2.45), black, 0.008)
    add_cylinder_between(f"MastPartner_gold_front_band_{name}", (-radius * 1.9, deck_y + 0.066, z - radius * 1.9), (radius * 1.9, deck_y + 0.066, z - radius * 1.9), 0.010, gold, 8)
    add_cylinder_between(f"MastPartner_gold_back_band_{name}", (-radius * 1.9, deck_y + 0.066, z + radius * 1.9), (radius * 1.9, deck_y + 0.066, z + radius * 1.9), 0.010, gold, 8)
    band_y = deck_y + min(0.32, height * 0.34)
    add_cylinder_between(f"gold_mast_band_{name}", (-radius * 1.42, band_y, z), (radius * 1.42, band_y, z), 0.014, gold, 10)


def station_profile():
    # z, half width, deck y, keel y. Forward is -Z, matching the Godot convention.
    return [
        (2.65, 0.58, 1.14, -0.46),
        (2.25, 0.76, 1.05, -0.56),
        (1.80, 0.90, 0.96, -0.66),
        (1.18, 0.98, 0.85, -0.74),
        (0.42, 0.98, 0.76, -0.80),
        (-0.42, 0.90, 0.73, -0.78),
        (-1.15, 0.76, 0.78, -0.67),
        (-1.72, 0.56, 0.88, -0.50),
        (-2.28, 0.30, 1.02, -0.25),
        (-2.88, 0.06, 1.15, -0.04),
    ]


def side_point(z, side, t, offset=0.0):
    stations = station_profile()
    lower = stations[0]
    upper = stations[-1]
    for i in range(len(stations) - 1):
        if stations[i][0] >= z >= stations[i + 1][0]:
            lower = stations[i]
            upper = stations[i + 1]
            break
    span = lower[0] - upper[0]
    f = 0 if span == 0 else (lower[0] - z) / span
    half_width = lower[1] + (upper[1] - lower[1]) * f
    deck_y = lower[2] + (upper[2] - lower[2]) * f
    keel_y = lower[3] + (upper[3] - lower[3]) * f
    y = keel_y + (deck_y - keel_y) * t
    beam = half_width * (math.sin(t * math.pi * 0.5) ** 0.58)
    tumblehome = 1.0 - max(0.0, t - 0.72) * 0.28
    return (side * (beam * tumblehome + offset), y, z)


def create_hull(materials):
    stations = station_profile()
    rows = 14
    verts = []
    index = {}
    for side in (-1, 1):
        for si, (z, half_width, deck_y, keel_y) in enumerate(stations):
            for row in range(rows + 1):
                t = row / rows
                y = keel_y + (deck_y - keel_y) * t
                beam = half_width * (math.sin(t * math.pi * 0.5) ** 0.66)
                tumblehome = 1.0 - max(0.0, t - 0.70) * 0.34
                sheer_softener = 1.0 - 0.05 * math.cos((z + 0.25) * math.pi)
                z_raked = z
                if si == len(stations) - 1:
                    z_raked = z + 0.50 * (1.0 - t) - 0.18 * t
                elif si == len(stations) - 2:
                    z_raked = z + 0.18 * (1.0 - t) - 0.06 * t
                index[(side, si, row)] = len(verts)
                verts.append((side * beam * tumblehome * sheer_softener, y, z_raked))

    faces = []
    mat_ids = []
    for side in (-1, 1):
        for si in range(len(stations) - 1):
            for row in range(rows):
                a = index[(side, si, row)]
                b = index[(side, si + 1, row)]
                c = index[(side, si + 1, row + 1)]
                d = index[(side, si, row + 1)]
                faces.append((a, b, c, d) if side == 1 else (d, c, b, a))
                mat_ids.append(0 if row < 5 else 1)

    # Close bottom, bow, and stern so the transparent render reads as a solid object.
    for si in range(len(stations) - 1):
        faces.append((index[(-1, si, 0)], index[(1, si, 0)], index[(1, si + 1, 0)], index[(-1, si + 1, 0)]))
        mat_ids.append(0)
    for row in range(rows):
        faces.append((index[(-1, 0, row)], index[(-1, 0, row + 1)], index[(1, 0, row + 1)], index[(1, 0, row)]))
        mat_ids.append(0)
        last = len(stations) - 1
        faces.append((index[(-1, last, row)], index[(1, last, row)], index[(1, last, row + 1)], index[(-1, last, row + 1)]))
        mat_ids.append(1)

    mesh = bpy.data.meshes.new("GalleonHullMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    hull = bpy.data.objects.new("Hull_curved_galleon_body", mesh)
    bpy.context.collection.objects.link(hull)
    hull.data.materials.append(materials["dark_wood"])
    hull.data.materials.append(materials["red_paint"])
    for poly, material_index in zip(hull.data.polygons, mat_ids):
        poly.material_index = material_index
    hull.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    bevel = hull.modifiers.new("broad soft bevel", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 4
    return hull


def decorate_hull(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    red = materials["red_paint"]
    gold = materials["gold"]
    black = materials["black"]

    # Horizontal planking and ornate gold strakes.
    for side in (-1, 1):
        for t in (0.16, 0.27, 0.38, 0.49, 0.60):
            pts = [side_point(z, side, t, 0.015) for z, *_ in station_profile()[1:-1]]
            add_polyline(f"wood_plank_line_{side}_{t:.2f}", pts, 0.009, dark)
        for t, radius in ((0.63, 0.012), (0.78, 0.010), (0.88, 0.015), (0.98, 0.012)):
            pts = [side_point(z, side, t, 0.025) for z, *_ in station_profile()[1:-1]]
            add_polyline(f"gold_hull_sheer_{side}_{t:.2f}", pts, radius, gold)

    # Deck insert, red gun band, and raised castles.
    deck_z = [2.34, 1.96, 1.58, 1.20, 0.82, 0.44, 0.06, -0.32, -0.70, -1.08, -1.46, -1.84, -2.22, -2.58]
    add_shaped_deck("Deck_shaped_to_hull_planks", deck_z, materials)
    add_cube("Deck_central_hatch_frame", (0, 1.105, 0.42), (0.46, 0.055, 0.34), dark, 0.018)
    add_cube("Deck_central_hatch_recess", (0, 1.138, 0.42), (0.34, 0.028, 0.24), materials["black"], 0.010)
    for x in [-0.13, 0.0, 0.13]:
        add_cube(f"Deck_hatch_slat_{x}", (x, 1.158, 0.42), (0.024, 0.020, 0.28), wood, 0.003)
    for side in (-1, 1):
        add_polyline(
            f"deck_edge_dark_cap_{side}",
            [(x, y + 0.055, z) for x, y, z in [side_point(z, side, 0.99, 0.004) for z in deck_z]],
            0.020,
            dark,
        )
        # Broad stepped side transitions imply access between main deck and quarterdeck,
        # without committing to tiny literal stairs at this early hull stage.
        for i, (z, y) in enumerate([(1.06, 1.12), (1.20, 1.19), (1.34, 1.26)]):
            add_cube(f"Quarterdeck_transition_step_{side}_{i}", (side * 0.57, y, z), (0.22, 0.035, 0.18), dark, 0.010)
        add_stern_stairs(side, materials)
    for side in (-1, 1):
        add_polyline(
            f"Bow_deck_closing_heavy_cheek_rail_{side}",
            [
                side_point(-1.54, side, 1.0, 0.030),
                side_point(-1.96, side, 1.0, 0.020),
                side_point(-2.40, side, 1.0, 0.008),
                (0.0, 1.28, -2.66),
            ],
            0.030,
            dark,
        )
    add_cylinder_between("Bow_front_cross_rail_meeting_point", (-0.11, 1.33, -2.57), (0.11, 1.33, -2.57), 0.024, dark, 12)

    # Sterncastle: wide raked gallery masses with a faceted curved transom.
    add_sterncastle_anchor(materials)
    add_cube("Sterncastle_front_deck_contact_wall", (0, 1.20, 1.66), (0.98, 0.42, 0.10), red, 0.020)
    add_cube("Sterncastle_front_dark_contact_foot", (0, 1.01, 1.62), (1.00, 0.055, 0.14), dark, 0.012)
    add_stern_gallery_tier(
        "Sterncastle_lower_curved_transom_gallery",
        1.12, 1.56, 1.72, 2.52,
        1.08, 1.22, 0.98, 1.10,
        red, 0.035,
    )
    add_cube("Sterncastle_lower_internal_floor_band", (0, 1.56, 2.14), (0.98, 0.060, 0.38), dark, 0.016)
    add_cube("Sterncastle_lower_gold_gallery_sill", (0, 1.16, 2.14), (0.88, 0.022, 0.36), gold, 0.006)
    add_cube("Sterncastle_second_level_recessed_walk", (0, 1.62, 2.10), (0.68, 0.052, 0.16), dark, 0.010)
    add_cube("Sterncastle_second_level_dark_support_fascia", (0, 1.58, 2.18), (0.82, 0.085, 0.36), dark, 0.012)
    for x in [-0.34, -0.12, 0.12, 0.34]:
        add_cylinder_between(f"Sterncastle_second_level_short_support_post_{x}", (x, 1.50, 2.26), (x, 1.66, 2.26), 0.018, dark, 10)
    add_stern_gallery_tier(
        "Sterncastle_middle_raked_window_gallery",
        1.56, 2.42, 2.16, 2.52,
        0.78, 1.02, 0.66, 0.86,
        red, 0.030,
    )
    add_stern_second_level_rail(materials)
    add_cube("Sterncastle_middle_internal_floor_band", (0, 2.03, 2.28), (0.66, 0.044, 0.26), dark, 0.010)
    add_cube("Sterncastle_middle_upper_walk_band", (0, 2.42, 2.28), (0.62, 0.052, 0.24), dark, 0.012)
    add_cube("Sterncastle_middle_gold_sill", (0, 1.65, 2.28), (0.62, 0.018, 0.22), gold, 0.005)
    add_cube("Sterncastle_upper_captain_gallery_flat_block", (0, 2.58, 2.43), (0.34, 0.24, 0.16), red, 0.026)
    add_cube("Sterncastle_upper_captain_gallery_front_face", (0, 2.43, 2.35), (0.30, 0.036, 0.018), red, 0.006)
    add_cube("Sterncastle_upper_internal_cap", (0, 2.72, 2.42), (0.34, 0.060, 0.18), dark, 0.010)
    add_cube("Sterncastle_roof_dark_wood", (0, 2.80, 2.42), (0.38, 0.076, 0.20), dark, 0.014)
    add_cube("Sterncastle_subtle_dark_pediment", (0, 2.91, 2.42), (0.24, 0.070, 0.08), dark, 0.010)
    add_cylinder_between("Sterncastle_top_ornamental_mast", (0, 2.78, 2.40), (0, 3.30, 2.40), 0.040, dark, 16)
    add_cylinder_between("Sterncastle_top_gold_mast_band", (-0.065, 3.02, 2.40), (0.065, 3.02, 2.40), 0.010, gold, 8)
    for y, width, depth, zc in [(1.22, 0.86, 0.30, 2.22), (1.74, 0.62, 0.20, 2.32), (2.42, 0.30, 0.12, 2.42)]:
        add_cube(f"stern_gallery_shadowed_undercut_{y}", (0, y, zc), (width, 0.045, depth), materials["black"], 0.012)

    # Gun ports with red lips and black interiors.
    lower_ports = [2.04, 1.68, 1.32, 0.96, 0.60, 0.24, -0.12, -0.48, -0.84, -1.20, -1.56, -1.92]
    upper_ports = [1.76, 1.30, 0.84, 0.38, -0.08, -0.54, -1.00, -1.46]
    for side in (-1, 1):
        for i, z in enumerate(lower_ports):
            add_side_gunport(f"lower_gundeck_port_{side}_{i}", side, z, 0.43, materials, size=0.178, offset=0.060)
        for i, z in enumerate(upper_ports):
            add_side_gunport(f"upper_gundeck_port_{side}_{i}", side, z, 0.66, materials, size=0.168, offset=0.058)
            x, y, _ = side_point(z, side, 0.72, 0.020)
            add_cylinder_between(f"upper_deck_cannon_{side}_{i}", (x - side * 0.045, y, z), (x + side * 0.075, y - 0.006, z), 0.021, black, 12)

    # Stern windows and structural columns: tall rectangles so they do not read as gunports.
    for col, x in enumerate([-0.22, 0.0, 0.22]):
        add_rect_stern_window(f"stern_bow_face_second_level_window_{col}", (x, 1.96, 2.105), (0.075, 0.18), materials)
    add_cube("stern_bow_face_second_level_dark_lintel", (0, 2.11, 2.105), (0.62, 0.030, 0.050), dark, 0.006)
    add_cube("stern_bow_face_second_level_gold_sill", (0, 1.77, 2.105), (0.54, 0.020, 0.052), gold, 0.004)
    for row, (y, xs, height) in enumerate([
        (1.34, [-0.32, -0.16, 0.0, 0.16, 0.32], 0.18),
        (1.86, [-0.24, -0.08, 0.08, 0.24], 0.20),
        (2.18, [-0.22, -0.07, 0.07, 0.22], 0.20),
    ]):
        for col, x in enumerate(xs):
            add_rect_stern_window(f"stern_rect_window_{row}_{col}", (x, y, 2.50), (0.080, height), materials)
    add_stern_door("stern_middle_gallery_door", (0.0, 1.62, 2.505), (0.13, 0.30), materials)
    add_stern_door("stern_upper_gallery_door", (0.0, 2.00, 2.505), (0.12, 0.28), materials)
    for x in [-0.48, -0.30, -0.10, 0.10, 0.30, 0.48]:
        add_cylinder_between(f"stern_heavy_dark_gallery_column_{x}", (x, 1.12, 2.47), (x * 0.72, 2.42, 2.52), 0.020, dark, 12)
        add_cylinder_between(f"stern_thin_gold_column_face_{x}", (x, 1.13, 2.51), (x * 0.72, 2.42, 2.56), 0.006, gold, 8)
    for y, width in [(1.18, 1.14), (1.56, 1.10), (2.02, 0.90), (2.42, 0.72)]:
        add_cube(f"stern_horizontal_dark_gallery_beam_{y}", (0, y, 2.52), (width, 0.030, 0.050), dark, 0.007)
        add_cube(f"stern_horizontal_gold_gallery_face_{y}", (0, y + 0.020, 2.56), (width * 0.94, 0.010, 0.022), gold, 0.003)

    # Rail posts, lantern hints, and three mast stumps for presentation.
    for side in (-1, 1):
        rail_z = [2.20, 1.78, 1.36, 0.94, 0.52, 0.10, -0.32, -0.74, -1.16, -1.58, -2.00, -2.34, -2.58]
        for z in rail_z:
            x, y, _ = side_point(z, side, 1.0, 0.04)
            add_cylinder_between(f"rail_post_{side}_{z}", (x, y, z), (x, y + 0.25, z), 0.026, dark, 10)
            add_ellipsoid(f"rail_post_gold_cap_{side}_{z}", (x, y + 0.268, z), (0.024, 0.016, 0.024), gold, 10, 4)
        rail_pts = [side_point(z, side, 1.0, 0.04) for z in rail_z]
        rail_pts = [(x, y + 0.27, z) for x, y, z in rail_pts]
        add_polyline(f"top_rail_{side}", rail_pts, 0.034, dark)
        mid_rail = [(x, y + 0.13, z) for x, y, z in rail_pts]
        add_polyline(f"mid_rail_{side}", mid_rail, 0.018, dark)
        add_cylinder_between(
            f"sterncastle_main_deck_top_rail_return_{side}",
            rail_pts[0],
            (side * 0.49, 1.47, 2.08),
            0.030,
            dark,
            10,
        )
        add_cylinder_between(
            f"sterncastle_main_deck_mid_rail_return_{side}",
            mid_rail[0],
            (side * 0.49, 1.34, 2.08),
            0.018,
            dark,
            10,
        )
        add_cylinder_between(
            f"sterncastle_rail_terminal_post_{side}",
            (side * 0.49, 1.18, 2.08),
            (side * 0.49, 1.50, 2.08),
            0.026,
            dark,
            10,
        )

    for name, z, height, radius in [("fore", -1.08, 1.0, 0.07), ("main", -0.05, 1.28, 0.085), ("mizzen", 1.05, 0.9, 0.06)]:
        add_mast_stub(name, z, height, radius, materials)

    # Bowsprit, beakhead structure, and simple figurehead silhouette.
    add_cylinder_between("Bowsprit_dark_wood", (0, 1.28, -2.46), (0, 2.06, -3.30), 0.055, dark, 16)
    add_cylinder_between("Bowsprit_gold_tip", (0, 2.06, -3.30), (0, 2.18, -3.48), 0.04, gold, 16)
    add_polyline("Bow_swept_gold_stem", [(0, -0.05, -2.20), (0, 0.36, -2.42), (0, 0.86, -2.62), (0, 1.24, -2.76)], 0.030, gold)
    add_polyline("Bow_upper_gold_scroll_rail", [(0.0, 1.04, -2.26), (0.0, 1.15, -2.46), (0.0, 1.22, -2.66)], 0.012, gold)
    for side in (-1, 1):
        add_polyline(
            f"Bow_beakhead_side_sweep_{side}",
            [
                side_point(-1.50, side, 0.75, 0.026),
                (side * 0.20, 1.02, -2.18),
                (side * 0.08, 1.15, -2.56),
            ],
            0.014,
            dark,
        )
        add_cylinder_between(
            f"Bow_beakhead_short_rail_post_{side}",
            (side * 0.18, 0.98, -2.36),
            (side * 0.18, 1.13, -2.36),
            0.012,
            dark,
            10,
        )
        add_cylinder_between(
            f"Bow_bowsprit_knee_{side}",
            (side * 0.16, 1.08, -2.26),
            (side * 0.04, 1.42, -2.68),
            0.018,
            dark,
            10,
        )
        add_cylinder_between(
            f"Bow_beakhead_lower_knee_{side}",
            (side * 0.16, 0.74, -2.30),
            (side * 0.04, 1.00, -2.70),
            0.016,
            dark,
            10,
        )
    add_ellipsoid("Figurehead_carved_gold_body", (0, 0.86, -2.86), (0.075, 0.18, 0.055), gold, 16, 8)
    add_ellipsoid("Figurehead_carved_gold_chest", (0, 1.00, -2.96), (0.085, 0.13, 0.060), gold, 16, 8)
    add_ellipsoid("Figurehead_carved_gold_head", (0, 1.12, -3.06), (0.060, 0.060, 0.075), gold, 12, 6)
    add_cylinder_between("Figurehead_gold_neck_spine", (0, 0.78, -2.78), (0, 1.10, -3.04), 0.018, gold, 10)
    for side in (-1, 1):
        add_cylinder_between(f"Figurehead_gold_foreleg_{side}", (side * 0.035, 0.94, -2.94), (side * 0.070, 0.74, -2.78), 0.012, gold, 8)
        add_cylinder_between(f"Figurehead_gold_mane_sweep_{side}", (side * 0.045, 1.10, -3.00), (side * 0.085, 0.98, -2.88), 0.010, gold, 8)
    add_cube("Figurehead_dark_mounting_bracket", (0, 0.72, -2.70), (0.12, 0.060, 0.14), dark, 0.012)

    # Gold rivets and rosettes: small enough to be charming, big enough to read.
    for side in (-1, 1):
        for z in [1.5, 1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
            for t in [0.34, 0.60, 0.86]:
                x, y, _ = side_point(z, side, t, 0.055)
                bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=4, radius=0.028, location=(x, y, z))
                rivet = bpy.context.object
                rivet.name = f"gold_rivet_{side}_{z}_{t}"
                rivet.scale.x = 0.55
                rivet.data.materials.append(gold)
        for z in [1.72, 1.18, 0.64, 0.10, -0.44, -0.98, -1.48]:
            x, y, _ = side_point(z, side, 0.66, 0.058)
            add_cube(f"painted_hull_panel_divider_{side}_{z}", (x, y, z), (0.034, 0.30, 0.028), gold, 0.006)


def add_lighting_and_camera():
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 128
    bpy.context.scene.render.film_transparent = False
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.context.scene.view_settings.look = "Medium High Contrast"
    bpy.context.scene.view_settings.exposure = 0.25
    bpy.context.scene.view_settings.gamma = 1.0
    bpy.context.scene.world.color = (0.58, 0.55, 0.50)
    bpy.context.scene.render.resolution_x = 2800
    bpy.context.scene.render.resolution_y = 1700

    bpy.ops.object.light_add(type="AREA", location=(-4.8, 6.2, -5.6))
    key = bpy.context.object
    key.name = "Large warm soft key light"
    key.data.energy = 3600
    key.data.size = 7.5
    key.data.color = (1.0, 0.82, 0.60)
    bpy.ops.object.light_add(type="AREA", location=(5.2, 4.0, 4.4))
    fill = bpy.context.object
    fill.name = "Broad neutral fill light"
    fill.data.energy = 2100
    fill.data.size = 9.0
    fill.data.color = (0.82, 0.88, 1.0)
    bpy.ops.object.light_add(type="AREA", location=(-2.2, 3.7, 4.8))
    top = bpy.context.object
    top.name = "Soft overhead reveal light"
    top.data.energy = 900
    top.data.size = 6.0
    top.data.color = (1.0, 0.92, 0.78)
    bpy.ops.object.light_add(type="POINT", location=(3.0, 2.8, 2.8))
    rim = bpy.context.object
    rim.name = "Small gold rim light"
    rim.data.energy = 380
    rim.data.color = (1.0, 0.76, 0.42)

    bpy.ops.object.camera_add(location=(-8.2, 1.52, -0.45))
    camera = bpy.context.object
    camera.name = "Camera_primary_centered_hull_review"
    look_at(camera, (0, 0.92, -0.45))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 9.05
    bpy.context.scene.camera = camera

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0.55, 0))
    bpy.context.object.name = "Origin_waterline_center_reference"
    return camera


def render_to(path, camera_location, target, ortho_scale, roll_degrees=0.0):
    camera = bpy.context.scene.camera
    camera.location = camera_location
    look_at(camera, target)
    if roll_degrees:
        camera.rotation_euler.rotate_axis("Z", math.radians(roll_degrees))
    camera.data.ortho_scale = ortho_scale
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def render_clay(path):
    clay = mat("inspection warm clay", (0.62, 0.58, 0.52, 1), 0.72)
    dark_clay = mat("inspection dark recess", (0.20, 0.18, 0.16, 1), 0.85)
    for obj in bpy.context.scene.objects:
        if hasattr(obj.data, "materials"):
            obj.data.materials.clear()
            obj.data.materials.append(dark_clay if "black" in obj.name.lower() or "recess" in obj.name.lower() else clay)
    render_to(path, (-8.2, 1.52, -0.42), (0, 1.05, -0.42), 10.60, 90.0)


def write_reference_notes():
    text = """# Blender First Hull Reference Notes

Generated from scratch in Blender. The rough scale source is the current Godot
`galleon_basic` visual profile:

- hull length 4.35
- hull width 1.72
- hull height 0.76
- bow length 1.08
- stern height 0.55
- forward axis -Z, origin at waterline center

The user-supplied galleon concept image was used for visual direction: warm dark
wood grain, burgundy painted bands, brighter gold trim, ornate raised stern,
curved bow, gun ports, and a strong side silhouette.

2026-08-14 refinement pass:

- brighter warm studio lighting on a neutral medium-light background
- procedural wood grain and subtle bump on hull/deck materials
- smoother hull station profile and softer bevels
- more consistent gunport spacing and framing
- denser rail posts, mid-rails, and clearer gold strakes
- extra stern gallery bars, columns, and lantern hints
- bow correction: raked forward station, shortened forecastle block, and curved
  gold prow rails/stem so the side silhouette no longer reads square

2026-08-14 refinement pass 2:

- sterncastle rebuilt as stepped tapered galleries with larger readable window
  groups, gold columns, side buttresses, crown bar, pediment, and finials
- bow/beakhead integration improved with side sweep rails, lower keel transition,
  bowsprit knees, and a stronger figurehead accent
- hull flow improved with extra painted panel dividers and clearer trim rhythm
- materials kept stylized but separated further: grainy wood, satin paint, and
  brighter aged gold
- added elevated orthographic gameplay-camera render

2026-08-14 refinement pass 3:

- reduced toy-like surface response: darker satin paint, rougher aged gold, and
  more restrained trim thickness
- removed awkward bow protrusions: dark lower bow sweep and extra forward gold nub
- simplified beakhead rails so each protrusion reads as support or stem detail
- added modest central hatch structure and deck slats
- toned down oversized stern crown/finials and reduced rail/post thickness
- added clay inspection render for checking form without material distraction

2026-08-14 refinement pass 4:

- replaced the sterncastle's core box/taper stack with faceted raked gallery
  meshes whose aft faces widen, rake, and curve subtly across the transom
- moved stern windows and columns onto the new transom face instead of floating
  on a flat rectangular back
- reduced stern crown/lantern scale again so the shaped gallery mass carries
  the silhouette instead of decorative primitives

2026-08-14 reference architecture pass:

- prioritized architecture over ornament based on `original.png`
- added quarterdeck/forecastle transition steps to clarify deck-level logic
- added restrained upper gun-deck ports as lintel/sill/reveal structures
- replaced the bow orb with a small carved figurehead assembly and bracket
- added broader framed stern transom panels behind the window/framing layer
- kept ornament limited to framing/bands that explain windows, decks, and hull

2026-08-14 structure-first cleanup pass:

- converted railings from gold tube/icing style to dark structural posts and
  rails with small gold post caps
- added deck edge cap rails, quarterdeck/forecastle transition steps, and
  sweeping stern stair treads to improve top-down deck logic
- rebuilt lower gunports as recessed wood/reveal/lintel/sill assemblies
- standardized upper-deck cannon scale and upper gun-deck port spacing
- kept bow figurehead as carved assembly and added a bow close-up render

2026-08-14 structure correction pass:

- simplified shiny bow/beakhead rods into darker structural knees and shorter
  rails so forward protrusions read as support instead of stray ornament
- strengthened stern side buttresses with dark wood cores and narrow gold caps
- added side-facing stern gallery windows to make the sterncastle read as
  layered ship architecture from side and gameplay angles

2026-08-15 deck and gun-deck correction pass:

- lengthened the hull station profile enough to support the requested gun count
- replaced the rectangular deck block with a shaped deck mesh sampled from the
  hull outline, closing the large top-down gaps along both sides
- updated the side rail/deck-edge paths to follow the longer hull
- standardized two gun decks per side: 12 lower ports and 8 upper ports, with
  the upper ports/cannons now using a consistent readable size
- enlarged the sterncastle stairs into broader curved side runs that sweep
  outward and back inward instead of tiny straight blocks

2026-08-15 sterncastle architecture pass:

- preserved the long hull, shaped deck, broadside count, and overall layout
- removed the forward blocky forecastle structure so the bow deck and rails
  close into the stem instead of a square cabin
- moved the figurehead forward and outside the hull silhouette
- shifted the bowsprit and beakhead supports back onto the actual bow stem
- rebuilt the sterncastle emphasis around wider tiered galleries, deeper window
  bays, heavier columns, balcony undercuts, and larger sweeping stairs
- made railings heavier and more wood-like with thicker dark rails/posts and
  smaller gold caps
- recessed visible upper cannons so they no longer appear pasted onto the side
- increased painted-red wood variation through stronger procedural surface grain

2026-08-15 mast and stern shelf structural pass:

- anchored the mast stumps into the shaped deck with dark mast-partner sockets,
  shadow recesses, and small gold bands so they no longer float above the deck
- tightened sterncastle balcony shelves, sills, roof, and shadow undercuts so
  each deck layer stays inside its gallery tier instead of leaking past it

2026-08-15 sterncastle architecture reset pass:

- focused only on sterncastle structure
- reduced visible floor/deck leakage by replacing oversized shelves with
  internal floor bands and smaller contained walk bands
- shifted the sterncastle footprint into a more upright, centered relationship
  with the main deck
- rebuilt the second level as a taller recessed gallery with two rows of
  rectangular windows plus door openings
- reduced the top level to a smaller ornamental tier with a mast stub
- changed stern windows from square gunport-like bays to taller rectangular
  openings
- enlarged the grand side stairs with solid treads and heavier handrails that
  flare outward then return inward

2026-08-15 sterncastle alignment pass:

- removed the stair flare after it read poorly in the gameplay views
- reduced gallery mesh aft rake so stern corners stop looking angled off the
  hull
- moved lower, middle, and top sterncastle tiers back against a shared stern
  line instead of stacking forward like a step pyramid
- made the second level much more deeply recessed by moving its front face aft
- added a bow-side contact wall and foot so the castle visibly meets the main
  deck
- replaced the top-level mast helper with a mast mounted directly on the
  ornamental top tier

2026-08-15 sterncastle corner artifact fix:

- fixed inconsistent face normals in the tapered-box and stern gallery tier
  meshes; inverted faces made the bevel modifier flare the tier rims outward
  into curled corner spikes, most visible on the starboard sterncastle corners
- moderated gallery tier bevel widths (0.070/0.060 -> 0.035/0.030) so tier
  rims read as crisp cornice lines instead of rolled lips
"""
    (OUT_DIR / "reference_notes.md").write_text(text, encoding="utf-8")


def build_materials():
    return {
        "dark_wood": wood_mat("dark aged walnut with grain", (0.16, 0.095, 0.048, 1), (0.36, 0.20, 0.085, 1), (0.055, 0.032, 0.018, 1)),
        "wood": wood_mat("warm deck wood with grain", (0.45, 0.285, 0.13, 1), (0.64, 0.40, 0.18, 1), (0.15, 0.075, 0.032, 1)),
        "red_paint": paint_mat("deep burgundy satin paint", (0.40, 0.040, 0.032, 1), (0.54, 0.075, 0.055, 1), (0.22, 0.018, 0.016, 1)),
        "gold": gold_mat("bright aged gold trim"),
        "black": mat("visible warm shadow black", (0.035, 0.027, 0.020, 1), 0.82),
    }


def main():
    clear_scene()
    materials = build_materials()
    create_hull(materials)
    decorate_hull(materials)
    add_lighting_and_camera()

    blend_path = OUT_DIR / "first_pass_galleon_hull.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    render_to(OUT_DIR / "galleon_hull_refined_primary.png", (-8.2, 1.52, -0.42), (0, 1.05, -0.42), 10.60, 90.0)
    render_to(OUT_DIR / "galleon_hull_refined_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.88, -0.12), 10.75, 90.0)
    render_to(OUT_DIR / "galleon_hull_refined_stern_angle.png", (-6.1, 3.35, 6.2), (0, 1.05, 0.72), 8.1)

    render_to(OUT_DIR / "galleon_hull_refined_bow_readability_angle.png", (6.3, 3.45, -6.4), (0, 0.98, -0.72), 8.0)
    render_to(OUT_DIR / "galleon_hull_refined_bow_close.png", (4.5, 2.20, -5.0), (0, 0.98, -2.34), 3.8)
    render_clay(OUT_DIR / "galleon_hull_refined_clay_inspection.png")
    write_reference_notes()


if __name__ == "__main__":
    main()
