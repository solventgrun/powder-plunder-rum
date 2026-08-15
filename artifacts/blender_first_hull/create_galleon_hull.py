"""Galleon visual asset generator (pilot ship of the ship pipeline).

Ship-agnostic machinery lives in artifacts/ship_kit; this file owns only the
galleon: its station profile, hull decoration, sterncastle, sail plan, rigging
routes, streamers/anchors, classification rules, and review renders.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

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
    add_stern_gallery_tier,
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
from ship_kit import create_hull as kit_create_hull

OUT_DIR = Path(__file__).resolve().parent


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

    # Handrails start on a bottom newel, ride balusters planted in every tread,
    # and run on aft to hand off to the balcony rail at the stair opening.
    outer_rail_pts = [(side * (x_abs + width * 0.50), y + 0.15, z) for x_abs, y, z, width in steps]
    outer_rail_pts.append((side * 0.70, 1.955, 1.86))
    add_polyline(f"stern_stair_curved_outer_wood_handrail_{side}", outer_rail_pts, 0.026, dark)
    inner_rail_pts = [(side * (x_abs - width * 0.48), y + 0.12, z) for x_abs, y, z, width in steps]
    inner_rail_pts.append((side * 0.40, 1.945, 1.85))
    add_polyline(f"stern_stair_curved_inner_wood_handrail_{side}", inner_rail_pts, 0.022, dark)
    add_polyline(
        f"stern_stair_gold_handrail_face_{side}",
        [(x, y + 0.030, z) for x, y, z in outer_rail_pts],
        0.007,
        gold,
    )
    for i, (x_abs, y, z, width) in enumerate(steps):
        outer_x = side * (x_abs + width * 0.50)
        inner_x = side * (x_abs - width * 0.48)
        add_cylinder_between(f"stern_stair_outer_baluster_{side}_{i}", (outer_x, y + 0.028, z), (outer_x, y + 0.15, z), 0.011, dark, 8)
        add_cylinder_between(f"stern_stair_inner_baluster_{side}_{i}", (inner_x, y + 0.028, z), (inner_x, y + 0.12, z), 0.010, dark, 8)
    x0_abs, y0, z0, w0 = steps[0]
    newel_x = side * (x0_abs + w0 * 0.50)
    add_cylinder_between(f"stern_stair_bottom_newel_{side}", (newel_x, y0 - 0.14, z0), (newel_x, y0 + 0.17, z0), 0.020, dark, 10)
    add_ellipsoid(f"stern_stair_bottom_newel_gold_cap_{side}", (newel_x, y0 + 0.185, z0), (0.020, 0.014, 0.020), gold, 10, 4)


def add_second_level_balcony(materials):
    dark = materials["dark_wood"]
    gold = materials["gold"]
    wood = materials["wood"]
    # A distinct railed balcony across the sterncastle's second level: an
    # overhanging plank deck on knee brackets with a perimeter rail. The stair
    # handrails hand off to the outer rail at the side openings, so the fall
    # barrier is continuous from deck bulwark to stair to balcony.
    add_cube("Balcony_second_level_plank_deck", (0, 1.685, 2.00), (1.44, 0.050, 0.34), wood, 0.010)
    add_cube("Balcony_front_gold_nosing", (0, 1.716, 1.842), (1.40, 0.014, 0.026), gold, 0.004)
    add_cube("Balcony_front_dark_fascia", (0, 1.60, 1.855), (1.42, 0.125, 0.035), dark, 0.010)
    for side in (-1, 1):
        add_cube(f"Balcony_side_dark_fascia_{side}", (side * 0.685, 1.60, 2.005), (0.055, 0.125, 0.325), dark, 0.010)
        for z in (1.92, 2.10):
            add_cylinder_between(f"Balcony_knee_bracket_{side}_{z}", (side * 0.485, 1.46, z), (side * 0.665, 1.645, z), 0.020, dark, 8)
        for i, (x, z) in enumerate([(side * 0.70, 1.86), (side * 0.70, 2.13)]):
            add_cylinder_between(f"Balcony_outer_rail_post_{side}_{i}", (x, 1.700, z), (x, 1.955, z), 0.020, dark, 10)
            add_ellipsoid(f"Balcony_outer_rail_gold_cap_{side}_{i}", (x, 1.970, z), (0.018, 0.012, 0.018), gold, 10, 4)
        # Outer rail runs aft along the balcony edge, then returns into the
        # castle wall so nobody can slip off behind it.
        outer_top = [(side * 0.70, 1.955, 1.86), (side * 0.70, 1.955, 2.13), (side * 0.30, 1.955, 2.22)]
        outer_mid = [(side * 0.70, 1.835, 1.86), (side * 0.70, 1.835, 2.13), (side * 0.30, 1.835, 2.22)]
        add_polyline(f"Balcony_outer_top_rail_{side}", outer_top, 0.024, dark)
        add_polyline(f"Balcony_outer_mid_rail_{side}", outer_mid, 0.014, dark)
    # Front rail between the two stair openings guards the drop to the deck.
    for x in (-0.40, -0.13, 0.13, 0.40):
        add_cylinder_between(f"Balcony_front_rail_post_{x}", (x, 1.700, 1.85), (x, 1.955, 1.85), 0.018, dark, 10)
        add_ellipsoid(f"Balcony_front_rail_gold_cap_{x}", (x, 1.970, 1.85), (0.016, 0.011, 0.016), gold, 10, 4)
    add_polyline("Balcony_front_top_rail", [(-0.40, 1.955, 1.85), (0.40, 1.955, 1.85)], 0.024, dark)
    add_polyline("Balcony_front_mid_rail", [(-0.40, 1.835, 1.85), (0.40, 1.835, 1.85)], 0.014, dark)


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


def add_bow_face_window(name, center, size, materials):
    # Ornate window for bow-facing sterncastle walls: pieces extend FORWARD
    # (-z) off the wall plane, so frames sit proud and the glass reads deep.
    x, y, wall_z = center
    width, height = size
    gold = materials["gold"]
    dark = materials["dark_wood"]
    black = materials["black"]
    red = materials["red_paint"]
    add_cube(f"{name}_red_surround", (x, y, wall_z - 0.000), (width * 1.52, height * 1.34, 0.036), red, 0.005)
    add_cube(f"{name}_dark_reveal", (x, y, wall_z - 0.004), (width * 1.18, height * 1.14, 0.036), dark, 0.004)
    add_cube(f"{name}_glass", (x, y, wall_z - 0.003), (width * 0.84, height * 0.84, 0.030), black, 0.003)
    add_cube(f"{name}_gold_mullion_v", (x, y, wall_z - 0.014), (0.011, height * 0.84, 0.016), gold, 0.002)
    add_cube(f"{name}_gold_mullion_h", (x, y + height * 0.10, wall_z - 0.014), (width * 0.84, 0.011, 0.016), gold, 0.002)
    add_cube(f"{name}_gold_lintel", (x, y + height * 0.62, wall_z - 0.008), (width * 1.60, 0.026, 0.044), gold, 0.004)
    add_cube(f"{name}_gold_sill", (x, y - height * 0.60, wall_z - 0.008), (width * 1.50, 0.022, 0.044), gold, 0.004)
    add_cube(f"{name}_gold_left_jamb", (x - width * 0.62, y, wall_z - 0.008), (0.020, height * 1.18, 0.040), gold, 0.003)
    add_cube(f"{name}_gold_right_jamb", (x + width * 0.62, y, wall_z - 0.008), (0.020, height * 1.18, 0.040), gold, 0.003)
    add_ellipsoid(f"{name}_gold_pediment_crown", (x, y + height * 0.72, wall_z - 0.024), (width * 0.66, 0.024, 0.020), gold, 12, 6)


def add_bow_face_door(name, center, size, materials):
    # Ornate double door for bow-facing sterncastle walls: paneled dark
    # leaves in a gold architrave under a small entablature and cornice.
    x, y, wall_z = center
    width, height = size
    gold = materials["gold"]
    dark = materials["dark_wood"]
    black = materials["black"]
    red = materials["red_paint"]
    add_cube(f"{name}_red_surround", (x, y, wall_z - 0.000), (width * 1.62, height * 1.24, 0.036), red, 0.005)
    add_cube(f"{name}_dark_double_leaf", (x, y, wall_z - 0.010), (width, height, 0.040), dark, 0.005)
    add_cube(f"{name}_leaf_split_shadow", (x, y, wall_z - 0.031), (0.009, height * 0.92, 0.010), black, 0.002)
    for lx in (-1, 1):
        add_cube(f"{name}_leaf_panel_upper_{lx}", (x + lx * width * 0.24, y + height * 0.22, wall_z - 0.030), (width * 0.30, height * 0.30, 0.012), black, 0.002)
        add_cube(f"{name}_leaf_panel_lower_{lx}", (x + lx * width * 0.24, y - height * 0.22, wall_z - 0.030), (width * 0.30, height * 0.30, 0.012), black, 0.002)
        add_ellipsoid(f"{name}_gold_handle_{lx}", (x + lx * width * 0.11, y - height * 0.03, wall_z - 0.034), (0.010, 0.010, 0.008), gold, 8, 4)
    add_cube(f"{name}_gold_left_jamb", (x - width * 0.60, y, wall_z - 0.008), (0.022, height * 1.10, 0.044), gold, 0.003)
    add_cube(f"{name}_gold_right_jamb", (x + width * 0.60, y, wall_z - 0.008), (0.022, height * 1.10, 0.044), gold, 0.003)
    add_cube(f"{name}_gold_entablature", (x, y + height * 0.60, wall_z - 0.008), (width * 1.55, 0.030, 0.048), gold, 0.004)
    add_cube(f"{name}_dark_cornice", (x, y + height * 0.69, wall_z - 0.004), (width * 1.40, 0.026, 0.056), dark, 0.004)
    add_cube(f"{name}_gold_threshold", (x, y - height * 0.56, wall_z - 0.006), (width * 1.30, 0.020, 0.048), gold, 0.003)


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
    # Stern counter: fairs the hull's rising stern top into the transom base so
    # the castle reads as growing out of the hull instead of hovering behind it.
    add_tapered_box("Sterncastle_stern_counter_fairing", (0, 1.02, 2.52), 1.06, 1.16, 0.24, 0.36, red, 0.028)
    add_cube("Sterncastle_counter_shadow_tuck", (0, 0.89, 2.48), (1.02, 0.040, 0.30), black, 0.010)


def add_flags_and_anchors(materials):
    # Streamers fly aft off the mastheads like the concept sheet's banners.
    # The faction flag itself stays procedural in Godot (ADR 0010) — the model
    # only ships anchor empties for the runtime flag and fire-effect systems.
    streamer = materials["streamer"]

    def add_streamer(name, root, length, height):
        root_v = Vector(root)

        def fn(u, v):
            z = root_v.z + u * length
            y = root_v.y - u * length * 0.16 + 0.055 * math.sin(math.pi * 2.1 * u) * u + (v - 0.5) * height * (1.0 - 0.55 * u)
            x = root_v.x + 0.05 * math.sin(math.pi * 2.6 * u + 0.8) * u
            return (x, y, z)

        add_sail(name, fn, streamer, nx=16, ny=2)

    add_streamer("Streamer_fore", (0, 3.44, -1.05), 0.46, 0.070)
    add_streamer("Streamer_main", (0, 3.91, -0.02), 0.60, 0.080)
    add_streamer("Streamer_mizzen", (0, 3.35, 1.08), 0.40, 0.062)

    def anchor(name, loc):
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_size = 0.06
        empty.location = loc
        bpy.context.collection.objects.link(empty)

    # Flag anchors: ensign on the ornamental stern mast, pennant at the main
    # masthead. Fire anchors keep the gameplay-tuned visual_states positions
    # from ship_visual_profiles.yaml (deck_fire_main / sail_fire_main).
    anchor("Anchor_Flag_Stern", (0.0, 3.34, 2.54))
    anchor("Anchor_Flag_Main", (0.0, 3.96, -0.05))
    anchor("Anchor_Fire_Deck", (0.0, 1.05, 0.12))
    anchor("Anchor_Fire_Sail", (0.0, 2.35, -0.05))


def add_rigging(materials):
    # Stylized standing rigging: major stays, backstays, shrouds, yard lifts,
    # and bowsprit gear only — silhouette support, not rope simulation. Routes
    # are chosen to clear the filled sails (the main stay ends at the fore
    # masthead instead of the bow so it cannot pierce the fore course; the
    # bobstay starts mid-bowsprit, aft of the spritsail canvas).
    rope = materials["rope"]

    def bulwark_anchor(z, side):
        x, y, _ = side_point(z, side, 1.0, 0.05)
        return (x, y + 0.12, z)

    fore = []
    fore.append(rope_points((0, 3.39, -1.08), (0, 1.98, -3.18), 0.05))       # fore topmast stay -> bowsprit
    fore.append(rope_points((0, 2.27, -1.08), (0, 1.31, -2.52), 0.04))       # fore stay -> stem head
    for side in (-1, 1):
        fore.append(rope_points((0, 3.39, -1.08), bulwark_anchor(-0.45, side), 0.03))   # backstay
        for z in (-1.40, -1.08, -0.76):
            fore.append(rope_points((0, 2.27, -1.08), bulwark_anchor(z, side), 0.012))  # shrouds
        fore.append(rope_points((0, 2.30, -1.08), (side * 0.775, 2.019, -1.08), 0.015)) # course yard lift
    add_rope_bundle("Rigging_fore", fore, 0.010, rope)

    main = []
    main.append(rope_points((0, 2.54, -0.05), (0, 2.24, -1.02), 0.05))       # main stay -> fore masthead
    main.append(rope_points((0, 3.86, -0.05), (0, 2.32, -1.08), 0.05))       # main topmast stay -> fore top
    for side in (-1, 1):
        main.append(rope_points((0, 3.86, -0.05), bulwark_anchor(0.65, side), 0.03))    # backstay
        for z in (-0.40, -0.05, 0.30):
            main.append(rope_points((0, 2.54, -0.05), bulwark_anchor(z, side), 0.012))  # shrouds
        main.append(rope_points((0, 2.57, -0.05), (side * 1.025, 2.224, -0.05), 0.015)) # course yard lift
    add_rope_bundle("Rigging_main", main, 0.010, rope)

    mizzen = []
    mizzen.append(rope_points((0, 3.30, 1.05), (0, 1.15, 0.10), 0.05))       # mizzen stay -> main deck partner
    mizzen.append(rope_points((0, 3.30, 1.05), (0, 2.84, 2.50), 0.03))       # stern stay -> sterncastle roof
    for side in (-1, 1):
        # Shrouds land forward of the stern staircase foot (its treads climb
        # z 0.74-1.86 beside the quarterdeck; a bulwark anchor aft of that
        # runs the rope straight through the treads and handrails).
        mizzen.append(rope_points((0, 2.24, 1.05), bulwark_anchor(0.66, side), 0.012))
        # Aft support becomes a backstay landing on the balcony corner
        # stanchion top — well above the staircase.
        mizzen.append(rope_points((0, 2.24, 1.05), (side * 0.70, 1.96, 2.13), 0.03))
    mizzen.append(rope_points((0, 3.28, 1.05), (0, 2.86, 1.78), 0.02))       # lateen peak lift
    mizzen.append(rope_points((0, 1.63, 0.40), (0, 0.92, 0.34), 0.02))       # lateen tack downhaul
    mizzen.append(rope_points((0, 1.74, 1.68), (0.32, 1.94, 2.16), 0.03))    # lateen sheet -> balcony rail
    add_rope_bundle("Rigging_mizzen", mizzen, 0.010, rope)

    bowsprit = []
    bowsprit.append(rope_points((0, 1.63, -2.90), (0, 0.20, -2.35), 0.03))   # bobstay, aft of the spritsail
    for side in (-1, 1):
        bowsprit.append(rope_points((side * 0.475, 1.84, -3.06), (side * 0.48, 0.60, -2.05), 0.03))  # sprit yard guy
        bowsprit.append(rope_points((0, 2.12, -3.36), (side * 0.475, 1.85, -3.06), 0.015))           # sprit yard lift
    add_rope_bundle("Rigging_bowsprit", bowsprit, 0.009, rope)


def add_sails(materials):
    # Healthy sail set, moderately filled with wind (baked shape — runtime
    # deformation is out of scope for the alpha, topology supports it later).
    # Square sails billow bow-ward (-Z, the runtime wind convention); the
    # mizzen lateen billows to starboard, perpendicular to its fore-aft plane.
    canvas = materials["sail"]

    def square_sail(name, z_mast, yard_y, foot_y, width_head, width_foot, depth, foot_arc):
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

        add_sail(name, fn, canvas)

    fore_deck = side_point(-1.08, 1, 0.985, -0.020)[1]
    main_deck = side_point(-0.05, 1, 0.985, -0.020)[1]
    mizzen_deck = side_point(1.05, 1, 0.985, -0.020)[1]

    square_sail("Sail_course_fore", -1.08, fore_deck + 2.70 * 0.47, 1.28, 1.44, 1.44, 0.34, 0.14)
    square_sail("Sail_topsail_fore", -1.08, fore_deck + 2.70 * 0.90, fore_deck + 2.70 * 0.62, 0.88, 1.07, 0.26, 0.10)
    square_sail("Sail_course_main", -0.05, main_deck + 3.20 * 0.47, 1.38, 1.92, 1.92, 0.40, 0.15)
    square_sail("Sail_topsail_main", -0.05, main_deck + 3.20 * 0.90, main_deck + 3.20 * 0.62, 1.15, 1.40, 0.30, 0.11)
    square_sail("Sail_sprit_bowsprit", -3.045, 1.84, 1.34, 0.82, 0.86, 0.15, 0.07)

    # Lateen: a triangular sheet whose head lies along the raked yard, leech
    # dropping from the peak to a clew held forward of the sterncastle front.
    mizzen_cross = mizzen_deck + 2.55 * 0.55
    yard_low = Vector((0.0, mizzen_cross - 0.68, 1.05 - 0.755))
    yard_high = Vector((0.0, mizzen_cross + 0.68, 1.05 + 0.755))
    tack = yard_low.lerp(yard_high, 0.06)
    peak = yard_low.lerp(yard_high, 0.95)
    clew = Vector((0.0, 1.72, 1.70))
    foot_start = tack.lerp(clew, 0.04)

    def lateen_fn(u, v):
        head = tack.lerp(peak, u)
        foot = foot_start.lerp(clew, u)
        base = head.lerp(foot, v)
        billow = 0.20 * math.sin(math.pi * u) * math.sin(math.pi * v * 0.72)
        arc = 0.07 * math.sin(math.pi * u) * (v ** 2)
        return (base.x + billow, base.y + arc, base.z)

    add_sail("Sail_lateen_mizzen", lateen_fn, canvas)


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


FORM = HullForm(station_profile())


def side_point(z, side, t, offset=0.0):
    return FORM.side_point(z, side, t, offset)


def hull_surface_frame(z, side, t):
    return FORM.surface_frame(z, side, t)


def create_hull(materials):
    return kit_create_hull(FORM, materials, mesh_name="GalleonHullMesh", object_name="Hull_curved_galleon_body")


def decorate_hull(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    red = materials["red_paint"]
    gold = materials["gold"]
    black = materials["black"]

    # Horizontal planking and ornate gold strakes. Lines ride the exact hull
    # skin, and their heights are chosen to run BETWEEN the gunport rows
    # (lower ports span roughly t 0.35-0.52, upper ports t 0.58-0.75).
    for side in (-1, 1):
        for t in (0.16, 0.27, 0.38, 0.49, 0.60):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.004))
            add_polyline(f"wood_plank_line_{side}_{t:.2f}", pts, 0.008, dark)
        for t, radius in ((0.55, 0.012), (0.78, 0.010), (0.88, 0.015), (0.98, 0.012)):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.006))
            add_polyline(f"gold_hull_sheer_{side}_{t:.2f}", pts, radius, gold)

    # Deck insert, red gun band, and raised castles.
    # Runs all the way aft under the sterncastle so top-down views never see
    # into the open hull shell beside the castle walls.
    deck_z = [2.62, 2.48, 2.34, 1.96, 1.58, 1.20, 0.82, 0.44, 0.06, -0.32, -0.70, -1.08, -1.46, -1.84, -2.22, -2.58]
    add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
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
        1.02, 1.56, 1.72, 2.66,
        1.08, 1.16, 0.98, 1.08,
        red, 0.035,
    )
    add_cube("Sterncastle_lower_internal_floor_band", (0, 1.56, 2.14), (0.98, 0.060, 0.38), dark, 0.016)
    add_cube("Sterncastle_lower_gold_gallery_sill", (0, 1.16, 2.14), (0.88, 0.022, 0.36), gold, 0.006)
    add_cube("Sterncastle_second_level_dark_support_fascia", (0, 1.58, 2.18), (0.82, 0.085, 0.36), dark, 0.012)
    for x in [-0.34, -0.12, 0.12, 0.34]:
        add_cylinder_between(f"Sterncastle_second_level_short_support_post_{x}", (x, 1.50, 2.26), (x, 1.66, 2.26), 0.018, dark, 10)
    add_stern_gallery_tier(
        "Sterncastle_middle_raked_window_gallery",
        1.56, 2.42, 2.16, 2.66,
        0.78, 1.02, 0.66, 0.86,
        red, 0.030,
    )
    add_second_level_balcony(materials)
    add_cube("Sterncastle_middle_internal_floor_band", (0, 2.03, 2.28), (0.66, 0.044, 0.26), dark, 0.010)
    add_cube("Sterncastle_middle_upper_walk_band", (0, 2.42, 2.28), (0.62, 0.052, 0.24), dark, 0.012)
    add_cube("Sterncastle_middle_gold_sill", (0, 1.65, 2.28), (0.62, 0.018, 0.22), gold, 0.005)
    add_cube("Sterncastle_upper_captain_gallery_flat_block", (0, 2.58, 2.57), (0.34, 0.24, 0.16), red, 0.026)
    add_cube("Sterncastle_upper_captain_gallery_front_face", (0, 2.43, 2.49), (0.30, 0.036, 0.018), red, 0.006)
    add_cube("Sterncastle_upper_internal_cap", (0, 2.72, 2.56), (0.34, 0.060, 0.18), dark, 0.010)
    add_cube("Sterncastle_roof_dark_wood", (0, 2.80, 2.56), (0.38, 0.076, 0.20), dark, 0.014)
    add_cube("Sterncastle_subtle_dark_pediment", (0, 2.91, 2.56), (0.24, 0.070, 0.08), dark, 0.010)
    add_cylinder_between("Sterncastle_top_ornamental_mast", (0, 2.78, 2.54), (0, 3.30, 2.54), 0.040, dark, 16)
    add_cylinder_between("Sterncastle_top_gold_mast_band", (-0.065, 3.02, 2.54), (0.065, 3.02, 2.54), 0.010, gold, 8)
    for y, width, depth, zc in [(1.22, 0.86, 0.30, 2.36), (1.74, 0.62, 0.20, 2.46), (2.42, 0.30, 0.12, 2.56)]:
        add_cube(f"stern_gallery_shadowed_undercut_{y}", (0, y, zc), (width, 0.045, depth), materials["black"], 0.012)

    # Gun ports with red lips and black interiors.
    lower_ports = [2.04, 1.68, 1.32, 0.96, 0.60, 0.24, -0.12, -0.48, -0.84, -1.20, -1.56, -1.92]
    upper_ports = [1.76, 1.30, 0.84, 0.38, -0.08, -0.54, -1.00, -1.46]
    for side in (-1, 1):
        for i, z in enumerate(lower_ports):
            add_side_gunport(FORM, f"lower_gundeck_port_{side}_{i}", side, z, 0.43, materials, size=0.178)
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.43)
            add_cylinder_between(f"lower_deck_cannon_{side}_{i}", tuple(origin - e_x * 0.06), tuple(origin + e_x * 0.11), 0.024, black, 12)
        for i, z in enumerate(upper_ports):
            add_side_gunport(FORM, f"upper_gundeck_port_{side}_{i}", side, z, 0.66, materials, size=0.168)
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.66)
            add_cylinder_between(f"upper_deck_cannon_{side}_{i}", tuple(origin - e_x * 0.06), tuple(origin + e_x * 0.10), 0.021, black, 12)

    # Stern windows and structural columns: tall rectangles so they do not read as gunports.
    # Bow face of the sterncastle: an ornate balcony door flanked by framed
    # windows on the second level, and a cabin door with windows at deck
    # level, all built proud toward the bow off their wall planes.
    add_bow_face_door("stern_bow_face_balcony_door", (0.0, 1.90, 2.16), (0.17, 0.34), materials)
    for col, x in enumerate([-0.245, 0.245]):
        add_bow_face_window(f"stern_bow_face_second_level_window_{col}", (x, 1.97, 2.16), (0.085, 0.19), materials)
    add_cube("stern_bow_face_second_level_dark_lintel", (0, 2.155, 2.145), (0.62, 0.028, 0.040), dark, 0.006)
    add_bow_face_door("stern_deck_level_cabin_door", (0.0, 1.19, 1.61), (0.20, 0.32), materials)
    for col, x in enumerate([-0.30, 0.30]):
        add_bow_face_window(f"stern_deck_level_cabin_window_{col}", (x, 1.22, 1.61), (0.080, 0.15), materials)
    for row, (y, xs, height) in enumerate([
        (1.34, [-0.32, -0.16, 0.0, 0.16, 0.32], 0.18),
        (1.86, [-0.24, -0.08, 0.08, 0.24], 0.20),
        (2.18, [-0.22, -0.07, 0.07, 0.22], 0.20),
    ]):
        for col, x in enumerate(xs):
            add_rect_stern_window(f"stern_rect_window_{row}_{col}", (x, y, 2.64), (0.080, height), materials)
    add_stern_door("stern_middle_gallery_door", (0.0, 1.62, 2.645), (0.13, 0.30), materials)
    add_stern_door("stern_upper_gallery_door", (0.0, 2.00, 2.645), (0.12, 0.28), materials)
    for x in [-0.48, -0.30, -0.10, 0.10, 0.30, 0.48]:
        add_cylinder_between(f"stern_heavy_dark_gallery_column_{x}", (x, 1.12, 2.61), (x * 0.72, 2.42, 2.66), 0.020, dark, 12)
        add_cylinder_between(f"stern_thin_gold_column_face_{x}", (x, 1.13, 2.65), (x * 0.72, 2.42, 2.70), 0.006, gold, 8)
    for y, width in [(1.18, 1.10), (1.56, 1.08), (2.02, 0.90), (2.42, 0.72)]:
        add_cube(f"stern_horizontal_dark_gallery_beam_{y}", (0, y, 2.66), (width, 0.030, 0.050), dark, 0.007)
        add_cube(f"stern_horizontal_gold_gallery_face_{y}", (0, y + 0.020, 2.70), (width * 0.94, 0.010, 0.022), gold, 0.003)

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
        mid_rail = [(x, y - 0.14, z) for x, y, z in rail_pts]
        add_polyline(f"mid_rail_{side}", mid_rail, 0.018, dark)
        # The bulwark rail ends below the balcony's aft corner; a tall corner
        # stanchion carries the fall barrier up into the balcony rail instead
        # of the old returns that dove inboard toward the castle wall.
        add_cylinder_between(
            f"sterncastle_rail_corner_stanchion_{side}",
            (rail_pts[0][0], rail_pts[0][1] - 0.20, rail_pts[0][2]),
            (side * 0.70, 1.955, 2.13),
            0.026,
            dark,
            10,
        )

    # Full mast assemblies (heights match the galleon_basic visual profile so
    # the exported model stays drop-in for the existing gameplay slot).
    add_mast_assembly(
        FORM,
        "fore", -1.08, 2.70, 0.070, materials,
        square_yards=[("lower", 0.47, 1.55, 0.030), ("upper", 0.90, 1.18, 0.024)],
    )
    add_mast_assembly(
        FORM,
        "main", -0.05, 3.20, 0.085, materials,
        square_yards=[("lower", 0.47, 2.05, 0.034), ("upper", 0.90, 1.50, 0.027)],
    )
    add_mast_assembly(FORM, "mizzen", 1.05, 2.55, 0.060, materials, lateen=True)

    # Bowsprit, beakhead structure, and simple figurehead silhouette.
    add_cylinder_between("Bowsprit_dark_wood", (0, 1.28, -2.46), (0, 2.06, -3.30), 0.055, dark, 16)
    add_cylinder_between("Bowsprit_gold_tip", (0, 2.06, -3.30), (0, 2.18, -3.48), 0.04, gold, 16)
    # Sprit yard for the D3 spritsail, hung under the outer bowsprit.
    add_cylinder_between("Bowsprit_sprit_yard", (-0.475, 1.84, -3.06), (0.475, 1.84, -3.06), 0.022, dark, 12)
    add_cylinder_between("Bowsprit_sprit_yard_gold_collar", (0, 1.822, -3.041), (0, 1.858, -3.079), 0.062, gold, 12)
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

    # Gold rivets and rosettes: small enough to be charming, big enough to
    # read. Heights avoid the port rows and dividers sit at the midpoints
    # between upper ports so nothing bisects a gunport.
    for side in (-1, 1):
        for z in [1.5, 1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
            for t in [0.30, 0.55, 0.86]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                loc = origin + e_x * 0.010
                bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=4, radius=0.028, location=tuple(loc))
                rivet = bpy.context.object
                rivet.name = f"gold_rivet_{side}_{z}_{t}"
                rivet.scale.x = 0.55
                rivet.data.materials.append(gold)
        for z in [1.53, 1.07, 0.61, 0.15, -0.31, -0.77, -1.23]:
            frame = hull_surface_frame(z, side, 0.66)
            add_surface_cube(f"painted_hull_panel_divider_{side}_{z}", frame, (0.012, 0.0, 0.0), (0.030, 0.30, 0.028), gold, 0.006)


MAST_ASSEMBLIES = {"fore": "ForemastAssembly", "main": "MainmastAssembly", "mizzen": "MizzenAssembly", "bowsprit": "BowspritAssembly"}

# Godot-facing assembly tree (contract in docs/design/galleon-sails-rigging-plan.md).
# Hull children are the D6 join targets; empty groups today, one mesh each after
# the join pass. Assembly empties are the future per-mast hide/damage handles.
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
    # Galleon-specific rules first, then the kit's cross-ship prefixes.
    if n.startswith("sterncastle_rail_corner_stanchion"):
        # Part of the bulwark fall barrier, not the castle mass.
        return "Railings"
    if n.startswith(("sterncastle", "stern_", "balcony_")):
        return "Sterncastle"
    if n.startswith(("bow_deck_closing_heavy_cheek_rail", "bow_front_cross_rail")):
        return "Railings"
    common = classify_common(n, MAST_ASSEMBLIES)
    if common is not None:
        return common
    if n.startswith(("hull_", "wood_plank_line_", "gold_hull_sheer_", "bow_", "figurehead_", "gold_rivet_", "painted_hull_panel_divider_")):
        return "HullMesh"
    return None


def organize_assemblies():
    def mast_deck_point(z):
        _, deck_y, _ = side_point(z, 1, 0.985, -0.020)
        return (0.0, deck_y, z)

    # Useful pivots: mast assemblies at their deck partner, bowsprit at its root.
    assembly_locations = {
        "ForemastAssembly": mast_deck_point(-1.08),
        "MainmastAssembly": mast_deck_point(-0.05),
        "MizzenAssembly": mast_deck_point(1.05),
        "BowspritAssembly": (0.0, 1.28, -2.46),
    }
    organize_assemblies_from("Galleon", ASSEMBLY_TREE, assembly_locations, classify_ship_object)


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

2026-08-15 hull integration pass:

- buried the sterncastle base into the deck and moved the shared transom line
  aft of the hull's stern tip, with a new red counter fairing and shadow tuck,
  so the castle sides meet the hull instead of floating beside/over it
- shifted transom windows, doors, columns, beams, and the top tier stack aft
  to follow the new stern line
- connected the stair handrails: balusters planted in every tread, a bottom
  newel with gold cap, the outer rail runs on into the landing rail, and the
  inner rail terminates on a post at the landing
- footed the second-level rail posts on the landing and lower gallery roof
  with a shared level rail height
- rebuilt gunports as surface-oriented recessed assemblies that hug the local
  hull skin (shadow cut ring, thin architrave, sunken reveal/port faces), and
  aligned the upper-deck cannon barrels to fire through their port centers
  along the hull normal

2026-08-15 balcony and gunport consistency pass:

- gunport frames now sample the exact hull mesh skin (station vertex math with
  per-station sheer softener, lerped like the mesh faces) so every port sits
  at the same shallow recess depth instead of some floating and some burying
- replaced the stair landing and inward-curving second-level rail with a
  distinct railed balcony: overhanging plank deck on knee brackets, perimeter
  posts and rails, front rail guarding the drop, and side openings where the
  stair handrails arrive
- the bulwark rail now hands off to the balcony rail through a tall corner
  stanchion, keeping the fall barrier continuous deck-to-stair-to-balcony
- fixed the main deck mid rail floating above the top rail

2026-08-15 broadside and bow-face detail pass:

- moved the gold strake, rivet rows, and panel dividers so nothing bisects a
  gunport (strake 0.63 -> 0.55, rivet rows 0.34/0.60 -> 0.30/0.55, dividers
  re-seated at the midpoints between upper ports), and re-laid planking,
  strakes, rivets, and dividers on the exact hull skin so they no longer
  float off the wavy surface
- added lower gun deck cannon muzzles through the lower port centers
- rebuilt the sterncastle's bow-facing openings with dedicated forward-proud
  ornate assemblies: a paneled double balcony door with gold architrave,
  entablature, and handles, flanked windows with mullions, deep glass, and
  pediment crowns, plus a matching cabin door and windows at deck level

2026-08-15 assembly organization pass (plan deliverable D1):

- added organize_assemblies(): every generated object is parented (world
  transforms preserved) into the Godot-facing assembly tree from
  docs/design/galleon-sails-rigging-plan.md — Galleon root, Hull with
  HullMesh/Deck/Sterncastle/Railings/Gunports/Cannons join-target groups,
  Fore/Main/Mizzen mast assemblies (empties pivoted at their deck partners),
  BowspritAssembly, plus empty Flags and EffectsAnchors groups for D5
- classification is by name prefix; mast partner deck hardware deliberately
  stays under Deck so hiding a mast assembly leaves a plausible socket
- verified no visual change: post-pass renders match the pre-pass baseline

2026-08-15 masts and yards pass (plan deliverable D2):

- replaced the three mast stubs with full assemblies: tapered lower masts
  (new add_spar cone-frustum helper), round top platforms with gold rims,
  overlapping tapered topmasts with gold doubling bands, and gold masthead
  finials; heights match the galleon_basic profile (fore 2.70, main 3.20,
  mizzen 2.55 above deck) so the export stays drop-in for the gameplay slot
- course and topsail yards with gold slings on fore and main (sling radius
  derived from the local mast taper so it always encircles the mast), raked
  lateen yard on the mizzen overhanging the sterncastle, and a sprit yard
  with gold collar under the outer bowsprit
- the old gold mast band became a proper encircling ring instead of a bar

2026-08-15 healthy sails pass (plan deliverable D3):

- six deformable sail sheets (13x11 quad grids, smooth-shaded, thin solidify),
  each its own named object on the shared neutral canvas material:
  Sail_course_fore, Sail_topsail_fore, Sail_course_main, Sail_topsail_main,
  Sail_lateen_mizzen, Sail_sprit_bowsprit
- moderate wind fill is baked into the mesh: square sails billow bow-ward
  with depth zero at head/clews and deepest at the mid foot, topsails taper
  toward their heads, the lateen is a triangular sheet along the raked yard
  billowing to starboard with its clew held forward of the sterncastle front
- fill tuning after first render: billow peak moved to ~70% down the sail
  (foot keeps 77%), depths increased, course feet raised for clear air, and
  foot edges arc up between the clews so sails stop reading as flat cards

2026-08-15 rigging pass (plan deliverable D4):

- stylized standing rigging as four multi-spline curve objects (one per
  group, no per-rope objects): Rigging_fore, Rigging_main, Rigging_mizzen,
  Rigging_bowsprit — stays, backstays, three shrouds per side on fore/main,
  two on mizzen, course yard lifts, lateen peak lift/downhaul/sheet, bobstay
  and sprit yard guys/lifts; every rope has a light parabolic sag
- routes chosen to clear the filled sails: the main stay lands on the fore
  masthead instead of the bow (a bow run would pierce the fore course), the
  bobstay starts mid-bowsprit aft of the spritsail canvas, and sprit yard
  guys run from the yard tips outside the sail's width

2026-08-15 streamers and anchors pass (plan deliverable D5):

- three bright red masthead streamers (thin tapering ribbon grids with a
  baked aft-flying S-curl, matching the concept sheet's banners) under the
  Flags group: Streamer_fore, Streamer_main, Streamer_mizzen
- four anchor empties for the runtime systems: Anchor_Flag_Stern (ornamental
  stern mast) and Anchor_Flag_Main (main masthead) under Flags,
  Anchor_Fire_Deck and Anchor_Fire_Sail under EffectsAnchors at the
  gameplay-tuned visual_states positions from ship_visual_profiles.yaml

2026-08-15 shared ship kit extraction:

- moved the ship-agnostic machinery into artifacts/ship_kit (materials,
  primitives, HullForm hull math with skin/gunport/shaped-deck builders,
  mast assemblies, sail grids, rope bundles, assembly organization, the
  review lighting/render rig, and the GLB flatten/export helpers) so the
  next ship classes reuse it; this file now holds only galleon content
- verified zero visual change: post-extraction renders match the previous
  set pixel-for-pixel and the rebuilt GLB is structurally identical
"""
    (OUT_DIR / "reference_notes.md").write_text(text, encoding="utf-8")


