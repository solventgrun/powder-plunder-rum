"""Station-profile hull mathematics and hull-bound builders.

A HullForm owns a ship's station list (z, half width, deck y, keel y — forward
is -Z, matching the Godot convention) plus the shaping constants. Defaults are
the galleon house values; ships override per class.

Two related but deliberately distinct surface models are preserved from the
galleon pilot:
- side_point: the coarser decor-placement helper (its own beam exponent and
  tumblehome, no sheer softener or stern rake),
- skin_vertex/mesh_point/surface_frame: the exact create_hull skin, including
  the per-station sheer softener and raked stern stations, interpolated the
  same way the mesh faces are.
"""
import math

import bpy
from mathutils import Vector

from .primitives import add_cube, add_surface_cube


class HullForm:
    def __init__(
        self,
        stations,
        beam_exponent_decor=0.58,
        tumblehome_start_decor=0.72,
        tumblehome_amount_decor=0.28,
        beam_exponent_skin=0.66,
        tumblehome_start_skin=0.70,
        tumblehome_amount_skin=0.34,
        sheer_amplitude=0.05,
        sheer_phase=0.25,
        stern_rake_last=(0.50, 0.18),
        stern_rake_previous=(0.18, 0.06),
    ):
        self.stations = list(stations)
        self.beam_exponent_decor = beam_exponent_decor
        self.tumblehome_start_decor = tumblehome_start_decor
        self.tumblehome_amount_decor = tumblehome_amount_decor
        self.beam_exponent_skin = beam_exponent_skin
        self.tumblehome_start_skin = tumblehome_start_skin
        self.tumblehome_amount_skin = tumblehome_amount_skin
        self.sheer_amplitude = sheer_amplitude
        self.sheer_phase = sheer_phase
        self.stern_rake_last = stern_rake_last
        self.stern_rake_previous = stern_rake_previous

    def side_point(self, z, side, t, offset=0.0):
        stations = self.stations
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
        beam = half_width * (math.sin(t * math.pi * 0.5) ** self.beam_exponent_decor)
        tumblehome = 1.0 - max(0.0, t - self.tumblehome_start_decor) * self.tumblehome_amount_decor
        return (side * (beam * tumblehome + offset), y, z)

    def skin_vertex(self, station_index, t, side):
        stations = self.stations
        sz, half_width, deck_y, keel_y = stations[station_index]
        y = keel_y + (deck_y - keel_y) * t
        beam = half_width * (math.sin(t * math.pi * 0.5) ** self.beam_exponent_skin)
        tumblehome = 1.0 - max(0.0, t - self.tumblehome_start_skin) * self.tumblehome_amount_skin
        softener = 1.0 - self.sheer_amplitude * math.cos((sz + self.sheer_phase) * math.pi)
        z_raked = sz
        if station_index == len(stations) - 1:
            z_raked = sz + self.stern_rake_last[0] * (1.0 - t) - self.stern_rake_last[1] * t
        elif station_index == len(stations) - 2:
            z_raked = sz + self.stern_rake_previous[0] * (1.0 - t) - self.stern_rake_previous[1] * t
        return Vector((side * beam * tumblehome * softener, y, z_raked))

    def mesh_point(self, z, side, t):
        stations = self.stations
        lo, hi = 0, len(stations) - 1
        for i in range(len(stations) - 1):
            if stations[i][0] >= z >= stations[i + 1][0]:
                lo, hi = i, i + 1
                break
        a = self.skin_vertex(lo, t, side)
        b = self.skin_vertex(hi, t, side)
        span = a.z - b.z
        f = 0.0 if span == 0 else (a.z - z) / span
        return a + (b - a) * min(max(f, 0.0), 1.0)

    def surface_frame(self, z, side, t):
        # Local frame on the hull skin: origin on the surface, e_x the outboard
        # surface normal, e_y up along the skin, e_z along the hull run.
        p0 = self.mesh_point(z, side, t)
        dz = self.mesh_point(z + 0.05, side, t) - self.mesh_point(z - 0.05, side, t)
        t_lo = max(t - 0.05, 0.02)
        t_hi = min(t + 0.05, 0.995)
        dt = self.mesh_point(z, side, t_hi) - self.mesh_point(z, side, t_lo)
        normal = dz.cross(dt)
        if normal.x * side < 0:
            normal = -normal
        e_x = normal.normalized()
        e_y = (dt - dt.project(e_x)).normalized()
        e_z = e_x.cross(e_y)
        return p0 + e_x * 0.003, e_x, e_y, e_z


