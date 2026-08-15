"""Sail sheets, streamers, and anchor empties."""
import math

import bpy
from mathutils import Vector

from .primitives import recalc_outward_normals


def add_sail(name, point_fn, material, nx=13, ny=11):
    # Deformable sail sheet: an even nx x ny quad grid (future wind/damage
    # deformation needs this topology), smooth-shaded, with a thin solidify so
    # both faces light correctly in Cycles and in Godot after export.
    verts = []
    faces = []
    for r in range(ny + 1):
        v = r / ny
        for c in range(nx + 1):
            u = c / nx
            verts.append(point_fn(u, v))
    for r in range(ny):
        for c in range(nx):
            a = r * (nx + 1) + c
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    recalc_outward_normals(mesh)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    solid = obj.modifiers.new("canvas thickness", "SOLIDIFY")
    solid.thickness = 0.014
    solid.offset = 0.0
    return obj


def add_square_sail(name, material, z_mast, yard_y, foot_y, width_head, width_foot, depth, foot_arc):
    # Head hangs just below its yard, sheet just forward of the mast. The
    # billow peaks around 70% down the sail (foot keeps ~77% of it, head is
    # bent flat to the yard), and the foot edge arcs up between the clews.
    z_plane = z_mast - 0.045
    head_y = yard_y - 0.015

    def fn(u, v):
        width = width_head + (width_foot - width_head) * v
        x = (u - 0.5) * width
        y = head_y + (foot_y - head_y) * v + foot_arc * math.sin(math.pi * u) * (v ** 2)
        billow = depth * math.sin(math.pi * u) * math.sin(math.pi * v * 0.72)
        return (x, y, z_plane - billow)

    return add_sail(name, fn, material)


def add_streamer(name, root, length, height, material, nx=16, ny=2):
    # Thin tapering ribbon with a baked aft-flying S-curl.
    root_v = Vector(root)

    def fn(u, v):
        z = root_v.z + u * length
        y = root_v.y - u * length * 0.16 + 0.055 * math.sin(math.pi * 2.1 * u) * u + (v - 0.5) * height * (1.0 - 0.55 * u)
        x = root_v.x + 0.05 * math.sin(math.pi * 2.6 * u + 0.8) * u
        return (x, y, z)

    return add_sail(name, fn, material, nx=nx, ny=ny)


def add_anchor_empty(name, loc, display_size=0.06):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = display_size
    empty.location = loc
    bpy.context.collection.objects.link(empty)
    return empty
