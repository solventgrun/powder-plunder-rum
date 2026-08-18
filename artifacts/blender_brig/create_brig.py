"""Brig visual asset generator (third ship through the pipeline).

Ship-agnostic machinery lives in artifacts/ship_kit; this file owns only the
brig: its station profile, hull decoration, half-deck/transom, sail plan
(square foremast + gaff mainsail — the fleet's first fore-aft main), rigging
routes, streamers/anchors, classification rules, and review renders.

Class character (docs/design/brig-visual-brief.md): the raider — the knife.
Two-mast rig, knife-flat sheer, low half-deck aft, small plain transom, one
short gun row. Color per the brief + user concept sheet: tarred warm-brown
hull, buff/sand band carrying the ports, muted navy bulwark accent,
blackened-iron fittings (the kit's "gold" material slot renders as iron here),
brass only on the stem cap and ensign truck.

Env knobs for iteration:
  BRIG_STAGE   hull | full   (default full)
  BRIG_QUALITY draft | final (default final)
  BRIG_KIT     base | dutch (default base)
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ship_kit import (
    HullForm,
    add_cube,
    add_cylinder_between,
    add_ellipsoid,
    add_jib,
    add_mast_assembly,
    add_polyline,
    add_rope_bundle,
    add_sail,
    add_shaped_deck,
    add_side_gunport,
    add_spar,
    add_square_sail,
    add_streamer,
    add_tapered_box,
    classify_common,
    clear_scene,
    gold_mat,
    mat,
    organize_assemblies_from,
    paint_mat,
    recalc_outward_normals,
    render_clay,
    render_to,
    rope_points,
    setup_review_scene,
    wood_mat,
)
from ship_kit import add_anchor_empty
from ship_kit import create_hull as kit_create_hull

OUT_DIR = Path(__file__).resolve().parent

STAGE = os.environ.get("BRIG_STAGE", "full")
QUALITY = os.environ.get("BRIG_QUALITY", "final")
FACTION_KIT = os.environ.get("BRIG_KIT", "base")


def station_profile():
    # z, half width, deck y, keel y. Forward is -Z, matching the Godot convention.
    # The smallest hull in the fleet and the flattest: mid deck 0.535 vs the
    # frigate's 0.61, with barely 0.07/0.10 of rise at the ends — the knife
    # silhouette is a near-level line from transom to stem.
    return [
        (2.05, 0.42, 0.600, -0.28),
        (1.70, 0.56, 0.585, -0.38),
        (1.30, 0.67, 0.565, -0.46),
        (0.85, 0.74, 0.550, -0.52),
        (0.30, 0.77, 0.535, -0.56),
        (-0.35, 0.745, 0.530, -0.55),
        (-0.90, 0.66, 0.540, -0.50),
        (-1.40, 0.50, 0.555, -0.41),
        (-1.85, 0.28, 0.585, -0.21),
        (-2.25, 0.05, 0.635, -0.02),
    ]


# Flatter sheer and a shallower bow rake than even the frigate: nothing about
# this hull casts up. Bow tip lands at z ~-2.35 per the brief.
FORM = HullForm(
    station_profile(),
    sheer_amplitude=0.022,
    stern_rake_last=(0.28, 0.10),
    stern_rake_previous=(0.10, 0.03),
)

# Low aft half-deck: half the frigate's quarterdeck step (about +0.10 over the
# main deck surface instead of +0.25).
HDECK_Z = [1.05, 1.24, 1.43, 1.62, 1.81, 2.02]
HDECK_Y_FWD = 0.710
HDECK_Y_AFT = 0.730


def hdeck_y(z):
    f = (z - HDECK_Z[0]) / (HDECK_Z[-1] - HDECK_Z[0])
    return HDECK_Y_FWD + (HDECK_Y_AFT - HDECK_Y_FWD) * f


def side_point(z, side, t, offset=0.0):
    return FORM.side_point(z, side, t, offset)


def hull_surface_frame(z, side, t):
    return FORM.surface_frame(z, side, t)


def create_hull(materials):
    # Tarred warm-brown hull wearing a bounded buff/sand band (rows 8-11 of 14,
    # t 0.57-0.86 — just clear of the waterline) that carries the gun row;
    # brown returns above it. Narrower than the frigate's band: tan-on-brown
    # carries far more contrast than navy-on-black, so the stripe stays a
    # stripe instead of repainting the ship.
    hull = kit_create_hull(
        FORM,
        materials,
        mesh_name="BrigHullMesh",
        object_name="Hull_curved_brig_body",
        paint_material="buff_paint",
        paint_from_row=8,
        paint_to_row=12,
    )
    # The kit paints the bow cap slivers with the band material (invisible on
    # the galleon/frigate); keep every cap face tarred brown on the brig. The
    # cap faces are the trailing bow/stern row pairs.
    for poly in list(hull.data.polygons)[-2 * 14:]:
        if poly.material_index == 1:
            poly.material_index = 0
    # The kit's bow/stern cap faces wind inward; on the exposed brig counter
    # (small transom, no gallery covering it) the inverted shading normal
    # renders the dark stern blown-out bright. Reorient outward — brig mesh
    # only, prior ships hide these faces behind transom decor.
    recalc_outward_normals(hull.data)
    return hull


def add_strip_mesh(name, top_pts, bottom_pts, material, bevel=0.012):
    verts = []
    faces = []
    for i, (top, bottom) in enumerate(zip(top_pts, bottom_pts)):
        verts.append(tuple(top))
        verts.append(tuple(bottom))
        if i:
            a = (i - 1) * 2
            b = i * 2
            faces.append((a, b, b + 1, a + 1))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    if bevel > 0:
        mod = obj.modifiers.new("soft bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def add_halfdeck(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    navy = materials["navy_paint"]
    black = materials["black"]

    # Raised plank platform aft of the waist — deliberately low (about half
    # the frigate quarterdeck's step) so the sheer stays knife-flat.
    verts = []
    for z in HDECK_Z:
        left = side_point(z, -1, 0.985, -0.038)
        right = side_point(z, 1, 0.985, -0.038)
        y = hdeck_y(z)
        verts.append((left[0], y, z))
        verts.append((right[0], y, z))
    faces = [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(len(HDECK_Z) - 1)]
    mesh = bpy.data.meshes.new("Halfdeck_plank_platformMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Halfdeck_plank_platform", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(wood)
    obj.modifiers.new("deck weighted normals", "WEIGHTED_NORMAL")
    bevel = obj.modifiers.new("soft deck edge", "BEVEL")
    bevel.width = 0.014
    bevel.segments = 2
    for z in HDECK_Z[1:-1:2]:
        left = side_point(z, -1, 0.985, -0.066)
        right = side_point(z, 1, 0.985, -0.066)
        add_cube(
            f"Halfdeck_plank_separator_{z:.2f}",
            (0, hdeck_y(z) + 0.014, z),
            (abs(right[0] - left[0]), 0.012, 0.016),
            dark,
            0.002,
        )

    # Low side bulwarks planted on the actual hull skin, wearing the concept
    # sheet's navy as the brig's one painted accent; dark cap on top. The cap
    # line sweeps down at the front instead of stopping square.
    for side in (-1, 1):
        top_pts = []
        bottom_pts = []
        for i, z in enumerate(HDECK_Z):
            skin = FORM.mesh_point(z, side, 0.995)
            x = skin.x + side * 0.014
            sweep = 0.055 if i == 0 else (0.018 if i == 1 else 0.0)
            top_pts.append((x, hdeck_y(z) + 0.085 - sweep, z))
            bottom_pts.append((x, skin.y - 0.05, z))
        add_strip_mesh(f"Halfdeck_side_bulwark_{side}", top_pts, bottom_pts, navy, 0.012)
        add_polyline(
            f"Halfdeck_bulwark_cap_rail_{side}",
            [(x, y, z) for x, y, z in top_pts],
            0.023,
            dark,
        )

    # Plain breast bulkhead closing the platform toward the waist: one shadowed
    # central doorway, a pair of side steps, nothing gilded.
    front_half = abs(side_point(HDECK_Z[0], 1, 1.0, 0.0)[0])
    front_z = HDECK_Z[0] + 0.040
    main_deck_y = side_point(HDECK_Z[0], 1, 0.985, -0.020)[1] + 0.050
    wall_height = HDECK_Y_FWD - main_deck_y + 0.075
    add_cube(
        "Halfdeck_breast_bulkhead",
        (0, main_deck_y + wall_height * 0.5 - 0.02, front_z),
        (front_half * 2.0 - 0.05, wall_height, 0.075),
        dark,
        0.010,
    )
    add_cube("Halfdeck_breast_doorway", (0, main_deck_y + 0.070, front_z - 0.044), (0.13, 0.125, 0.026), black, 0.004)
    for side in (-1, 1):
        for i, (dz, dy) in enumerate([(0.13, 0.028), (0.045, 0.078)]):
            add_cube(
                f"Halfdeck_side_step_{side}_{i}",
                (side * 0.40, main_deck_y + dy, front_z - dz),
                (0.22, 0.040, 0.12),
                dark,
                0.006,
            )


def add_transom(materials):
    navy = materials["navy_paint"]
    dark = materials["dark_wood"]
    counter = materials["counter_wood"]
    iron = materials["gold"]
    brass = materials["brass"]
    black = materials["black"]

    # Small plain raked transom: one modest navy panel, two rectangular stern
    # lights, iron mouldings, a taffrail cap. No window row, no galleries.
    # The counter stack wears the deeper "shadowed counter" wood: aft faces
    # catch the review fill light square-on and tarred brown blows out pale.
    add_tapered_box("Transom_navy_panel", (0, 0.70, 2.03), 0.84, 0.72, 0.32, 0.14, navy, 0.016)
    add_tapered_box("Transom_dark_counter_fairing", (0, 0.475, 1.95), 0.90, 0.83, 0.21, 0.26, counter, 0.016)
    add_tapered_box("Transom_counter_planking", (0, 0.295, 1.97), 0.78, 0.88, 0.16, 0.22, counter, 0.014)
    add_cube("Transom_shadow_tuck", (0, 0.585, 2.00), (0.82, 0.030, 0.17), black, 0.007)
    add_cube("Transom_iron_upper_moulding", (0, 0.845, 2.075), (0.74, 0.016, 0.045), iron, 0.003)
    add_cube("Transom_dark_taffrail_cap", (0, 0.875, 2.07), (0.78, 0.034, 0.065), dark, 0.007)

    # Two stern lights only (the brief's ceiling).
    for col, x in enumerate([-0.17, 0.17]):
        add_cube(f"Transom_light_recess_{col}", (x, 0.705, 2.105), (0.115, 0.155, 0.036), dark, 0.004)
        add_cube(f"Transom_light_glass_{col}", (x, 0.705, 2.118), (0.082, 0.112, 0.032), black, 0.003)
        add_cube(f"Transom_light_iron_lintel_{col}", (x, 0.795, 2.113), (0.125, 0.014, 0.036), iron, 0.003)
        add_cube(f"Transom_light_iron_sill_{col}", (x, 0.618, 2.113), (0.122, 0.013, 0.036), iron, 0.003)

    # Taffrail ensign staff, raked aft; the runtime faction flag hangs from
    # Anchor_Flag_Stern near its head. Brass truck = half the gold budget.
    add_cylinder_between("Transom_ensign_staff", (0, 0.86, 2.07), (0, 1.46, 2.24), 0.015, dark, 10)
    add_ellipsoid("Transom_ensign_staff_brass_truck", (0, 1.472, 2.245), (0.013, 0.017, 0.013), brass, 8, 4)


def add_hoop(name, loc, major_radius, minor_radius, material):
    # Ring around the barrel body, not a rod through it — axis rotated onto Y
    # (the deck's up axis) so it wraps the stave silhouette like an iron band.
    bpy.ops.mesh.primitive_torus_add(
        location=loc, major_radius=major_radius, minor_radius=minor_radius,
        major_segments=12, minor_segments=6,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    if material:
        obj.data.materials.append(material)
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def add_dutch_barrel(name, x, z, cargo, dark_mat):
    # A short straight-sided cylinder body (the bulk of a real barrel's
    # height) with a brief taper to each rim reads as a barrel; the prior
    # rim-to-belly-to-rim taper over the FULL height had no straight run and
    # came out lens/egg-shaped. Dark stave lines and hoop bands are separate
    # dark_mat geometry — wood_mat's procedural grain doesn't survive glTF
    # export (ADR 0010), so the "wood lines" have to be modeled, not shaded.
    height = 0.30
    taper_frac = 0.22
    r_rim = 0.082
    r_body = 0.115
    n_staves = 8
    y_bottom = mast_deck_y(z)
    y_taper1 = y_bottom + height * taper_frac
    y_taper2 = y_bottom + height * (1.0 - taper_frac)
    y_top = y_bottom + height

    add_spar(f"{name}_lower_taper", (x, y_bottom, z), (x, y_taper1, z), r_rim, r_body, cargo, 10)
    add_cylinder_between(f"{name}_body", (x, y_taper1, z), (x, y_taper2, z), r_body, cargo, 10)
    add_spar(f"{name}_upper_taper", (x, y_taper2, z), (x, y_top, z), r_body, r_rim, cargo, 10)

    def radius_at(frac):
        if frac <= taper_frac:
            return r_rim + (r_body - r_rim) * (frac / taper_frac)
        if frac >= 1.0 - taper_frac:
            return r_rim + (r_body - r_rim) * ((1.0 - frac) / taper_frac)
        return r_body

    for frac in (0.09, 0.19, 0.81, 0.91):
        hy = y_bottom + height * frac
        hr = radius_at(frac) * 1.10
        add_hoop(f"{name}_hoop_{frac:.2f}", (x, hy, z), hr, 0.010, dark_mat)

    for i in range(n_staves):
        angle = (2.0 * math.pi * i) / n_staves
        sx = math.cos(angle) * r_body * 1.01
        sz = math.sin(angle) * r_body * 1.01
        add_cylinder_between(f"{name}_stave_{i}", (x + sx, y_taper1, z + sz), (x + sx, y_taper2, z + sz), 0.0055, dark_mat, 6)


def add_dutch_commerce_dressing(materials):
    """Give the Dutch pilot a broad commerce read without changing hull dimensions."""
    wood = materials["wood"]
    dark = materials["dark_wood"]
    rope = materials["rope"]
    cargo = materials["cargo_wood"]
    for side in (-1, 1):
        for z in (-0.86, -0.12, 0.62):
            x, y, _ = side_point(z, side, 0.985, 0.055)
            add_cylinder_between(f"Dutch_loading_beam_{side}_{z}", (x, y + 0.085, z), (x + side * 0.20, y + 0.095, z), 0.018, dark, 10)
        rail = []
        for z in (1.35, 0.86, 0.36, -0.16, -0.66):
            x, y, _ = side_point(z, side, 1.0, 0.055)
            rail.append((x, y + 0.215, z))
        add_polyline(f"Dutch_broad_work_rail_{side}", rail, 0.024, dark)

    # Centerline cargo stays clear of guns and sail roots, but remains large
    # enough to resolve as freight from the gameplay camera.
    for i, (x, z) in enumerate(((-0.30, -0.30), (0.00, -0.56), (0.30, -0.30), (-0.24, 0.52), (0.24, 0.52))):
        add_dutch_barrel(f"Dutch_cargo_barrel_{i}", x, z, cargo, dark)
    for i, (x, z) in enumerate(((-0.36, 0.90), (0.36, 0.90))):
        y = mast_deck_y(z) + 0.090
        add_cube(f"Dutch_cargo_crate_{i}", (x, y, z), (0.22, 0.16, 0.20), cargo, 0.010)
        add_polyline(f"Dutch_cargo_crate_lash_{i}", [(x - 0.13, y + 0.09, z - 0.12), (x + 0.13, y + 0.09, z + 0.12)], 0.009, rope)
        add_polyline(f"Dutch_cargo_crate_crosslash_{i}", [(x - 0.13, y + 0.09, z + 0.12), (x + 0.13, y + 0.09, z - 0.12)], 0.009, rope)
    for side in (-1, 1):
        add_rope_bundle(
            f"Dutch_cargo_net_{side}",
            [rope_points((side * 0.56, 0.80, 0.66), (side * 0.72, 0.62, 0.18), 0.06), rope_points((side * 0.56, 0.80, 0.28), (side * 0.72, 0.62, 0.70), 0.06)],
            0.008,
            rope,
        )


def decorate_hull(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    navy = materials["navy_paint"]
    brass = materials["brass"]
    black = materials["black"]

    # Shaped main deck, full length: closes top-down views along both sides.
    deck_z = [2.02, 1.82, 1.58, 1.32, 1.04, 0.74, 0.42, 0.10, -0.22, -0.54, -0.86, -1.18, -1.50, -1.78, -2.00, -2.16]
    add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
    add_cube("Deck_central_hatch_frame", (0, 0.585, 0.10), (0.38, 0.048, 0.28), dark, 0.014)
    add_cube("Deck_central_hatch_recess", (0, 0.613, 0.10), (0.28, 0.024, 0.19), black, 0.008)
    for x in (-0.10, 0.0, 0.10):
        add_cube(f"Deck_hatch_slat_{x}", (x, 0.629, 0.10), (0.020, 0.016, 0.23), wood, 0.003)
    add_cube("Deck_fore_hatch_frame", (0, 0.605, -1.30), (0.26, 0.042, 0.20), dark, 0.010)
    add_cube("Deck_fore_hatch_recess", (0, 0.629, -1.30), (0.18, 0.022, 0.13), black, 0.006)

    for side in (-1, 1):
        add_polyline(
            f"deck_edge_dark_cap_{side}",
            [(x, y + 0.050, z) for x, y, z in [side_point(z, side, 0.99, 0.004) for z in deck_z]],
            0.017,
            dark,
        )

    # Workmanlike hull graphics: three plank lines below the band, dark strakes
    # edging the buff band, and one muted navy sheer strake just under the rail
    # (the concept sheet's blue, kept to a stripe so the frigate owns navy).
    for side in (-1, 1):
        for t in (0.16, 0.30, 0.42):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.004))
            add_polyline(f"wood_plank_line_{side}_{t:.2f}", pts, 0.008, dark)
        for t in (0.571, 0.857):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.005))
            add_polyline(f"buff_band_edge_strake_{side}_{t:.2f}", pts, 0.009, dark)
        pts = []
        for z, *_ in station_profile()[1:-1]:
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.955)
            pts.append(tuple(origin + e_x * 0.006))
        add_polyline(f"navy_sheer_strake_{side}", pts, 0.016, navy)

    # One short gun row: 7 ports per side in the buff band with muzzles run
    # out (gameplay stat is 14; modeled count is readability).
    gun_z = [-1.55 + i * 0.45 for i in range(7)]
    for side in (-1, 1):
        for i, z in enumerate(gun_z):
            add_side_gunport(FORM, f"main_gundeck_port_{side}_{i}", side, z, 0.70, materials, size=0.155)
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.70)
            add_cylinder_between(f"main_deck_cannon_{side}_{i}", tuple(origin - e_x * 0.06), tuple(origin + e_x * 0.095), 0.020, black, 12)

    # Main-deck bulwark rails, bow to the half-deck break. Plain: no caps, no
    # gilding — posts and two rails, closed into the stem at the bow.
    for side in (-1, 1):
        rail_z = [0.85, 0.45, 0.05, -0.35, -0.75, -1.15, -1.55, -1.90]
        for z in rail_z:
            x, y, _ = side_point(z, side, 1.0, 0.034)
            add_cylinder_between(f"rail_post_{side}_{z}", (x, y, z), (x, y + 0.195, z), 0.020, dark, 10)
        rail_pts = [side_point(z, side, 1.0, 0.034) for z in rail_z]
        rail_pts = [(x, y + 0.20, z) for x, y, z in rail_pts]
        add_polyline(f"top_rail_{side}", rail_pts, 0.027, dark)
        add_polyline(f"mid_rail_{side}", [(x, y - 0.10, z) for x, y, z in rail_pts], 0.015, dark)
        end_x, end_y, end_z = rail_pts[-1]
        add_polyline(
            f"Bow_rail_closing_sweep_{side}",
            [(end_x, end_y, end_z), (side * 0.12, 0.775, -2.30), (side * 0.025, 0.740, -2.42)],
            0.022,
            dark,
        )

    # Bow: swept dark stem with a simple brass cap — no billethead scroll, no
    # figurehead. Bowsprit knees tie the spar into the head.
    add_polyline("Bow_swept_dark_stem", [(0, -0.02, -2.02), (0, 0.26, -2.20), (0, 0.50, -2.31), (0, 0.63, -2.375)], 0.024, dark)
    add_polyline("Bow_stem_brass_cap", [(0, 0.63, -2.375), (0, 0.685, -2.405), (0, 0.715, -2.415)], 0.019, brass)
    for side in (-1, 1):
        add_cylinder_between(
            f"Bow_bowsprit_knee_{side}",
            (side * 0.10, 0.60, -2.10),
            (side * 0.025, 0.72, -2.32),
            0.013,
            dark,
            10,
        )

    add_halfdeck(materials)
    add_transom(materials)
    if FACTION_KIT == "dutch":
        add_dutch_commerce_dressing(materials)

    # Two masts only — the class signature. Square-rigged foremast; the main
    # is a bare kit pole (no square yards) carrying ship-side boom and gaff.
    add_mast_assembly(
        FORM,
        "fore", -0.85, 2.25, 0.056, materials,
        square_yards=[("lower", 0.47, 1.32, 0.026), ("upper", 0.90, 0.98, 0.021)],
    )
    add_mast_assembly(FORM, "main", 0.32, 2.55, 0.064, materials)
    add_gaff_spars(materials)

    # Bowsprit: short and low-steeved (~24 degrees), iron gammoning, no gold tip.
    add_cylinder_between("Bowsprit_dark_wood", (0, 0.56, -2.12), (0, 0.98, -3.06), 0.042, dark, 16)
    add_cylinder_between("Bowsprit_dark_tip", (0, 0.98, -3.06), (0, 1.035, -3.17), 0.028, dark, 14)
    add_cylinder_between("Bowsprit_iron_gammoning_band", (0, 0.655, -2.355), (0, 0.695, -2.385), 0.052, materials["gold"], 12)


def mast_deck_y(z):
    return side_point(z, 1, 0.985, -0.020)[1]


def gaff_geometry():
    # Shared by the spar builder, the sail sheet, and the rigging routes.
    main_deck = mast_deck_y(0.32)
    boom_start = Vector((0.0, main_deck + 0.345, 0.40))
    boom_end = Vector((0.0, main_deck + 0.388, 1.98))
    throat = Vector((0.0, main_deck + 1.393, 0.40))
    peak = Vector((0.0, main_deck + 2.000, 1.32))
    return boom_start, boom_end, throat, peak


def add_gaff_spars(materials):
    # Boom + gaff for the big fore-aft mainsail: ship-side add_spar calls (the
    # brief's bias — no kit change for a one-ship rig). Named Yard_* so they
    # classify into the main assembly and flatten to Yard_Main_Gaff.
    dark = materials["dark_wood"]
    iron = materials["gold"]
    boom_start, boom_end, throat, peak = gaff_geometry()
    add_spar("Yard_boom_main", tuple(boom_start), tuple(boom_end), 0.030, 0.022, dark, 12)
    add_spar("Yard_gaff_main", tuple(throat), tuple(peak), 0.022, 0.015, dark, 12)
    add_cube("Yard_boom_jaw_main", (0, boom_start.y, 0.35), (0.12, 0.055, 0.12), dark, 0.008)
    add_cube("Yard_gaff_jaw_main", (0, throat.y, 0.35), (0.11, 0.050, 0.11), dark, 0.008)
    add_cylinder_between("Yard_gaff_iron_collar_main", (0, throat.y - 0.02, 0.32), (0, throat.y + 0.02, 0.32), 0.055, iron, 12)


def add_sails(materials):
    # Five sails, moderately filled (baked shape, runtime deformation out of
    # scope). Square sails billow bow-ward (-Z, runtime wind convention); the
    # gaff mainsail and the jib billow to starboard.
    canvas = materials["sail"]

    fore_deck = mast_deck_y(-0.85)

    add_square_sail("Sail_course_fore", canvas, -0.85, fore_deck + 2.25 * 0.47, 0.88, 1.25, 1.25, 0.25, 0.10)
    add_square_sail("Sail_topsail_fore", canvas, -0.85, fore_deck + 2.25 * 0.90, fore_deck + 2.25 * 0.62, 0.70, 0.88, 0.19, 0.075)

    # Gaff mainsail: quad sheet laced head-to-gaff and foot-to-boom, luff at
    # the mast, free flat leech — billow vanishes on all four edges except a
    # starboard belly mid-canvas (lateen/jib convention).
    boom_start, boom_end, throat_spar, peak_spar = gaff_geometry()
    throat = Vector((0.0, throat_spar.y - 0.02, 0.44))
    peak = Vector((0.0, peak_spar.y - 0.02, peak_spar.z - 0.02))
    tack = Vector((0.0, boom_start.y + 0.033, 0.46))
    clew = Vector((0.0, boom_end.y + 0.040, 1.90))

    def gaff_fn(u, v):
        head = throat.lerp(peak, u)
        foot = tack.lerp(clew, u)
        base = head.lerp(foot, v)
        billow = 0.16 * math.sin(math.pi * u) * math.sin(math.pi * v)
        return (base.x + billow, base.y, base.z)

    add_sail("Sail_gaff_main", gaff_fn, canvas)

    # Jib on the fore topmast stay (the stay route in add_rigging matches these
    # endpoints); tack seated on the bowsprit spar, clew sheeted aft.
    stay_low = (0.0, 0.945, -2.98)
    stay_high = (0.0, fore_deck + 2.25 - 0.04, -0.87)
    add_jib(
        "Sail_jib_bowsprit",
        canvas,
        stay_low,
        stay_high,
        clew=(0.0, 0.78, -1.62),
        luff_start=0.02,
        luff_end=0.78,
        billow=0.15,
        sheet_offset=0.065,
    )


def add_rigging(materials):
    # Stylized standing rigging: silhouette support, not rope simulation.
    # Routes chosen to clear the filled sails; main shrouds anchor FORWARD of
    # the mast so they angle away from the aft gaff canvas (the mizzen lesson
    # from both prior ships), and the fore topmast stay doubles as the jib luff.
    rope = materials["rope"]

    def bulwark_anchor(z, side):
        x, y, _ = side_point(z, side, 1.0, 0.05)
        return (x, y + 0.09, z)

    def hdeck_rail_anchor(z, side):
        skin = FORM.mesh_point(z, side, 0.995)
        return (skin.x + side * 0.012, hdeck_y(z) + 0.09, z)

    fore_deck = mast_deck_y(-0.85)
    fore_head = fore_deck + 2.25
    fore_top = fore_deck + 2.25 * 0.60
    main_deck = mast_deck_y(0.32)
    main_head = main_deck + 2.55
    main_top = main_deck + 2.55 * 0.60
    boom_start, boom_end, throat, peak = gaff_geometry()

    fore = []
    fore.append(rope_points((0, fore_head - 0.04, -0.87), (0, 0.945, -2.98), 0.015))  # topmast stay = jib luff line (kept taut)
    fore.append(rope_points((0, fore_top - 0.10, -0.87), (0, 0.70, -2.30), 0.04))     # fore stay -> stem head / gammoning
    for side in (-1, 1):
        fore.append(rope_points((0, fore_head - 0.04, -0.83), bulwark_anchor(-0.20, side), 0.03))
        for z in (-1.15, -0.85, -0.55):
            fore.append(rope_points((0, fore_top - 0.10, -0.85), bulwark_anchor(z, side), 0.012))
        fore.append(rope_points((0, fore_deck + 2.25 * 0.47 + 0.03, -0.85), (side * 0.66, fore_deck + 2.25 * 0.47, -0.85), 0.015))
    add_rope_bundle("Rigging_fore", fore, 0.010, rope)

    main = []
    main.append(rope_points((0, main_top - 0.12, 0.30), (0, fore_top - 0.10, -0.81), 0.05))   # main stay -> fore top
    main.append(rope_points((0, main_head - 0.04, 0.30), (0, fore_head + 0.01, -0.81), 0.05))  # main topmast stay -> fore masthead
    main.append(rope_points((0, main_head - 0.06, 0.36), (0, peak.y + 0.02, peak.z - 0.02), 0.02))  # gaff peak halyard
    main.append(rope_points((0, boom_end.y - 0.02, 1.94), (0, 0.745, 2.00), 0.008))            # boom sheet -> half-deck
    for side in (-1, 1):
        for z in (-0.25, 0.03, 0.30):
            main.append(rope_points((0, main_top - 0.12, 0.32), bulwark_anchor(z, side), 0.012))
        main.append(rope_points((0, main_head - 0.04, 0.36), hdeck_rail_anchor(1.80, side), 0.03))  # backstay, clear of the leech
        main.append(rope_points((0, peak.y, peak.z), (side * 0.30, 0.82, 1.98), 0.02))              # gaff vang framing the leech
    add_rope_bundle("Rigging_main", main, 0.010, rope)

    bowsprit = []
    bowsprit.append(rope_points((0, 0.92, -2.90), (0, 0.06, -2.02), 0.03))            # bobstay -> stem
    for side in (-1, 1):
        bowsprit.append(rope_points((0, 0.93, -2.92), (side * 0.24, 0.32, -1.80), 0.02))  # shroud -> hull skin
    add_rope_bundle("Rigging_bowsprit", bowsprit, 0.009, rope)


def add_flags_and_anchors(materials):
    # Two restrained masthead streamers (fore + main); the faction flag stays
    # procedural in Godot — the model only ships anchor empties for the
    # runtime flag and fire-effect systems.
    streamer = materials["streamer"]
    fore_head = mast_deck_y(-0.85) + 2.25
    main_head = mast_deck_y(0.32) + 2.55

    add_streamer("Streamer_fore", (0, fore_head + 0.05, -0.82), 0.34, 0.052, streamer)
    add_streamer("Streamer_main", (0, main_head + 0.05, 0.37), 0.44, 0.060, streamer)

    # Flag anchors: ensign on the taffrail staff, pennant at the main masthead.
    # Fire anchors keep the exact gameplay-tuned visual_states positions from
    # ship_visual_profiles.yaml (brigantine_basic deck_fire_main / sail_fire_main).
    add_anchor_empty("Anchor_Flag_Stern", (0.0, 1.44, 2.23))
    add_anchor_empty("Anchor_Flag_Main", (0.0, main_head + 0.06, 0.32))
    add_anchor_empty("Anchor_Fire_Deck", (0.0, 0.85, 0.18))
    add_anchor_empty("Anchor_Fire_Sail", (0.0, 1.88, 0.32))


MAST_ASSEMBLIES = {"fore": "ForemastAssembly", "main": "MainmastAssembly", "bowsprit": "BowspritAssembly"}

# Two-mast contract tree: MizzenAssembly is dropped, everything else keeps the
# contract names (transom pieces take the Sterncastle slot, frigate precedent).
ASSEMBLY_TREE = {
    "Hull": ["HullMesh", "Deck", "Sterncastle", "Railings", "Gunports", "Cannons"],
    "ForemastAssembly": [],
    "MainmastAssembly": [],
    "BowspritAssembly": [],
    "Flags": [],
    "EffectsAnchors": [],
}


def classify_ship_object(name):
    n = name.lower()
    # Brig-specific rules first, then the kit's cross-ship prefixes. The
    # half-deck platform/bulwarks/steps are deck architecture; the transom
    # panel, stern lights, and ensign staff take the Sterncastle slot.
    if n.startswith("transom_"):
        return "Sterncastle"
    if n.startswith("halfdeck_bulwark_cap_rail"):
        return "Railings"
    if n.startswith("halfdeck_"):
        return "Deck"
    if n.startswith(("dutch_cargo_", "dutch_loading_beam_")):
        return "Deck"
    if n.startswith("dutch_broad_work_rail_"):
        return "Railings"
    common = classify_common(n, MAST_ASSEMBLIES)
    if common is not None:
        return common
    if n.startswith(("hull_", "wood_plank_line_", "buff_band_edge_strake_", "navy_sheer_strake_", "bow_")):
        return "HullMesh"
    return None


def organize_assemblies():
    assembly_locations = {
        "ForemastAssembly": (0.0, mast_deck_y(-0.85), -0.85),
        "MainmastAssembly": (0.0, mast_deck_y(0.32), 0.32),
        "BowspritAssembly": (0.0, 0.58, -2.14),
    }
    organize_assemblies_from("Brig", ASSEMBLY_TREE, assembly_locations, classify_ship_object)


def build_materials():
    return {
        # Tarred warm-brown hull: a working raider, not a showpiece.
        "dark_wood": wood_mat("tarred warm brown hull oak", (0.135, 0.088, 0.052, 1), (0.205, 0.138, 0.082, 1), (0.045, 0.028, 0.016, 1)),
        "wood": wood_mat("weathered brig deck wood", (0.40, 0.29, 0.16, 1), (0.55, 0.40, 0.22, 1), (0.12, 0.07, 0.035, 1)),
        # Deep shadowed counter timber for the transom stack (aft faces sit
        # square to the fill light and need the darker base to stay tarred).
        "counter_wood": wood_mat("shadowed counter timber", (0.062, 0.044, 0.028, 1), (0.100, 0.070, 0.045, 1), (0.022, 0.015, 0.010, 1)),
        # Buff/sand gun band: the brig's ownable color (galleon owns burgundy,
        # frigate owns navy-as-band).
        "buff_paint": paint_mat("buff sand gun band", (0.435, 0.345, 0.205, 1), (0.535, 0.440, 0.285, 1), (0.250, 0.190, 0.105, 1)),
        # Muted navy from the concept sheet, kept to bulwark/transom accents.
        "navy_paint": paint_mat("muted brig bulwark navy", (0.048, 0.075, 0.130, 1), (0.075, 0.112, 0.185, 1), (0.020, 0.030, 0.058, 1)),
        # Brick red for gunport reveals (kit gunports read materials["red_paint"]).
        "red_paint": paint_mat("muted brick port reveal", (0.315, 0.075, 0.050, 1), (0.415, 0.110, 0.070, 1), (0.165, 0.032, 0.022, 1)),
        # The raider spends nothing on shine: the kit's "gold" slot renders as
        # blackened iron, so mast bands, slings, and port sills come out iron.
        "gold": mat("blackened iron fittings", (0.070, 0.062, 0.055, 1), 0.55, 0.62),
        # The entire true-gold budget: stem cap + ensign truck.
        "brass": gold_mat("single worn brass accent"),
        # Darker than the deck/hull wood so the cargo doesn't wash out against
        # the planking; wood_mat's base color is what actually exports to the
        # GLB (its procedural grain doesn't survive glTF, per ADR 0010) — the
        # stave/hoop lines are separate dark_mat geometry, not shading.
        "cargo_wood": wood_mat("dutch cargo weathered oak", (0.150, 0.098, 0.055, 1), (0.230, 0.155, 0.085, 1), (0.045, 0.028, 0.015, 1)),
        "black": mat("visible warm shadow black", (0.035, 0.027, 0.020, 1), 0.82),
        # Neutral/whitish so ShipVisualBuilder's per-faction tint reads (ADR 0010).
        "sail": mat("neutral sail canvas", (0.91, 0.88, 0.80, 1), 0.90),
        "rope": mat("tarred hemp rope", (0.20, 0.14, 0.09, 1), 0.92),
        "streamer": mat("muted signal red", (0.60, 0.09, 0.07, 1), 0.65),
    }


def render_level(path, camera_location, target, ortho_scale):
    # Kit render_to tracks the camera up toward world Z (a quirk the galleon
    # renders inherited: angled shots come out rolled). This keeps the horizon
    # level — world +Y up — for the brig's angled review shots.
    camera = bpy.context.scene.camera
    camera.location = camera_location
    forward = (Vector(target) - camera.location).normalized()
    right = forward.cross(Vector((0.0, 1.0, 0.0))).normalized()
    up = right.cross(forward)
    camera.rotation_euler = Matrix((right, up, -forward)).transposed().to_euler()
    camera.data.ortho_scale = ortho_scale
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    materials = build_materials()
    create_hull(materials)
    if STAGE == "hull":
        # B1 silhouette check: naked hull + deck/half-deck/transom masses.
        deck_z = [2.02, 1.82, 1.58, 1.32, 1.04, 0.74, 0.42, 0.10, -0.22, -0.54, -0.86, -1.18, -1.50, -1.78, -2.00, -2.16]
        add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
        add_halfdeck(materials)
        add_transom(materials)
    else:
        decorate_hull(materials)
        add_sails(materials)
        add_rigging(materials)
        add_flags_and_anchors(materials)
        organize_assemblies()
    setup_review_scene()
    if QUALITY == "draft":
        bpy.context.scene.cycles.samples = 48
        bpy.context.scene.render.resolution_x = 1600
        bpy.context.scene.render.resolution_y = 970

    if STAGE == "full":
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT_DIR / "brig_working.blend"))

    if STAGE == "hull":
        # B1 framing: tight on the naked hull so the sheer line fills the frame.
        render_to(OUT_DIR / "brig_hull_primary.png", (-8.2, 0.62, -0.10), (0, 0.42, -0.10), 6.9, 90.0)
        render_level(OUT_DIR / "brig_hull_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.50, 0.0), 7.6)
        render_level(OUT_DIR / "brig_hull_stern_angle.png", (-6.1, 3.2, 6.2), (0, 0.60, 0.60), 6.0)
        render_level(OUT_DIR / "brig_hull_bow_readability_angle.png", (6.3, 3.3, -6.4), (0, 0.55, -0.70), 6.0)
        render_clay(OUT_DIR / "brig_hull_clay_side.png", (-8.2, 0.62, -0.10), (0, 0.42, -0.10), 6.4, 90.0)
    else:
        render_to(OUT_DIR / "brig_primary.png", (-8.2, 1.30, -0.20), (0, 1.30, -0.20), 8.8, 90.0)
        render_level(OUT_DIR / "brig_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.75, 0.0), 9.2)
        render_level(OUT_DIR / "brig_stern_angle.png", (-6.1, 3.2, 6.2), (0, 0.85, 0.55), 7.0)
        render_level(OUT_DIR / "brig_bow_readability_angle.png", (6.3, 3.3, -6.4), (0, 0.80, -0.75), 7.6)
        render_level(OUT_DIR / "brig_bow_close.png", (4.5, 1.8, -5.0), (0, 0.85, -1.95), 3.4)
        render_clay(OUT_DIR / "brig_clay_inspection.png", (-8.2, 1.30, -0.20), (0, 1.30, -0.20), 8.8, 90.0)


if __name__ == "__main__":
    main()