def create_hull(
    form,
    materials,
    mesh_name,
    object_name,
    rows=14,
    base_material="dark_wood",
    paint_material="red_paint",
    paint_from_row=5,
    paint_to_row=None,
    bevel_width=0.035,
    bevel_segments=4,
):
    # paint_to_row bounds the painted zone from above (exclusive), so a ship
    # can wear a paint band with base wood returning on the bulwark. None keeps
    # the galleon behavior: painted from paint_from_row to the sheer.
    stations = form.stations
    verts = []
    index = {}
    for side in (-1, 1):
        for si in range(len(stations)):
            for row in range(rows + 1):
                t = row / rows
                index[(side, si, row)] = len(verts)
                verts.append(tuple(form.skin_vertex(si, t, side)))

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
                paint_end = rows if paint_to_row is None else paint_to_row
                mat_ids.append(1 if paint_from_row <= row < paint_end else 0)

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

    mesh = bpy.data.meshes.new(mesh_name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    hull = bpy.data.objects.new(object_name, mesh)
    bpy.context.collection.objects.link(hull)
    hull.data.materials.append(materials[base_material])
    hull.data.materials.append(materials[paint_material])
    for poly, material_index in zip(hull.data.polygons, mat_ids):
        poly.material_index = material_index
    hull.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    bevel = hull.modifiers.new("broad soft bevel", "BEVEL")
    bevel.width = bevel_width
    bevel.segments = bevel_segments
    return hull


def add_hull_side_box(form, name, side, z, t, size, material, offset=0.055, bevel=0.0):
    x, y, _ = form.side_point(z, side, t, offset)
    return add_cube(name, (x, y, z), size, material, bevel)


def add_side_gunport(form, name, side, z, t, materials, size=0.16):
    gold = materials["gold"]
    red = materials["red_paint"]
    black = materials["black"]
    dark = materials["dark_wood"]
    # The whole assembly is oriented to the local hull skin and hugs it, so the
    # port reads as recessed into the planking instead of pasted proud of it:
    # a dark cut ring at the surface, a thin wood architrave just proud of the
    # ring, then reveal/port faces stacked barely above that.
    frame = form.surface_frame(z, side, t)
    add_surface_cube(f"{name}_shadow_cut_ring", frame, (0.000, 0.0, 0.0), (0.020, size * 1.42, size * 1.52), black, 0.003)
    add_surface_cube(f"{name}_wood_recess", frame, (0.005, 0.0, 0.0), (0.030, size * 1.14, size * 1.26), dark, 0.006)
    add_surface_cube(f"{name}_structural_lintel", frame, (0.016, size * 0.62, 0.0), (0.020, 0.024, size * 1.34), gold, 0.004)
    add_surface_cube(f"{name}_structural_sill", frame, (0.016, -size * 0.62, 0.0), (0.020, 0.024, size * 1.34), gold, 0.004)
    add_surface_cube(f"{name}_red_reveal", frame, (0.013, 0.0, 0.0), (0.022, size * 0.82, size * 0.90), red, 0.006)
    add_surface_cube(f"{name}_dark_port", frame, (0.021, 0.0, 0.0), (0.016, size * 0.46, size * 0.54), black, 0.003)


def add_shaped_deck(form, name, z_values, materials, t=0.985, inset=0.020, lift=0.050):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    verts = []
    for z in z_values:
        left = form.side_point(z, -1, t, -inset)
        right = form.side_point(z, 1, t, -inset)
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
        left = form.side_point(z, -1, t, -inset - 0.030)
        right = form.side_point(z, 1, t, -inset - 0.030)
        y = max(left[1], right[1]) + lift + 0.018
        add_cube(f"{name}_plank_separator_{z:.2f}", (0, y, z), (abs(right[0] - left[0]), 0.014, 0.018), dark, 0.002)

    return obj