def build_materials():
    return {
        "dark_wood": wood_mat("dark aged walnut with grain", (0.16, 0.095, 0.048, 1), (0.36, 0.20, 0.085, 1), (0.055, 0.032, 0.018, 1)),
        "wood": wood_mat("warm deck wood with grain", (0.45, 0.285, 0.13, 1), (0.64, 0.40, 0.18, 1), (0.15, 0.075, 0.032, 1)),
        "red_paint": paint_mat("deep burgundy satin paint", (0.40, 0.040, 0.032, 1), (0.54, 0.075, 0.055, 1), (0.22, 0.018, 0.016, 1)),
        "gold": gold_mat("bright aged gold trim"),
        "black": mat("visible warm shadow black", (0.035, 0.027, 0.020, 1), 0.82),
        # Neutral/whitish so ShipVisualBuilder's per-faction tint reads (ADR 0010).
        "sail": mat("neutral sail canvas", (0.91, 0.88, 0.80, 1), 0.90),
        "rope": mat("tarred hemp rope", (0.20, 0.14, 0.09, 1), 0.92),
        "streamer": mat("bright banner red", (0.72, 0.08, 0.06, 1), 0.62),
    }


def main():
    clear_scene()
    materials = build_materials()
    create_hull(materials)
    decorate_hull(materials)
    add_sails(materials)
    add_rigging(materials)
    add_flags_and_anchors(materials)
    organize_assemblies()
    setup_review_scene()

    blend_path = OUT_DIR / "first_pass_galleon_hull.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    render_to(OUT_DIR / "galleon_hull_refined_primary.png", (-8.2, 1.52, -0.42), (0, 1.05, -0.42), 10.60, 90.0)
    render_to(OUT_DIR / "galleon_hull_refined_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.88, -0.12), 10.75, 90.0)
    render_to(OUT_DIR / "galleon_hull_refined_stern_angle.png", (-6.1, 3.35, 6.2), (0, 1.05, 0.72), 8.1)

    render_to(OUT_DIR / "galleon_hull_refined_bow_readability_angle.png", (6.3, 3.45, -6.4), (0, 0.98, -0.72), 8.0)
    render_to(OUT_DIR / "galleon_hull_refined_bow_close.png", (4.5, 2.20, -5.0), (0, 0.98, -2.34), 3.8)
    render_clay(OUT_DIR / "galleon_hull_refined_clay_inspection.png", (-8.2, 1.52, -0.42), (0, 1.05, -0.42), 10.60, 90.0)
    write_reference_notes()


if __name__ == "__main__":
    main()
