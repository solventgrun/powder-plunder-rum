"""Sloop visual asset generator (fourth and last hull class through the pipeline).

Ship-agnostic machinery lives in artifacts/ship_kit; this file owns only the
sloop: its station profile, hull decoration, taffrail/transom, single-mast
gaff rig (the brig's ship-side gaff pattern, one mast), jib, rigging routes,
streamer/anchors, classification rules, and review renders.

Class character (docs/design/sloop-visual-brief.md): the dart — smallest,
fastest, most agile. One mast, gaff main with the boom past the transom, jib
to a proud bowsprit, flush deck with a tiller. Color per the user's "Rapide"
concept sheet (supersedes the brief's pale-oak recommendation): dark
charcoal-brown hull, warm ochre/gold-tan band as the sloop's ownable accent,
small navy stern panel with restrained gilt, muted red port lids, red
streamer. Kit "gold" slot renders as blackened iron (brig precedent) so
fittings stay workmanlike; true gilt only on stem cap, stern trim, and truck.

Env knobs for iteration:
  SLOOP_STAGE   hull | full   (default full)
  SLOOP_QUALITY draft | final (default final)
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

STAGE = os.environ.get("SLOOP_STAGE", "full")
QUALITY = os.environ.get("SLOOP_QUALITY", "final")


def station_profile():
    # z, half width, deck y, keel y. Forward is -Z, matching the Godot convention.
    # The smallest and flattest hull in the fleet: mid deck 0.455 vs the brig's
    # 0.535, rise of barely 0.065/0.075 at the ends — a dart, not a knife.
    # Keel depths: the shoal-draft experiment (~28% shallower) was reverted
    # at user request after proof review — the deep hull reads better.
    return [
        (1.75, 0.36, 0.520, -0.22),
        (1.45, 0.48, 0.505, -0.30),
        (1.10, 0.58, 0.490, -0.37),
        (0.70, 0.65, 0.475, -0.43),
        (0.25, 0.68, 0.460, -0.47),
        (-0.30, 0.66, 0.455, -0.46),
        (-0.80, 0.58, 0.462, -0.42),
        (-1.25, 0.45, 0.475, -0.34),
        (-1.70, 0.25, 0.495, -0.18),
        (-2.06, 0.045, 0.530, -0.02),
    ]


# Even flatter than the brig, with a shallow bow rake. Bow tip lands at
# z ~-2.14 per the brief's station guide.
FORM = HullForm(
    station_profile(),
    sheer_amplitude=0.018,
    stern_rake_last=(0.22, 0.08),
    stern_rake_previous=(0.08, 0.025),
)


def side_point(z, side, t, offset=0.0):
    return FORM.side_point(z, side, t, offset)


def hull_surface_frame(z, side, t):
    return FORM.surface_frame(z, side, t)


def create_hull(materials):
    # Dark charcoal-brown hull wearing a bounded ochre band (rows 8-11 of 14,
    # t 0.57-0.86, brig-proven bounds) that carries the four-port row.
    hull = kit_create_hull(
        FORM,
        materials,
        mesh_name="SloopHullMesh",
        object_name="Hull_curved_sloop_body",
        paint_material="ochre_paint",
        paint_from_row=8,
        paint_to_row=12,
    )
    # Brig-proven ship-side fixes: keep every cap face in base wood (the kit
    # paints the bow slivers with the band material) and reorient the inward-
    # wound cap faces so the exposed counter shades correctly.
    for poly in list(hull.data.polygons)[-2 * 14:]:
        if poly.material_index == 1:
            poly.material_index = 0
    recalc_outward_normals(hull.data)
    return hull


def add_transom(materials):
    navy = materials["navy_paint"]
    dark = materials["dark_wood"]
    counter = materials["counter_wood"]
    gilt = materials["gilt"]
    black = materials["black"]

    # Tiny flat transom: taffrail board, one small navy panel with a single
    # stern light, restrained gilt trim. The counter stack wears the darker
    # "shadowed counter" wood (aft faces blow out pale under the review rig).
    add_tapered_box("Transom_navy_panel", (0, 0.565, 1.73), 0.70, 0.62, 0.17, 0.10, navy, 0.012)
    add_tapered_box("Transom_dark_counter_fairing", (0, 0.40, 1.66), 0.74, 0.68, 0.16, 0.20, counter, 0.014)
    add_tapered_box("Transom_counter_planking", (0, 0.255, 1.68), 0.60, 0.72, 0.14, 0.18, counter, 0.012)
    add_cube("Transom_shadow_tuck", (0, 0.492, 1.735), (0.66, 0.026, 0.11), black, 0.006)

    # One stern light only — the brief's ceiling for this class.
    add_cube("Transom_light_recess", (0, 0.565, 1.786), (0.105, 0.115, 0.030), dark, 0.004)
    add_cube("Transom_light_glass", (0, 0.565, 1.797), (0.075, 0.082, 0.028), black, 0.003)
    add_cube("Transom_light_gilt_lintel", (0, 0.632, 1.792), (0.115, 0.012, 0.030), gilt, 0.003)

    add_cube("Transom_gilt_upper_moulding", (0, 0.657, 1.768), (0.60, 0.013, 0.040), gilt, 0.003)
    add_cube("Transom_dark_taffrail_cap", (0, 0.678, 1.762), (0.64, 0.030, 0.060), dark, 0.006)

    # Taffrail ensign staff; the runtime faction flag hangs from
    # Anchor_Flag_Stern near its head.
    add_cylinder_between("Transom_ensign_staff", (0, 0.66, 1.76), (0, 1.18, 1.90), 0.013, dark, 10)
    add_ellipsoid("Transom_ensign_staff_gilt_truck", (0, 1.19, 1.905), (0.011, 0.015, 0.011), gilt, 8, 4)


def decorate_hull(materials):
    wood = materials["wood"]
    dark = materials["dark_wood"]
    gilt = materials["gilt"]
    black = materials["black"]

    # Shaped main deck, full length, flush end to end (no half-deck).
    deck_z = [1.72, 1.55, 1.35, 1.12, 0.86, 0.58, 0.30, 0.02, -0.26, -0.54, -0.82, -1.10, -1.36, -1.60, -1.80, -1.96]
    add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
    add_cube("Deck_central_hatch_frame", (0, 0.515, 0.42), (0.32, 0.044, 0.24), dark, 0.012)
    add_cube("Deck_central_hatch_recess", (0, 0.540, 0.42), (0.23, 0.022, 0.16), black, 0.007)
    for x in (-0.08, 0.02):
        add_cube(f"Deck_hatch_slat_{x}", (x, 0.554, 0.42), (0.018, 0.014, 0.20), wood, 0.003)

    # Tiller instead of a wheel: rudder head at the taffrail, curved handle
    # sweeping forward over the aft deck.
    add_cube("Deck_tiller_rudder_head", (0, 0.545, 1.68), (0.075, 0.085, 0.075), dark, 0.008)
    add_polyline("Deck_tiller_curved_handle", [(0, 0.585, 1.66), (0, 0.625, 1.42), (0, 0.650, 1.20)], 0.019, dark)
    add_ellipsoid("Deck_tiller_dark_knob", (0, 0.652, 1.185), (0.024, 0.024, 0.024), dark, 8, 5)

    for side in (-1, 1):
        add_polyline(
            f"deck_edge_dark_cap_{side}",
            [(x, y + 0.048, z) for x, y, z in [side_point(z, side, 0.99, 0.004) for z in deck_z]],
            0.015,
            dark,
        )

    # Workboat hull graphics: three plank lines below the band, dark strakes
    # edging the ochre band, one black wale at the waterline. No gilt lines —
    # the sloop's gold budget lives at the stem and stern only.
    for side in (-1, 1):
        for t in (0.16, 0.30, 0.42):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.004))
            add_polyline(f"wood_plank_line_{side}_{t:.2f}", pts, 0.007, dark)
        for t in (0.571, 0.857):
            pts = []
            for z, *_ in station_profile()[1:-1]:
                origin, e_x, _, _ = hull_surface_frame(z, side, t)
                pts.append(tuple(origin + e_x * 0.005))
            add_polyline(f"ochre_band_edge_strake_{side}_{t:.2f}", pts, 0.008, dark)
        pts = []
        for z, *_ in station_profile()[1:-1]:
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.50)
            pts.append(tuple(origin + e_x * 0.006))
        add_polyline(f"wood_black_wale_{side}", pts, 0.014, black)

    # One honest port row: 4 ports per side in the ochre band with muzzles
    # run out — the one class where the modeled count IS the stat (8).
    gun_z = [-1.15, -0.55, 0.05, 0.65]
    for side in (-1, 1):
        for i, z in enumerate(gun_z):
            add_side_gunport(FORM, f"main_gundeck_port_{side}_{i}", side, z, 0.70, materials, size=0.145)
            origin, e_x, _, _ = hull_surface_frame(z, side, 0.70)
            add_cylinder_between(f"main_deck_cannon_{side}_{i}", tuple(origin - e_x * 0.05), tuple(origin + e_x * 0.085), 0.018, black, 12)

    # Aft-only open rail (tuning pass, per the brief): posts and a single top
    # rail around the quarters and tiller; the waist and foredeck stay open
    # with just the deck edge cap. The forward ends sweep down to the cap so
    # nothing terminates floating.
    for side in (-1, 1):
        rail_z = [1.58, 1.36, 1.14, 0.92, 0.70]
        for z in rail_z:
            x, y, _ = side_point(z, side, 1.0, 0.030)
            add_cylinder_between(f"rail_post_{side}_{z}", (x, y, z), (x, y + 0.155, z), 0.017, dark, 10)
        rail_pts = [side_point(z, side, 1.0, 0.030) for z in rail_z]
        rail_pts = [(x, y + 0.160, z) for x, y, z in rail_pts]
        add_polyline(f"top_rail_{side}", rail_pts, 0.024, dark)
        end_x, end_y, end_z = rail_pts[-1]
        cap_x, cap_y, _ = side_point(0.46, side, 0.99, 0.006)
        add_polyline(
            f"top_rail_end_sweep_{side}",
            [(end_x, end_y, end_z), (cap_x, cap_y + 0.105, 0.56), (cap_x, cap_y + 0.058, 0.46)],
            0.020,
            dark,
        )

    # Bow: swept dark stem with a small gilt cap (half the gold budget) and
    # bowsprit knees. No billethead, no head rails.
    add_polyline("Bow_swept_dark_stem", [(0, -0.02, -1.85), (0, 0.20, -2.00), (0, 0.38, -2.10), (0, 0.50, -2.16)], 0.020, dark)
    add_polyline("Bow_stem_gilt_cap", [(0, 0.50, -2.16), (0, 0.545, -2.185), (0, 0.57, -2.19)], 0.016, gilt)
    for side in (-1, 1):
        add_cylinder_between(
            f"Bow_bowsprit_knee_{side}",
            (side * 0.085, 0.46, -1.92),
            (side * 0.02, 0.56, -2.10),
            0.011,
            dark,
            10,
        )

    add_transom(materials)

    # One mast — the class signature. Bare kit pole (no square yards) carrying
    # the ship-side boom and gaff.
    add_mast_assembly(FORM, "main", -0.12, 2.15, 0.055, materials)
    add_gaff_spars(materials)

    # Proud bowsprit, low-steeved (~21 degrees), iron gammoning, dark tip.
    add_cylinder_between("Bowsprit_dark_wood", (0, 0.44, -1.90), (0, 0.80, -2.85), 0.036, dark, 16)
    add_cylinder_between("Bowsprit_dark_tip", (0, 0.80, -2.85), (0, 0.84, -2.95), 0.024, dark, 14)
    add_cylinder_between("Bowsprit_iron_gammoning_band", (0, 0.515, -2.125), (0, 0.55, -2.155), 0.044, materials["gold"], 12)


def mast_deck_y(z):
    return side_point(z, 1, 0.985, -0.020)[1]


def gaff_geometry():
    # Shared by the spar builder, the sail sheet, and the rigging routes.
    # Boom overhangs the transom (stern 1.75 -> boom end 1.92): the sloop
    # giveaway. Gaff rakes ~35 degrees, throat kept below the kit top platform.
    main_deck = mast_deck_y(-0.12)
    boom_start = Vector((0.0, main_deck + 0.300, -0.04))
    boom_end = Vector((0.0, main_deck + 0.340, 1.92))
    throat = Vector((0.0, main_deck + 1.200, -0.04))
    peak = Vector((0.0, main_deck + 1.900, 0.98))
    return boom_start, boom_end, throat, peak


def add_gaff_spars(materials):
    # Boom + gaff for the mainsail: ship-side add_spar calls (brig pattern,
    # no kit change). Named Yard_* so they classify into the main assembly
    # and flatten to Yard_Main_Gaff.
    dark = materials["dark_wood"]
    iron = materials["gold"]
    boom_start, boom_end, throat, peak = gaff_geometry()
    add_spar("Yard_boom_main", tuple(boom_start), tuple(boom_end), 0.027, 0.019, dark, 12)
    add_spar("Yard_gaff_main", tuple(throat), tuple(peak), 0.020, 0.013, dark, 12)
    add_cube("Yard_boom_jaw_main", (0, boom_start.y, -0.09), (0.10, 0.050, 0.10), dark, 0.007)
    add_cube("Yard_gaff_jaw_main", (0, throat.y, -0.09), (0.09, 0.045, 0.09), dark, 0.007)
    add_cylinder_between("Yard_gaff_iron_collar_main", (0, throat.y - 0.018, -0.12), (0, throat.y + 0.018, -0.12), 0.048, iron, 12)


def add_sails(materials):
    # Two sails — that IS the sloop. Gaff main laced to gaff and boom with a
    # starboard belly; jib on the forestay with tack seated on the bowsprit.
    canvas = materials["sail"]

    boom_start, boom_end, throat_spar, peak_spar = gaff_geometry()
    throat = Vector((0.0, throat_spar.y - 0.02, 0.00))
    peak = Vector((0.0, peak_spar.y - 0.02, peak_spar.z - 0.02))
    # Foot corners sit low enough to lace onto the boom (tuning pass: -0.02).
    tack = Vector((0.0, boom_start.y + 0.010, 0.02))
    clew = Vector((0.0, boom_end.y + 0.016, 1.84))

    def gaff_fn(u, v):
        head = throat.lerp(peak, u)
        foot = tack.lerp(clew, u)
        base = head.lerp(foot, v)
        billow = 0.15 * math.sin(math.pi * u) * math.sin(math.pi * v)
        return (base.x + billow, base.y, base.z)

    add_sail("Sail_gaff_main", gaff_fn, canvas)

    main_deck = mast_deck_y(-0.12)
    stay_low = (0.0, 0.762, -2.75)
    stay_high = (0.0, main_deck + 2.15 - 0.04, -0.14)
    add_jib(
        "Sail_jib_bowsprit",
        canvas,
        stay_low,
        stay_high,
        clew=(0.0, 0.66, -1.15),
        luff_start=0.02,
        luff_end=0.72,
        billow=0.14,
        sheet_offset=0.06,
    )


def add_rigging(materials):
    # Sparse rig, right for the class: forestay (= jib luff), three shrouds a
    # side anchored FORWARD of the mast (away from the aft gaff canvas — three
    # ships' precedent), a backstay pair to the quarters beside the leech, the
    # peak halyard, and the boom sheet. No vangs, no topping lift.
    rope = materials["rope"]

    def rail_anchor(z, side):
        # Rail-height anchor: only valid where the aft rail run exists.
        x, y, _ = side_point(z, side, 1.0, 0.045)
        return (x, y + 0.08, z)

    def chainplate_anchor(z, side):
        # Deck-edge anchor for the open waist (no rail there after the
        # tuning pass): shrouds land at the cap line like chainplates.
        x, y, _ = side_point(z, side, 1.0, 0.045)
        return (x, y + 0.025, z)

    main_deck = mast_deck_y(-0.12)
    main_head = main_deck + 2.15
    main_top = main_deck + 2.15 * 0.60
    boom_start, boom_end, throat, peak = gaff_geometry()

    main = []
    main.append(rope_points((0, main_head - 0.04, -0.14), (0, 0.762, -2.75), 0.015))  # forestay = jib luff line (kept taut)
    main.append(rope_points((0, main_head - 0.06, -0.08), (0, peak.y + 0.02, peak.z - 0.02), 0.02))  # gaff peak halyard
    main.append(rope_points((0, boom_end.y - 0.02, 1.88), (0, 0.56, 1.70), 0.008))    # boom sheet -> taffrail
    for side in (-1, 1):
        for z in (-0.75, -0.45, -0.16):
            main.append(rope_points((0, main_top - 0.10, -0.12), chainplate_anchor(z, side), 0.012))
        main.append(rope_points((0, main_head - 0.04, -0.10), rail_anchor(1.45, side), 0.03))  # backstay to the quarter rail
    add_rope_bundle("Rigging_main", main, 0.009, rope)

    bowsprit = []
    bowsprit.append(rope_points((0, 0.72, -2.60), (0, 0.04, -1.80), 0.025))           # bobstay -> stem
    for side in (-1, 1):
        bowsprit.append(rope_points((0, 0.73, -2.62), (side * 0.20, 0.26, -1.55), 0.018))  # shroud -> hull skin
    add_rope_bundle("Rigging_bowsprit", bowsprit, 0.008, rope)


def add_flags_and_anchors(materials):
    # ONE restrained masthead streamer; the faction flag stays procedural in
    # Godot — the model only ships anchor empties for the runtime flag and
    # fire-effect systems.
    streamer = materials["streamer"]
    main_head = mast_deck_y(-0.12) + 2.15

    add_streamer("Streamer_main", (0, main_head + 0.05, -0.07), 0.38, 0.055, streamer)

    # Flag anchors: ensign on the taffrail staff; Anchor_Flag_Main shipped for
    # the uniform contract even though the sloop profile has no mast pennant.
    # Fire anchors keep the exact visual_states positions (sloop_basic).
    add_anchor_empty("Anchor_Flag_Stern", (0.0, 1.16, 1.89))
    add_anchor_empty("Anchor_Flag_Main", (0.0, main_head + 0.06, -0.12))
    add_anchor_empty("Anchor_Fire_Deck", (0.0, 0.75, 0.0))
    add_anchor_empty("Anchor_Fire_Sail", (0.0, 1.65, -0.12))


MAST_ASSEMBLIES = {"main": "MainmastAssembly", "bowsprit": "BowspritAssembly"}

# Single-mast contract tree: ForemastAssembly AND MizzenAssembly are dropped,
# everything else keeps the contract names (transom pieces take the
# Sterncastle slot, frigate/brig precedent).
ASSEMBLY_TREE = {
    "Hull": ["HullMesh", "Deck", "Sterncastle", "Railings", "Gunports", "Cannons"],
    "MainmastAssembly": [],
    "BowspritAssembly": [],
    "Flags": [],
    "EffectsAnchors": [],
}


def classify_ship_object(name):
    n = name.lower()
    # Sloop-specific rules first, then the kit's cross-ship prefixes. The
    # transom panel, stern light, and ensign staff take the Sterncastle slot;
    # the tiller is deck furniture (Deck_ prefix handled by classify_common).
    if n.startswith("transom_"):
        return "Sterncastle"
    common = classify_common(n, MAST_ASSEMBLIES)
    if common is not None:
        return common
    if n.startswith(("hull_", "wood_plank_line_", "wood_black_wale_", "ochre_band_edge_strake_", "bow_")):
        return "HullMesh"
    return None


def organize_assemblies():
    assembly_locations = {
        "MainmastAssembly": (0.0, mast_deck_y(-0.12), -0.12),
        "BowspritAssembly": (0.0, 0.44, -1.90),
    }
    organize_assemblies_from("Sloop", ASSEMBLY_TREE, assembly_locations, classify_ship_object)


def build_materials():
    return {
        # Dark charcoal-brown hull per the Rapide sheet: deeper than the brig's
        # tarred brown, warmer than the frigate's near-black.
        "dark_wood": wood_mat("charcoal brown sloop hull oak", (0.085, 0.062, 0.042, 1), (0.140, 0.100, 0.068, 1), (0.028, 0.020, 0.013, 1)),
        "wood": wood_mat("warm sloop deck wood", (0.42, 0.31, 0.175, 1), (0.56, 0.42, 0.24, 1), (0.13, 0.075, 0.038, 1)),
        # Deep shadowed counter timber for the transom stack (aft faces sit
        # square to the review fill light — brig lesson).
        "counter_wood": wood_mat("shadowed counter timber", (0.055, 0.040, 0.026, 1), (0.090, 0.064, 0.042, 1), (0.020, 0.014, 0.009, 1)),
        # Warm ochre/gold-tan band: the sloop's ownable color (galleon owns
        # burgundy, frigate navy-as-band, brig buff-on-brown).
        "ochre_paint": paint_mat("rich gold-amber gun band", (0.505, 0.305, 0.058, 1), (0.655, 0.425, 0.095, 1), (0.285, 0.152, 0.026, 1)),
        # Deep navy for the small stern panel only (the frigate owns navy).
        "navy_paint": paint_mat("deep sloop stern navy", (0.040, 0.068, 0.125, 1), (0.065, 0.100, 0.180, 1), (0.016, 0.026, 0.055, 1)),
        # Muted red port lids/reveals (kit gunports read materials["red_paint"]).
        "red_paint": paint_mat("muted red port lid", (0.330, 0.075, 0.050, 1), (0.430, 0.110, 0.070, 1), (0.170, 0.033, 0.022, 1)),
        # Kit fittings render as blackened iron (brig precedent) so the gold
        # budget stays clearly below the frigate's.
        "gold": mat("blackened iron fittings", (0.070, 0.062, 0.055, 1), 0.55, 0.62),
        # True gilt, rationed: stem cap, stern mouldings, ensign truck.
        "gilt": gold_mat("rationed gilt accent"),
        "black": mat("visible warm shadow black", (0.035, 0.027, 0.020, 1), 0.82),
        # Neutral/whitish so ShipVisualBuilder's per-faction tint reads (ADR 0010).
        "sail": mat("neutral sail canvas", (0.91, 0.88, 0.80, 1), 0.90),
        "rope": mat("tarred hemp rope", (0.20, 0.14, 0.09, 1), 0.92),
        "streamer": mat("bright signal red", (0.66, 0.09, 0.07, 1), 0.63),
    }


def render_level(path, camera_location, target, ortho_scale):
    # Kit render_to tracks the camera up toward world Z (a quirk the galleon
    # renders inherited: angled shots come out rolled). This keeps the horizon
    # level — world +Y up — for the sloop's angled review shots.
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
        # S1 silhouette check: naked hull + deck/transom masses.
        deck_z = [1.72, 1.55, 1.35, 1.12, 0.86, 0.58, 0.30, 0.02, -0.26, -0.54, -0.82, -1.10, -1.36, -1.60, -1.80, -1.96]
        add_shaped_deck(FORM, "Deck_shaped_to_hull_planks", deck_z, materials)
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
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT_DIR / "sloop_working.blend"))

    if STAGE == "hull":
        # S1 framing: tight on the naked hull so the sheer line fills the frame.
        render_to(OUT_DIR / "sloop_hull_primary.png", (-8.2, 0.52, -0.15), (0, 0.35, -0.15), 6.2, 90.0)
        render_level(OUT_DIR / "sloop_hull_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.42, 0.0), 6.8)
        render_level(OUT_DIR / "sloop_hull_stern_angle.png", (-6.1, 3.2, 6.2), (0, 0.50, 0.45), 5.4)
        render_level(OUT_DIR / "sloop_hull_bow_readability_angle.png", (6.3, 3.3, -6.4), (0, 0.46, -0.65), 5.4)
        render_clay(OUT_DIR / "sloop_hull_clay_side.png", (-8.2, 0.52, -0.15), (0, 0.35, -0.15), 5.8, 90.0)
    else:
        render_to(OUT_DIR / "sloop_primary.png", (-8.2, 1.10, -0.35), (0, 1.10, -0.35), 8.0, 90.0)
        render_level(OUT_DIR / "sloop_gameplay_camera.png", (-6.8, 5.7, -6.2), (0, 0.65, 0.0), 8.2)
        render_level(OUT_DIR / "sloop_stern_angle.png", (-6.1, 3.2, 6.2), (0, 0.70, 0.45), 6.2)
        render_level(OUT_DIR / "sloop_bow_readability_angle.png", (6.3, 3.3, -6.4), (0, 0.70, -0.70), 6.8)
        render_level(OUT_DIR / "sloop_bow_close.png", (4.5, 1.6, -5.0), (0, 0.70, -1.70), 3.0)
        render_clay(OUT_DIR / "sloop_clay_inspection.png", (-8.2, 1.10, -0.35), (0, 1.10, -0.35), 8.0, 90.0)


if __name__ == "__main__":
    main()
