"""Frigate visual asset generator (second ship through the pipeline).

Ship-agnostic machinery lives in artifacts/ship_kit; this file owns only the
frigate: its station profile, hull decoration, quarterdeck/transom, sail plan,
rigging routes, streamers/anchors, classification rules, and review renders.

Class character (docs/design/frigate-visual-brief.md): the hunter. Sleek low
sheer, quarterdeck instead of sterncastle, a single gun deck, taller-looking
rig, jib instead of spritsail. Color scheme per the brief + user concept
sheet: near-black hull, deep navy gun band edged in gold, restrained gold.

Env knobs for iteration:
  FRIGATE_STAGE   hull | full   (default full)
  FRIGATE_QUALITY draft | final (default final)
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
    add_mast_assembly,
    add_polyline,
    add_rope_bundle,
    add_sail,
    add_shaped_deck,
    add_side_gunport,
    add_square_sail,
    add_streamer,
    add_surface_cube,
    add_tapered_box,
    classify_common,
    clear_scene,
    gold_mat,
    mat,
    organize_assemblies_from,
    paint_mat,
    render_clay,
    render_to,
    rope_points,
    setup_review_scene,
    wood_mat,
)
from ship_kit import add_anchor_empty
from ship_kit import create_hull as kit_create_hull

OUT_DIR = Path(__file__).resolve().parent

STAGE = os.environ.get("FRIGATE_STAGE", "full")
QUALITY = os.environ.get("FRIGATE_QUALITY", "final")


def station_profile():
    # z, half width, deck y, keel y. Forward is -Z, matching the Godot convention.
    # Long, low, and fast-looking: mid deck 0.61 vs the galleon's 0.73, gentle
    # sheer both ends, fine bow entry. The quarterdeck is a separate raised
    # platform aft (add_quarterdeck), not hull sheer, so the hull line stays low.
    return [
        (2.45, 0.48, 0.74, -0.36),
        (2.05, 0.63, 0.71, -0.48),
        (1.55, 0.75, 0.68, -0.58),
        (1.05, 0.82, 0.65, -0.65),
        (0.40, 0.85, 0.63, -0.70),
        (-0.40, 0.81, 0.61, -0.69),
        (-1.10, 0.70, 0.63, -0.62),
        (-1.70, 0.52, 0.67, -0.48),
        (-2.25, 0.28, 0.73, -0.24),
        (-2.75, 0.05, 0.81, -0.03),
    ]


# Softer sheer and a gentler stern rake than the galleon house defaults: the
# frigate's silhouette is carried by the long flat run, not by cast-up ends.
FORM = HullForm(
    station_profile(),
    sheer_amplitude=0.030,
    stern_rake_last=(0.34, 0.12),
    stern_rake_previous=(0.12, 0.04),
)

# Quarterdeck platform: z range, deck line, and the step above the main deck.
QDECK_Z = [1.00, 1.20, 1.44, 1.68, 1.92, 2.16, 2.40]
QDECK_Y_FWD = 0.93
QDECK_Y_AFT = 0.97


def qdeck_y(z):
    f = (z - QDECK_Z[0]) / (QDECK_Z[-1] - QDECK_Z[0])
    return QDECK_Y_FWD + (QDECK_Y_AFT - QDECK_Y_FWD) * f


def side_point(z, side, t, offset=0.0):
    return FORM.side_point(z, side, t, offset)


def hull_surface_frame(z, side, t):
    return FORM.surface_frame(z, side, t)


def create_hull(materials):
    # Near-black hull with the navy gun band as a bounded stripe (rows 7-11 of
    # 14, roughly t 0.50-0.79) and dark bulwark above it.
    return kit_create_hull(
        FORM,
        materials,
        mesh_name="FrigateHullMesh",
        object_name="Hull_curved_frigate_body",
        paint_material="navy_paint",
        paint_from_row=7,
        paint_to_row=12,
    )


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


def add_quarterdeck(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    gold = materials["gold"]
    black = materials["black"]

    # Raised plank platform spanning the hull aft of the waist (deck +0.25).
    verts = []
    for z in QDECK_Z:
        left = side_point(z, -1, 0.985, -0.040)
        right = side_point(z, 1, 0.985, -0.040)
        y = qdeck_y(z)
        verts.append((left[0], y, z))
        verts.append((right[0], y, z))
    faces = [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(len(QDECK_Z) - 1)]
    mesh = bpy.data.meshes.new("Quarterdeck_plank_platformMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Quarterdeck_plank_platform", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(wood)
    obj.modifiers.new("deck weighted normals", "WEIGHTED_NORMAL")
    bevel = obj.modifiers.new("soft deck edge", "BEVEL")
    bevel.width = 0.016
    bevel.segments = 2
    for z in QDECK_Z[1:-1:2]:
        left = side_point(z, -1, 0.985, -0.070)
        right = side_point(z, 1, 0.985, -0.070)
        add_cube(
            f"Quarterdeck_plank_separator_{z:.2f}",
            (0, qdeck_y(z) + 0.016, z),
            (abs(right[0] - left[0]), 0.013, 0.017),
            dark,
            0.002,
        )

    # Solid side bulwarks: planted on the actual hull skin (mesh_point, not the
    # decor model) and buried below the sheer so the raised deck reads as part
    # of the hull instead of a floating slab. The front of the cap line sweeps
    # down toward the waist rail instead of stopping square.
    for side in (-1, 1):
        top_pts = []
        bottom_pts = []
        for i, z in enumerate(QDECK_Z):
            skin = FORM.mesh_point(z, side, 0.995)
            x = skin.x + side * 0.016
            sweep = 0.065 if i == 0 else (0.022 if i == 1 else 0.0)
            top_pts.append((x, qdeck_y(z) + 0.115 - sweep, z))
            bottom_pts.append((x, skin.y - 0.10, z))
        add_strip_mesh(f"Quarterdeck_side_bulwark_{side}", top_pts, bottom_pts, dark, 0.014)
        add_polyline(
            f"Quarterdeck_bulwark_cap_rail_{side}",
            [(x, y, z) for x, y, z in top_pts],
            0.026,
            dark,
        )
        add_polyline(
            f"Quarterdeck_bulwark_gold_deckline_{side}",
            [(x + side * 0.012, qdeck_y(z) - 0.020, z) for (x, _, z) in top_pts],
            0.008,
            gold,
        )

    # Breast bulkhead closing the platform toward the waist, with a shadowed
    # doorway each side of center and modest gold nosing on the deck edge.
    front_half = abs(side_point(QDECK_Z[0], 1, 1.0, 0.0)[0])
    front_z = QDECK_Z[0] + 0.045
    main_deck_y = side_point(QDECK_Z[0], 1, 0.985, -0.020)[1] + 0.050
    wall_height = QDECK_Y_FWD - main_deck_y + 0.10
    add_cube(
        "Quarterdeck_breast_bulkhead",
        (0, main_deck_y + wall_height * 0.5 - 0.03, front_z),
        (front_half * 2.0 - 0.06, wall_height, 0.09),
        dark,
        0.012,
    )
    add_cube("Quarterdeck_breast_gold_nosing", (0, QDECK_Y_FWD + 0.012, front_z - 0.012), (front_half * 2.0 - 0.14, 0.016, 0.030), gold, 0.004)
    for side in (-1, 1):
        add_cube(f"Quarterdeck_breast_doorway_{side}", (side * 0.30, main_deck_y + 0.095, front_z - 0.052), (0.15, 0.19, 0.03), black, 0.004)
        add_cube(f"Quarterdeck_breast_door_lintel_{side}", (side * 0.30, main_deck_y + 0.20, front_z - 0.050), (0.17, 0.020, 0.026), gold, 0.003)

    # Small side steps up to the quarterdeck: three treads beside each doorway.
    for side in (-1, 1):
        for i, (dz, y) in enumerate([(0.16, main_deck_y + 0.045), (0.06, main_deck_y + 0.125), (-0.04, main_deck_y + 0.205)]):
            add_cube(
                f"Quarterdeck_side_step_{side}_{i}",
                (side * 0.60, y, QDECK_Z[0] - dz),
                (0.26, 0.045, 0.15),
                dark,
                0.008,
            )


def add_transom(materials):
    navy = materials["navy_paint"]
    dark = materials["dark_wood"]
    gold = materials["gold"]
    black = materials["black"]

    # Simple raked transom: one navy panel above the hull's stern face carrying
    # a single row of windows. No tiered galleries, no balcony (the brief).
    add_tapered_box("Transom_navy_panel", (0, 0.955, 2.40), 1.00, 0.86, 0.44, 0.14, navy, 0.020)
    add_tapered_box("Transom_dark_counter_fairing", (0, 0.70, 2.30), 1.04, 1.00, 0.16, 0.26, dark, 0.020)
    add_cube("Transom_shadow_tuck", (0, 0.615, 2.28), (0.98, 0.040, 0.24), black, 0.008)
    add_cube("Transom_gold_lower_moulding", (0, 0.760, 2.435), (0.99, 0.020, 0.050), gold, 0.004)
    add_cube("Transom_gold_upper_moulding", (0, 1.145, 2.415), (0.86, 0.018, 0.050), gold, 0.004)
    add_cube("Transom_dark_taffrail_cap", (0, 1.185, 2.41), (0.90, 0.038, 0.075), dark, 0.008)

    # One row of five stern windows on the aft face.
    for col, x in enumerate([-0.30, -0.15, 0.0, 0.15, 0.30]):
        add_cube(f"Transom_window_recess_{col}", (x, 0.95, 2.463), (0.105, 0.185, 0.040), dark, 0.004)
        add_cube(f"Transom_window_glass_{col}", (x, 0.95, 2.478), (0.075, 0.135, 0.036), black, 0.003)
        add_cube(f"Transom_window_gold_lintel_{col}", (x, 1.052, 2.474), (0.115, 0.016, 0.040), gold, 0.003)
        add_cube(f"Transom_window_gold_sill_{col}", (x, 0.848, 2.474), (0.112, 0.014, 0.040), gold, 0.003)
    for x in (-0.375, -0.225, -0.075, 0.075, 0.225, 0.375):
        add_cube(f"Transom_window_gold_mullion_{x:.3f}", (x, 0.95, 2.470), (0.016, 0.21, 0.040), gold, 0.003)

    # Ensign staff on the taffrail centerline, raked aft; the runtime faction
    # flag hangs from Anchor_Flag_Stern near its head (added with the anchors).
    add_cylinder_between("Transom_ensign_staff", (0, 1.16, 2.40), (0, 1.94, 2.58), 0.020, dark, 10)
    add_ellipsoid("Transom_ensign_staff_gold_truck", (0, 1.955, 2.585), (0.016, 0.020, 0.016), gold, 8, 4)


def decorate_hull(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    gold = materials["gold"]
    black = materials["black"]

    # Shaped main deck, full length: closes top-down views along both sides.
    deck_z = [2.40, 2.20, 1.96, 1.64, 1.28, 0.92, 0.56, 0.20, -0.16, -0.52, -0.88, -1.24, -1.60, -1.96, -2.20, -2.42]
    add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
    add_cube("Deck_central_hatch_frame", (0, 0.735, 0.30), (0.42, 0.050, 0.30), dark, 0.016)
    add_cube("Deck_central_hatch_recess", (0, 0.765, 0.30), (0.31, 0.026, 0.21), black, 0.009)
    for x in (-0.11, 0.0, 0.11):
        add_cube(f"Deck_hatch_slat_{x}", (x, 0.783, 0.30), (0.022, 0.018, 0.25), wood, 0.003)
    add_cube("Deck_fore_hatch_frame", (0, 0.760, -1.62), (0.30, 0.045, 0.22), dark, 0.012)
    add_cube("Deck_fore_hatch_recess", (0, 0.786, -1.62), (0.21, 0.024, 0.15), black, 0.007)

    for side in (-1, 1):
        add_polyline(
            f"deck_edge_dark_cap_{side}",
            [(x, y + 0.052, z) for x, y, z in [side_point(z, side, 0.99, 0.004) for z in deck_z]],
            0.019,
            dark,
        )

    # Planking below the band; two gold strakes edging the navy band and a thin
    # sheer line just below the rail. Half the galleon's trim budget on purpose.
    for side in (-1, 1):
        for t in (0.14, 0.26, 0.38):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.004))
            add_polyline(f"wood_plank_line_{side}_{t:.2f}", pts, 0.008, dark)
        for t, radius in ((0.50, 0.012), (0.86, 0.012), (0.965, 0.009)):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.006))
            add_polyline(f"gold_hull_sheer_{side}_{t:.2f}", pts, radius, gold)

    # Single gun deck: one clean row of 12 ports per side in the navy band,
    # with muzzles run out (gameplay stat is 34; modeled count is readability).
    gun_z = [-1.95 + i * 0.35 for i in range(12)]
    for side in (-1, 1):
        for i, z in enumerate(gun_z):
            add_side_gunport(FORM, f"main_gundeck_port_{side}_{i}", side, z, 0.64, materials, size=0.170)
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.64)
            add_cylinder_between(f"main_deck_cannon_{side}_{i}", tuple(origin - e_x * 0.06), tuple(origin + e_x * 0.105), 0.023, black, 12)

    # Main-deck bulwark rails, bow to the quarterdeck break; the quarterdeck
    # carries its own cap rail. Plainer than the galleon: fewer posts, small caps.
    for side in (-1, 1):
        rail_z = [0.86, 0.44, 0.02, -0.40, -0.82, -1.24, -1.66, -2.02, -2.32]
        for z in rail_z:
            x, y, _ = side_point(z, side, 1.0, 0.036)
            add_cylinder_between(f"rail_post_{side}_{z}", (x, y, z), (x, y + 0.22, z), 0.023, dark, 10)
            add_ellipsoid(f"rail_post_gold_cap_{side}_{z}", (x, y + 0.236, z), (0.020, 0.013, 0.020), gold, 10, 4)
        rail_pts = [side_point(z, side, 1.0, 0.036) for z in rail_z]
        rail_pts = [(x, y + 0.225, z) for x, y, z in rail_pts]
        add_polyline(f"top_rail_{side}", rail_pts, 0.030, dark)
        add_polyline(f"mid_rail_{side}", [(x, y - 0.115, z) for x, y, z in rail_pts], 0.016, dark)
        # Close the bulwark rail into the stem so the bow line does not stop
        # mid-air over the narrowing head.
        end_x, end_y, end_z = rail_pts[-1]
        add_polyline(
            f"Bow_rail_closing_sweep_{side}",
            [(end_x, end_y, end_z), (side * 0.14, 0.97, -2.52), (side * 0.03, 0.94, -2.64)],
            0.024,
            dark,
        )

    # Bow: swept stem, a simple gold scroll billethead (no figurehead
    # menagerie), one head rail per side, and bowsprit knees.
    add_polyline("Bow_swept_gold_stem", [(0, -0.04, -2.12), (0, 0.30, -2.34), (0, 0.62, -2.52), (0, 0.86, -2.62)], 0.026, gold)
    add_polyline(
        "Bow_billethead_gold_scroll",
        [(0, 0.86, -2.62), (0, 0.93, -2.68), (0, 0.965, -2.725), (0, 0.945, -2.76), (0, 0.905, -2.745), (0, 0.90, -2.71)],
        0.024,
        gold,
    )
    add_ellipsoid("Bow_billethead_gold_boss", (0, 0.930, -2.727), (0.020, 0.026, 0.026), gold, 10, 6)
    for side in (-1, 1):
        add_polyline(
            f"Bow_head_rail_{side}",
            [
                side_point(-1.95, side, 0.86, 0.022),
                side_point(-2.35, side, 0.92, 0.014),
                (side * 0.03, 0.92, -2.62),
            ],
            0.016,
            dark,
        )
        add_cylinder_between(
            f"Bow_bowsprit_knee_{side}",
            (side * 0.12, 0.74, -2.28),
            (side * 0.03, 0.94, -2.56),
            0.015,
            dark,
            10,
        )

    add_quarterdeck(materials)
    add_transom(materials)

    # Full mast assemblies (heights above local deck match frigate_basic).
    add_mast_assembly(
        FORM,
        "fore", -1.20, 2.55, 0.062, materials,
        square_yards=[("lower", 0.47, 1.45, 0.028), ("upper", 0.90, 1.06, 0.022)],
    )
    add_mast_assembly(
        FORM,
        "main", -0.05, 2.95, 0.075, materials,
        square_yards=[("lower", 0.47, 1.78, 0.031), ("upper", 0.90, 1.32, 0.025)],
    )
    add_mast_assembly(FORM, "mizzen", 1.00, 2.45, 0.055, materials, lateen=True, lateen_half=0.92)
    add_cube("Quarterdeck_mizzen_partner_collar", (0, qdeck_y(1.00) + 0.012, 1.00), (0.19, 0.05, 0.19), dark, 0.010)

    # Bowsprit: long and low-steeved (~29 degrees), no sprit yard (jib instead).
    add_cylinder_between("Bowsprit_dark_wood", (0, 0.80, -2.38), (0, 1.38, -3.42), 0.048, dark, 16)
    add_cylinder_between("Bowsprit_gold_tip", (0, 1.38, -3.42), (0, 1.46, -3.56), 0.034, gold, 14)
    add_cylinder_between("Bowsprit_gold_gammoning_band", (0, 0.875, -2.545), (0, 0.925, -2.585), 0.058, gold, 12)


def mast_deck_y(z):
    return side_point(z, 1, 0.985, -0.020)[1]


def add_sails(materials):
    # Healthy sail set, moderately filled (baked shape, runtime deformation out
    # of scope). Square sails billow bow-ward (-Z, runtime wind convention);
    # the mizzen lateen and the jib billow to starboard.
    canvas = materials["sail"]

    fore_deck = mast_deck_y(-1.20)
    main_deck = mast_deck_y(-0.05)
    mizzen_deck = mast_deck_y(1.00)

    add_square_sail("Sail_course_fore", canvas, -1.20, fore_deck + 2.55 * 0.47, 1.02, 1.35, 1.35, 0.30, 0.12)
    add_square_sail("Sail_topsail_fore", canvas, -1.20, fore_deck + 2.55 * 0.90, fore_deck + 2.55 * 0.62, 0.80, 0.98, 0.24, 0.09)
    add_square_sail("Sail_course_main", canvas, -0.05, main_deck + 2.95 * 0.47, 1.10, 1.68, 1.68, 0.36, 0.13)
    add_square_sail("Sail_topsail_main", canvas, -0.05, main_deck + 2.95 * 0.90, main_deck + 2.95 * 0.62, 1.00, 1.24, 0.27, 0.10)

    # Mizzen lateen: triangular sheet along the raked yard, clew held forward
    # of the transom, sheeted to the quarterdeck.
    mizzen_cross = mizzen_deck + 2.45 * 0.55
    yard_low = Vector((0.0, mizzen_cross - 0.616, 1.00 - 0.680))
    yard_high = Vector((0.0, mizzen_cross + 0.616, 1.00 + 0.680))
    tack = yard_low.lerp(yard_high, 0.06)
    peak = yard_low.lerp(yard_high, 0.95)
    clew = Vector((0.0, 1.28, 1.92))
    foot_start = tack.lerp(clew, 0.04)

    def lateen_fn(u, v):
        head = tack.lerp(peak, u)
        foot = foot_start.lerp(clew, u)
        base = head.lerp(foot, v)
        billow = 0.17 * math.sin(math.pi * u) * math.sin(math.pi * v * 0.72)
        arc = 0.06 * math.sin(math.pi * u) * (v ** 2)
        return (base.x + billow, base.y + arc, base.z)

    add_sail("Sail_lateen_mizzen", lateen_fn, canvas)

    # Jib: triangular headsail flying on the fore topmast stay (the stay route
    # in add_rigging matches these endpoints), tack near the bowsprit tip,
    # clew sheeted aft toward the bow deck.
    from ship_kit import add_jib

    stay_low = (0.0, 1.335, -3.34)
    stay_high = (0.0, fore_deck + 2.55 - 0.04, -1.22)
    add_jib(
        "Sail_jib_bowsprit",
        canvas,
        stay_low,
        stay_high,
        clew=(0.0, 0.94, -1.78),
        luff_start=0.02,
        luff_end=0.80,
        billow=0.16,
        sheet_offset=0.07,
    )


def add_rigging(materials):
    # Stylized standing rigging: stays, backstays, shrouds, lifts — silhouette
    # support, not rope simulation. Routes chosen to clear the filled sails;
    # the fore topmast stay doubles as the jib's luff line.
    rope = materials["rope"]

    def bulwark_anchor(z, side):
        x, y, _ = side_point(z, side, 1.0, 0.05)
        return (x, y + 0.10, z)

    def qdeck_rail_anchor(z, side):
        x, _, _ = side_point(z, side, 1.0, 0.03)
        return (x, qdeck_y(z) + 0.11, z)

    fore_deck = mast_deck_y(-1.20)
    main_deck = mast_deck_y(-0.05)
    mizzen_deck = mast_deck_y(1.00)
    fore_head = fore_deck + 2.55
    fore_top = fore_deck + 2.55 * 0.60
    main_head = main_deck + 2.95
    main_top = main_deck + 2.95 * 0.60
    mizzen_head = mizzen_deck + 2.45

    fore = []
    fore.append(rope_points((0, fore_head - 0.04, -1.22), (0, 1.335, -3.34), 0.015))  # topmast stay = jib luff line (kept taut)
    fore.append(rope_points((0, fore_top - 0.10, -1.22), (0, 0.95, -2.58), 0.04))     # fore stay -> stem head / gammoning
    for side in (-1, 1):
        fore.append(rope_points((0, fore_head - 0.04, -1.20), bulwark_anchor(-0.58, side), 0.03))
        for z in (-1.52, -1.20, -0.88):
            fore.append(rope_points((0, fore_top - 0.10, -1.20), bulwark_anchor(z, side), 0.012))
        fore.append(rope_points((0, fore_deck + 2.55 * 0.47 + 0.03, -1.20), (side * 0.725, fore_deck + 2.55 * 0.47, -1.20), 0.015))
    add_rope_bundle("Rigging_fore", fore, 0.010, rope)

    main = []
    main.append(rope_points((0, main_top - 0.12, -0.07), (0, fore_top - 0.10, -1.18), 0.05))   # main stay -> fore top
    main.append(rope_points((0, main_head - 0.04, -0.07), (0, fore_top + 0.02, -1.18), 0.05))  # main topmast stay -> fore top
    for side in (-1, 1):
        main.append(rope_points((0, main_head - 0.04, -0.05), bulwark_anchor(0.62, side), 0.03))
        for z in (-0.40, -0.05, 0.30):
            main.append(rope_points((0, main_top - 0.12, -0.05), bulwark_anchor(z, side), 0.012))
        main.append(rope_points((0, main_deck + 2.95 * 0.47 + 0.03, -0.05), (side * 0.895, main_deck + 2.95 * 0.47, -0.05), 0.015))
    add_rope_bundle("Rigging_main", main, 0.010, rope)

    mizzen = []
    mizzen.append(rope_points((0, mizzen_head - 0.05, 0.98), (0, 0.70, 0.06), 0.05))  # mizzen stay -> main deck partner
    for side in (-1, 1):
        # Shrouds anchor FORWARD of the mast on the main-deck bulwark so they
        # angle away from the aft-raked lateen canvas (the galleon's lesson).
        for z in (0.52, 0.80):
            mizzen.append(rope_points((0, mizzen_deck + 2.45 * 0.60 - 0.10, 1.00), bulwark_anchor(z, side), 0.012))
        mizzen.append(rope_points((0, mizzen_head - 0.05, 1.02), qdeck_rail_anchor(2.10, side), 0.03))  # backstay, above the yard
    mizzen.append(rope_points((0, mizzen_deck + 2.45 * 0.55 + 0.60, 1.66), (0, 1.20, 2.38), 0.02))  # lateen peak lift -> taffrail
    mizzen.append(rope_points((0, mizzen_deck + 2.45 * 0.55 - 0.58, 0.37), (0, 0.70, 0.40), 0.02))  # lateen tack downhaul -> deck
    mizzen.append(rope_points((0, 1.30, 1.90), (0.30, 0.99, 2.12), 0.02))                            # lateen sheet -> quarterdeck
    add_rope_bundle("Rigging_mizzen", mizzen, 0.010, rope)

    bowsprit = []
    bowsprit.append(rope_points((0, 1.28, -3.24), (0, 0.10, -2.28), 0.03))            # bobstay -> stem
    for side in (-1, 1):
        bowsprit.append(rope_points((0, 1.30, -3.28), (side * 0.26, 0.45, -2.08), 0.025))  # shroud -> hull skin
    add_rope_bundle("Rigging_bowsprit", bowsprit, 0.009, rope)


def add_flags_and_anchors(materials):
    # Masthead streamers (restrained: shorter than the galleon's); the faction
    # flag itself stays procedural in Godot — the model only ships anchor
    # empties for the runtime flag and fire-effect systems.
    streamer = materials["streamer"]
    fore_head = mast_deck_y(-1.20) + 2.55
    main_head = mast_deck_y(-0.05) + 2.95
    mizzen_head = mast_deck_y(1.00) + 2.45

    add_streamer("Streamer_fore", (0, fore_head + 0.05, -1.17), 0.38, 0.060, streamer)
    add_streamer("Streamer_main", (0, main_head + 0.05, -0.02), 0.50, 0.070, streamer)
    add_streamer("Streamer_mizzen", (0, mizzen_head + 0.05, 1.03), 0.32, 0.055, streamer)

    # Flag anchors: ensign on the transom staff, pennant at the main masthead.
    # Fire anchors keep the gameplay-tuned visual_states positions from
    # ship_visual_profiles.yaml (frigate_basic deck_fire_main / sail_fire_main).
    add_anchor_empty("Anchor_Flag_Stern", (0.0, 1.90, 2.57))
    add_anchor_empty("Anchor_Flag_Main", (0.0, main_head + 0.06, -0.05))
    add_anchor_empty("Anchor_Fire_Deck", (0.0, 0.95, 0.0))
    add_anchor_empty("Anchor_Fire_Sail", (0.0, 2.10, -0.05))


MAST_ASSEMBLIES = {"fore": "ForemastAssembly", "main": "MainmastAssembly", "mizzen": "MizzenAssembly", "bowsprit": "BowspritAssembly"}

ASSEMBLY_TREE = {
    "Hull": ["HullMesh", "Deck", "Sterncastle", "Railings", "Gunports", "Cannons"],
    "ForemastAssembly": [],
    "MainmastAssembly": [],
    "MizzenAssembly": [],
    "BowspritAssembly": [],
    "Flags": [],
    "EffectsAnchors": [],
}


def classify_ship_object(name):
    n = name.lower()
    # Frigate-specific rules first, then the kit's cross-ship prefixes.
    # The quarterdeck platform/bulwarks/steps live under Deck (they are deck
    # architecture); the transom panel, windows, and ensign staff take the
    # contract's Sterncastle slot (same tree/names as the galleon).
    if n.startswith("transom_"):
        return "Sterncastle"
    if n.startswith(("quarterdeck_bulwark_cap_rail", "quarterdeck_bulwark_gold_deckline")):
        return "Railings"
    if n.startswith(("bow_head_rail",)):
        return "Railings"
    common = classify_common(n, MAST_ASSEMBLIES)
    if common is not None:
        return common
    if n.startswith(("hull_", "wood_plank_line_", "gold_hull_sheer_", "bow_")):
        return "HullMesh"
    return None


def organize_assemblies():
    def mast_deck_point(z):
        return (0.0, mast_deck_y(z), z)

    assembly_locations = {
        "ForemastAssembly": mast_deck_point(-1.20),
        "MainmastAssembly": mast_deck_point(-0.05),
        "MizzenAssembly": mast_deck_point(1.00),
        "BowspritAssembly": (0.0, 0.82, -2.40),
    }
    organize_assemblies_from("Frigate", ASSEMBLY_TREE, assembly_locations, classify_ship_object)


def build_materials():
    return {
        # Near-black hull oak: the "built in a hurry to catch something" ship.
        "dark_wood": wood_mat("near-black hull oak with grain", (0.055, 0.042, 0.030, 1), (0.115, 0.085, 0.058, 1), (0.018, 0.014, 0.010, 1)),
        "wood": wood_mat("warm frigate deck wood", (0.36, 0.235, 0.115, 1), (0.52, 0.335, 0.16, 1), (0.11, 0.058, 0.028, 1)),
        # Deep navy band: the frigate's ownable color (galleon owns burgundy).
        "navy_paint": paint_mat("deep navy satin paint", (0.035, 0.062, 0.140, 1), (0.062, 0.102, 0.210, 1), (0.014, 0.024, 0.062, 1)),
        # Oxblood stays for gunport reveals only (kit gunports read materials["red_paint"]).
        "red_paint": paint_mat("dark oxblood port reveal", (0.30, 0.045, 0.035, 1), (0.40, 0.075, 0.055, 1), (0.16, 0.020, 0.016, 1)),
        "gold": gold_mat("restrained aged gold trim"),
        "black": mat("visible warm shadow black", (0.035, 0.027, 0.020, 1), 0.82),
        # Neutral/whitish so ShipVisualBuilder's per-faction tint reads (ADR 0010).
        "sail": mat("neutral sail canvas", (0.91, 0.88, 0.80, 1), 0.90),
        "rope": mat("tarred hemp rope", (0.20, 0.14, 0.09, 1), 0.92),
        "streamer": mat("bright banner red", (0.72, 0.08, 0.06, 1), 0.62),
    }


def render_level(path, camera_location, target, ortho_scale):
    # Kit render_to tracks the camera up toward world Z (a quirk the galleon
    # renders inherited: angled shots come out rolled). This keeps the horizon
    # level — world +Y up — for the frigate's angled review shots.
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
        # F1 silhouette check: naked hull + decks/quarterdeck/transom masses.
        deck_z = [2.40, 2.20, 1.96, 1.64, 1.28, 0.92, 0.56, 0.20, -0.16, -0.52, -0.88, -1.24, -1.60, -1.96, -2.20, -2.42]
        add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
        add_quarterdeck(materials)
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
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT_DIR / "frigate_working.blend"))

    if STAGE == "hull":
        # F1 framing: tight on the naked hull so the sheer line fills the frame.
        render_to(OUT_DIR / "frigate_hull_primary.png", (-8.2, 0.75, -0.15), (0, 0.55, -0.15), 7.9, 90.0)
        render_level(OUT_DIR / "frigate_hull_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.60, -0.05), 8.6)
        render_level(OUT_DIR / "frigate_hull_stern_angle.png", (-6.1, 3.2, 6.2), (0, 0.70, 0.72), 6.8)
        render_level(OUT_DIR / "frigate_hull_bow_readability_angle.png", (6.3, 3.3, -6.4), (0, 0.65, -0.72), 6.8)
        render_clay(OUT_DIR / "frigate_hull_clay_side.png", (-8.2, 0.75, -0.15), (0, 0.55, -0.15), 7.2, 90.0)
    else:
        render_to(OUT_DIR / "frigate_primary.png", (-8.2, 1.35, -0.30), (0, 1.15, -0.30), 9.8, 90.0)
        render_level(OUT_DIR / "frigate_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.80, -0.05), 10.2)
        render_level(OUT_DIR / "frigate_stern_angle.png", (-6.1, 3.2, 6.2), (0, 0.90, 0.72), 7.6)
        render_level(OUT_DIR / "frigate_bow_readability_angle.png", (6.3, 3.3, -6.4), (0, 0.85, -0.90), 8.6)
        render_level(OUT_DIR / "frigate_bow_close.png", (4.5, 1.95, -5.0), (0, 0.90, -2.20), 3.6)
        render_clay(OUT_DIR / "frigate_clay_inspection.png", (-8.2, 1.35, -0.30), (0, 1.15, -0.30), 9.8, 90.0)


if __name__ == "__main__":
    main()
