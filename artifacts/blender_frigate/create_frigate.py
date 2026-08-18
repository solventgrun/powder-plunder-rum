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
  FRIGATE_KIT     base | france (default base)
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
    add_spar,
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
FACTION_KIT = os.environ.get("FRIGATE_KIT", "base")


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
    # France kit: taffrail wood instead of gold — France's livery recolors the
    # gold slot to ivory-cream, and this bar sits right between the stern
    # lanterns where the cream read as a floating white strip.
    upper_moulding = dark if FACTION_KIT == "france" else gold
    add_cube("Transom_gold_upper_moulding", (0, 1.145, 2.415), (0.86, 0.018, 0.050), upper_moulding, 0.004)
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


# The sea-nymph is authored at a comfortable working size and then posed as a
# unit. FIGUREHEAD_SCALE is capped by the bow envelope, not by taste: at 2.0
# the head drives straight through the bowsprit and lands past its tip.
# Solving against the spar underside, the waterline, and the tip gives 1.6 at
# -10 deg of extra lean, which also aims her growth out along the spar instead
# of up into it. Going bigger means lengthening the bowsprit or accepting that
# she projects beyond it.
FIGUREHEAD_SCALE = 1.6
FIGUREHEAD_EXTRA_LEAN = math.radians(-10.0)
FIGUREHEAD_PIVOT = Vector((0.0, 0.60, -2.70))


def pose_french_figurehead(objects):
    matrix = (
        Matrix.Translation(FIGUREHEAD_PIVOT)
        @ Matrix.Rotation(FIGUREHEAD_EXTRA_LEAN, 4, "X")
        @ Matrix.Scale(FIGUREHEAD_SCALE, 4)
        @ Matrix.Translation(-FIGUREHEAD_PIVOT)
    )
    for obj in objects:
        obj.matrix_world = matrix @ obj.matrix_world


def add_french_stern_lantern(materials, side):
    # A real lantern silhouette (post, glass body in a cage, conical cap,
    # finial) replacing the first pass's bare ivory ellipsoid. Copper cage and
    # a deep-amber glass so the fixture reads metal, not white — copper is a
    # new material name on purpose, outside the livery roles.
    copper = materials["copper"]
    glass = materials["lantern_glass"]
    x = side * 0.47
    add_cylinder_between(f"French_stern_lantern_post_{side}", (x, 1.185, 2.42), (x, 1.248, 2.44), 0.013, copper, 8)
    add_ellipsoid(f"French_stern_lantern_base_{side}", (x, 1.252, 2.44), (0.038, 0.014, 0.038), copper, 10, 4)
    add_ellipsoid(f"French_stern_lantern_glass_{side}", (x, 1.312, 2.44), (0.034, 0.052, 0.034), glass, 12, 8)
    for i in range(4):
        a = math.pi * 0.5 * i + math.pi * 0.25
        rx = math.cos(a) * 0.036
        rz = math.sin(a) * 0.036
        add_cylinder_between(f"French_stern_lantern_rib_{side}_{i}", (x + rx, 1.260, 2.44 + rz), (x + rx, 1.364, 2.44 + rz), 0.007, copper, 6)
    add_spar(f"French_stern_lantern_cap_{side}", (x, 1.366, 2.44), (x, 1.406, 2.44), 0.042, 0.012, copper, 10)
    add_ellipsoid(f"French_stern_lantern_finial_{side}", (x, 1.414, 2.44), (0.012, 0.016, 0.012), copper, 8, 4)


def add_water_curl(name, eye, yaw, tilt, radius, start, sweep, thickness, material, samples=16, drift=None):
    """One tightening spiral, drawn in a plane whose normal is steered by yaw
    and tilt. Steering matters: spirals sharing one plane stack into parallel
    ribs and the sea reads as a basket, so every strand gets its own."""
    normal = Vector((math.cos(yaw), tilt, math.sin(yaw)))
    normal.normalize()
    axis_a = Vector((0.0, 1.0, 0.0)).cross(normal)
    if axis_a.length < 1e-4:
        axis_a = Vector((1.0, 0.0, 0.0))
    axis_a.normalize()
    axis_b = normal.cross(axis_a).normalized()
    points = []
    for step in range(samples):
        f = step / float(samples - 1)
        angle = start + sweep * f
        r = radius * (1.0 - 0.36 * f)
        point = eye + axis_a * (math.cos(angle) * r) + axis_b * (math.sin(angle) * r)
        if drift is not None:
            point = point + drift * f
        points.append((point.x, point.y, point.z))
    add_polyline(name, points, thickness, material)
    return points


def add_water_swirl(name, centre, axis_a, axis_b, radius, turns, material, thickness, segments=20):
    # Spiral tightening toward its centre — the eye of a curl. Water reads as
    # motion far better with a couple of these than with more plain arcs.
    points = []
    for i in range(segments + 1):
        f = i / float(segments)
        angle = turns * 2.0 * math.pi * f
        r = radius * (1.0 - 0.78 * f)
        point = centre + axis_a * (math.cos(angle) * r) + axis_b * (math.sin(angle) * r)
        points.append((point.x, point.y, point.z))
    add_polyline(name, points, thickness, material)


def add_french_sea(materials):
    """The sea she rides, built from strands rather than solid masses so it
    shares the hair's visual language and the whole carving reads as one
    piece. A low core keeps daylight out; everything above it is flowing
    strands, spiral curls, and foam beads."""
    navy = materials["navy_paint"]
    foam = materials["nymph_foam"]

    # Low core swell — deliberately wide and flat. It is scenery for the
    # strands to sit on, never the silhouette itself.
    core = add_ellipsoid("French_sea_core", (0, 0.500, -2.766), (0.150, 0.092, 0.132), navy, 16, 10)
    core.rotation_euler = (math.radians(-26.0), 0.0, 0.0)
    shoulder = add_ellipsoid("French_sea_core_shoulder", (0, 0.600, -2.820), (0.108, 0.076, 0.098), navy, 14, 10)
    shoulder.rotation_euler = (math.radians(-30.0), 0.0, 0.0)

    # Breaking-curl strands: each is a partial SPIRAL in the fore-aft plane,
    # sweeping up the wave face, over the crest, and tucking back toward its
    # own eye. A tightening spiral is the actual shape of a breaking wave; a
    # fixed polyline profile was the first attempt and the strands nested into
    # angular staples. Radius, start angle, and sweep all vary per strand so
    # they never stack concentrically.
    for station in range(7):
        u = (station - 3) / 3.0
        base_x = u * 0.190
        eye_y = 0.582 + 0.046 * (1.0 - abs(u)) - 0.020 * u * u
        eye_z = -2.792 - 0.052 * (1.0 - abs(u))
        for k in range(4):
            phase = 1.7 * station + 2.3 * k
            # Small and shallow on purpose: full-turn loops at this radius
            # tangled into a ball of yarn. These are crescent ridges layering
            # over the mound, with only the swirl eyes below closing fully.
            radius = (0.062 + 0.020 * math.sin(phase)) * (0.78 + 0.22 * (1.0 - abs(u)))
            # Outer stations swing their planes outboard, so the sea spreads
            # away from the stem the way a bow wave actually throws.
            yaw = 0.55 * u + 0.42 * math.sin(phase * 1.1)
            tilt = 0.35 * math.sin(phase * 0.7)
            points = add_water_curl(
                "French_sea_curl_%d_%d" % (station, k),
                Vector((base_x, eye_y, eye_z)),
                yaw, tilt, radius,
                math.radians(205.0 + 26.0 * math.sin(phase * 1.4)),
                math.radians(168.0 + 30.0 * math.sin(phase * 0.9)),
                0.0080, navy, samples=12,
                drift=Vector((0.026 * u, 0.010, -0.016 * (1.0 - abs(u)))),
            )
            if k % 2 == 0:
                crest = max(points, key=lambda p: p[1])
                add_ellipsoid(
                    "French_sea_curl_foam_%d_%d" % (station, k),
                    (crest[0], crest[1] + 0.009, crest[2]),
                    (0.017, 0.012, 0.017), foam, 8, 4,
                )

    # The water that replaces her legs: strands sweeping up around the hip
    # blend so she emerges from the sea instead of standing in it.
    body_up = Vector((0.0, 0.788, -0.6157))
    body_front = Vector((0.0, -0.6157, -0.788))
    leg_root = Vector((0.0, 0.600, -2.792))
    # Spirals rather than a ring of uprights: strands climbing straight up
    # around her hips built a picket cage. These sit tangent to the body at
    # staggered heights and angles, so the water looks like it is turning over
    # itself as it swallows her lower half.
    for i in range(18):
        angle = (i / 18.0) * 2.0 * math.pi * 1.35
        phase = 2.1 * i
        height = 0.020 + 0.175 * ((i % 9) / 8.0)
        radial = Vector((math.sin(angle), 0.0, 0.0)) + body_front * math.cos(angle)
        eye = leg_root + radial * (0.078 + 0.016 * math.sin(phase)) + body_up * height
        points = add_water_curl(
            "French_sea_leg_curl_%d" % i, eye,
            angle + 1.5708 + 0.30 * math.sin(phase),      # plane tangent to her body
            0.30 * math.sin(phase * 0.8),
            0.036 + 0.014 * math.sin(phase * 1.3),
            math.radians(190.0 + 40.0 * math.sin(phase)),
            math.radians(180.0 + 40.0 * math.cos(phase)),
            0.0074, navy, samples=11,
            drift=body_up * 0.024 + radial * 0.016,
        )
        if i % 4 == 0:
            crest = max(points, key=lambda p: p[1])
            add_ellipsoid(
                "French_sea_leg_foam_%d" % i, crest, (0.014, 0.010, 0.014), foam, 8, 4,
            )

    # Spiral eyes at the curl focal points — the bubbling, churning read.
    # Flanking pairs only: a fifth swirl once sat centre-front at (0, 0.560,
    # -2.900), which is exactly the fleur-de-lis shield's volume — it wove
    # through the gold and read as water blocking the emblem (user feedback
    # 2026-08-18). The centre-front of the wave face belongs to the heraldry.
    side_axis = Vector((1.0, 0.0, 0.0))
    for i, (centre, radius, turns) in enumerate((
        (Vector((-0.150, 0.610, -2.735)), 0.055, 1.35),
        (Vector((0.150, 0.610, -2.735)), 0.055, -1.35),
        (Vector((-0.072, 0.690, -2.860)), 0.044, -1.20),
        (Vector((0.072, 0.690, -2.860)), 0.044, 1.20),
    )):
        add_water_swirl(
            "French_sea_swirl_%d" % i, centre, side_axis, body_up, radius, turns, navy, 0.0075,
        )
        add_ellipsoid("French_sea_swirl_eye_%d" % i, tuple(centre), (0.014, 0.010, 0.014), foam, 8, 4)

    # Scattered bubble beads through the churn.
    for i in range(22):
        a = i * 2.399           # golden-angle scatter, no visible grid
        r = 0.055 + 0.135 * math.sqrt((i % 11) / 11.0)
        bead = Vector((math.cos(a) * r, 0.470 + 0.150 * ((i % 7) / 7.0), -2.760 + math.sin(a) * r * 0.62))
        size = 0.008 + 0.007 * ((i % 5) / 5.0)
        add_ellipsoid("French_sea_bubble_%d" % i, tuple(bead), (size, size * 0.75, size), foam, 8, 4)


def add_french_figurehead(materials):
    """Sea-nymph figurehead (user concept 2026-08-17): chunky color-blocked
    masses so she reads at gameplay distance — ivory-stone figure, French-blue
    drapery and wave base, true gold only on the small accents. Detail budget
    goes to the three silhouette cues: forward lean, swept-back hair, wave curl."""
    skin = materials["nymph_stone"]
    hair = materials["nymph_hair"]
    navy = materials["navy_paint"]  # paint role -> French blue at runtime
    foam = materials["nymph_foam"]
    gold = materials["gilt_bronze"]
    lean = math.radians(-38.0)  # forward pitch: +Y tips toward -Z (the bow)

    # The hull nose runs out to z=-2.75 (last station), so the whole figure
    # rides AHEAD of the prow under the bowsprit, like a real figurehead. The
    # centerline bobstay is split into a V around her (see add_rigging).
    # Wave base: a swelling mass at the prow with a BREAKING curl per side —
    # the curl arcs up, rolls forward, and tucks back under itself, with a
    # seafoam lip riding the whole crest (user feedback: the first pass's
    # smooth arcs read as blobs, not water).
    add_french_sea(materials)

    # A collection of small breaking wavelets climbing from the wave base up
    # over her gown to the waist, each rising, rolling over, and tucking back
    # under with its own foam tip. Two big curls alone read as decoration;
    # many fine ones read as sea.
    body_up = Vector((0.0, 0.788, -0.6157))     # along her body, toward the head
    body_front = Vector((0.0, -0.6157, -0.788))  # her ventral side
    hip_anchor = Vector((0.0, 0.818, -2.878))
    # Each wavelet is a shallow crescent WRAPPING her body (rising to a crest
    # at its middle), not a line climbing her — stacked and staggered row to
    # row they overlap like real wave fronts. Climbing chains of blobs was the
    # first attempt and read as beaded rope.
    for row in range(6):
        h = row / 5.0
        base = hip_anchor + body_up * (0.045 - 0.215 * h)
        girth = 0.054 + 0.034 * h
        stagger = 0.42 * (row % 2)
        for j in range(3):
            theta0 = -1.05 + 1.05 * j + stagger
            points = []
            for step in range(7):
                f = step / 6.0
                theta = theta0 + (f - 0.5) * 0.95
                radial = Vector((math.sin(theta), 0.0, 0.0)) + body_front * math.cos(theta)
                crest = base + radial * girth + body_up * (0.026 * math.sin(math.pi * f))
                points.append((crest.x, crest.y, crest.z))
            add_polyline(f"French_figurehead_wavelet_{row}_{j}", points, 0.0085, navy)
            peak = points[3]
            add_ellipsoid(
                f"French_figurehead_wavelet_foam_{row}_{j}",
                peak, (0.012, 0.008, 0.012), foam, 8, 4,
            )

    # No legs and no gown: below the hips she dissolves straight into the sea
    # (add_french_sea builds that region out of the same strand language as the
    # hair, so the whole carving reads as one piece). This blend mass is only
    # here so no daylight shows between hip and water.
    blend = add_ellipsoid("French_figurehead_hip_blend", (0, 0.742, -2.836), (0.062, 0.070, 0.062), navy, 12, 8)
    blend.rotation_euler = (lean, 0.0, 0.0)

    # Ribcage / waist / hip as three masses instead of one barrel: a single
    # tall ellipsoid from chest to hip carried its full width through the
    # middle, which read as a pregnant belly. The waist is deliberately the
    # narrowest link in the chain.
    torso = add_ellipsoid("French_figurehead_torso", (0, 0.922, -2.960), (0.056, 0.078, 0.050), skin, 12, 8)
    torso.rotation_euler = (lean, 0.0, 0.0)
    waist = add_ellipsoid("French_figurehead_waist", (0, 0.864, -2.914), (0.038, 0.046, 0.035), skin, 12, 8)
    waist.rotation_euler = (lean, 0.0, 0.0)
    hips = add_ellipsoid("French_figurehead_hips", (0, 0.814, -2.876), (0.058, 0.050, 0.052), skin, 12, 8)
    hips.rotation_euler = (lean, 0.0, 0.0)
    chest = add_ellipsoid("French_figurehead_shoulders", (0, 0.975, -2.990), (0.070, 0.048, 0.050), skin, 12, 6)
    chest.rotation_euler = (lean, 0.0, 0.0)
    # Deliberately oversized and set PROUD of the torso surface: the first pass
    # put them at 0.755 of the torso radius, so the ellipsoid swallowed them
    # whole. These must break the body silhouette to read female at gameplay
    # distance — the ventral direction is local -Z, which the lean tips
    # down-and-forward, so they carry the profile from the side too.
    for side in (-1, 1):
        breast = add_ellipsoid(f"French_figurehead_breast_{side}", (side * 0.036, 0.921, -3.019), (0.044, 0.042, 0.044), skin, 12, 8)
        breast.rotation_euler = (lean, 0.0, 0.0)

    # Arms swept back toward the prow, like the concept's trailing pose — the
    # hands land on the hull nose as if she is riding the ship forward.
    for side in (-1, 1):
        add_spar(
            f"French_figurehead_arm_{side}",
            (side * 0.062, 0.960, -2.975),
            (side * 0.080, 0.730, -2.760),
            0.016, 0.011, skin, 8,
        )

    # Head looking out over the sea, hair FLYING back toward the ship — a
    # crown cap plus a fan of thick undulating strands streaming aft and up
    # (user feedback: the first pass had no visible hair or motion). The
    # cluster sits low enough that the bowsprit shrouds pass above it.
    # Head is deliberately oversized against the body (a caricature ratio, like
    # a carved figurehead) so the face is a readable mass, not a knob.
    # Head height is set by the bowsprit, not by taste: at 1.015 the posed
    # crown came within 0.012 world of the spar underside, leaving no room for
    # hair on top — the bun could only exist inside the spar (user feedback
    # 2026-08-18: hair wrapped around the mast). Dropping to 0.997 buys the
    # cap ~0.03 of daylight below the spar while the neck stays readable.
    add_ellipsoid("French_figurehead_head", (0, 0.997, -3.035), (0.058, 0.067, 0.062), skin, 14, 10)
    # Nose on the ventral face direction (the lean tips her face down-forward),
    # set a touch above centre so it reads as a profile rather than a snout.
    face = Vector((0.0, math.sin(lean), -math.cos(lean)))  # outward from the face
    head_centre = Vector((0.0, 0.997, -3.035))
    brow = head_centre + Vector((0.0, 0.788, -0.6157)) * 0.008
    add_spar(
        "French_figurehead_nose",
        tuple(brow + face * 0.040), tuple(brow + face * 0.082),
        0.016, 0.007, skin, 8,
    )
    # Low chignon hugging the skull, not an up-tipped bun: the first pass sat
    # at (0, 1.040, -3.010) with a long +z axis pitched -24 deg, whose posed
    # top reached y~1.316 against a spar underside of y~1.264 — the bowsprit
    # plowed straight through the hair. Solved against the posed spar: this
    # centre/size/tilt tops out at y~1.247, under the spar by ~0.03 while
    # still covering the crown by ~0.008.
    hair_cap = add_ellipsoid("French_figurehead_hair_cap", (0, 1.004, -3.030), (0.068, 0.064, 0.062), hair, 14, 10)
    hair_cap.rotation_euler = (math.radians(-6.0), 0.0, 0.0)
    # Under-mass stops daylight showing between strands without becoming the
    # shape itself — the strands are what should read as hair. It must dive
    # WITH the fan: at the first pass's -14 deg it lay nearly level, and the
    # posed aft end drove up through the descending bowsprit and poked out
    # above the spar — the tan mass "wrapped around the mast" in the user's
    # 2026-08-18 screenshots. +48 deg lays its long axis along the strand
    # fall line (48 deg below horizontal pre-pose), keeping the whole mass
    # >=0.05 world under the spar.
    hair_mass = add_ellipsoid("French_figurehead_hair_stream", (0, 0.865, -2.882), (0.046, 0.034, 0.118), hair, 12, 8)
    hair_mass.rotation_euler = (math.radians(48.0), 0.0, 0.0)

    # A dense fan of FINE strands in three layers. Radius 0.0072 against the
    # arms' 0.016->0.011 taper: less than half, so hair and limbs can never be
    # confused. They stream back and DOWN along her back — the bowsprit slopes
    # right over her head, so upswept hair would clip it — and each strand
    # carries its own phase so the fan never reads as one solid shell.
    # The fall line is set by the bowsprit, not by taste: its underside drops
    # from y~1.104 at z=-3.00 to y~0.909 at z=-2.65, faster than hair would
    # naturally fall, so the centreline strands have to dive to stay clear.
    # Outboard strands (|x| > the spar's 0.048 radius) pass beside it.
    # 112 strands across four layers. Radius stays far under the arms'
    # 0.016->0.011 taper so hair and limbs can never be confused, and the sea
    # is built from strands of a comparable gauge so the two halves of the
    # carving read as one material language.
    strand_radius = 0.0060
    z_root = -3.000
    # The fall is steep on purpose, and it is pinched from both sides. Above:
    # posing the carving 1.6x lifts the fan toward the bowsprit, which descends
    # aft faster than hair naturally falls, so a gentle drop clips the spar.
    # Below-aft: the hull nose starts at z=-2.75, and the first pass's tips
    # (posed z~-2.68) ran straight into the bow and vanished through the deck
    # (user feedback 2026-08-18). Solved at the longest ragged reach (1.06),
    # every layer's posed tip now lands at z<=-2.786 — hovering just forward
    # of the stem, over the bow wave — and the steeper dive also buys more
    # daylight under the spar.
    for layer, (y_root, y_tip, z_tip, spread) in enumerate((
        (1.034, 0.754, -2.746, 1.10),   # crown: longest, widest
        (1.016, 0.736, -2.752, 0.98),
        (0.992, 0.712, -2.758, 0.80),
        (0.968, 0.688, -2.770, 0.58),   # nape: shortest, tucked in
    )):
        for i in range(28):
            u = (i - 13.5) / 13.5
            phase = 0.37 * i + 1.3 * layer
            # Ragged tip lengths stop the fan ending on one clean edge, which
            # is what made the first dense pass read as a broom.
            reach = 0.80 + 0.20 * math.cos(u * 1.6) + 0.06 * math.sin(phase * 2.0)
            points = []
            for step in range(7):
                t = (step / 6.0) * reach
                z = z_root + (z_tip - z_root) * t
                # Two sines of different frequency give a travelling wave down
                # the strand instead of a straight stick.
                y = (
                    y_root + (y_tip - y_root) * t
                    + 0.006 * math.sin(math.pi * t)
                    + 0.005 * math.sin(phase + t * 5.2)
                )
                x = u * 0.048 * spread * (0.60 + 0.70 * t) + 0.010 * math.sin(phase + t * 3.4)
                points.append((x, y, z))
            add_polyline(f"French_figurehead_hair_strand_{layer}_{i}", points, strand_radius, hair)
    add_ellipsoid("French_figurehead_gold_star", (0.052, 1.037, -3.022), (0.014, 0.014, 0.011), gold, 8, 4)

    # Blue sash wrapping the torso diagonally (the concept's flowing drape).
    add_polyline(
        "French_figurehead_sash",
        [
            (-0.050, 0.985, -2.995),
            (-0.062, 0.920, -2.945),
            (-0.028, 0.855, -2.895),
            (0.038, 0.815, -2.870),
            (0.062, 0.775, -2.840),
        ],
        0.022,
        navy,
    )
    add_ellipsoid("French_figurehead_gold_brooch", (0, 0.955, -3.020), (0.014, 0.014, 0.011), gold, 8, 4)

    # Fleur-de-lis shield below her on the front of the wave base (concept
    # detail — a tiny gold-on-blue pop at distance, readable heraldry close
    # up). Flat plates with a proud gold rim and slim petals — the first
    # pass's fat beveled box and thick tubes read as putty, not metalwork.
    # The whole assembly sits 0.018 forward of the first pass: at z~-2.87 the
    # sea's crescent curls broke across the gold and the emblem read as
    # underwater (user feedback 2026-08-18). Proud of the curl fronts, still
    # rooted in the wave shoulder behind it.
    tilt = math.radians(-24.0)
    rim = add_tapered_box("French_figurehead_shield_rim", (0, 0.575, -2.890), 0.108, 0.146, 0.170, 0.018, gold, 0.003)
    rim.rotation_euler = (tilt, 0.0, 0.0)
    plate = add_tapered_box("French_figurehead_shield", (0, 0.575, -2.900), 0.090, 0.128, 0.150, 0.016, navy, 0.003)
    plate.rotation_euler = (tilt, 0.0, 0.0)
    add_spar("French_figurehead_fleur_center", (0, 0.524, -2.925), (0, 0.640, -2.972), 0.011, 0.0035, gold, 8)
    add_spar("French_figurehead_fleur_point", (0, 0.524, -2.925), (0, 0.496, -2.914), 0.009, 0.003, gold, 8)
    for side in (-1, 1):
        # Side petals arc outward then CURL DOWN — pointing them up read as a
        # trident, not a fleur-de-lis.
        add_polyline(
            f"French_figurehead_fleur_petal_{side}",
            [
                (side * 0.008, 0.585, -2.949),
                (side * 0.030, 0.604, -2.959),
                (side * 0.044, 0.586, -2.954),
                (side * 0.046, 0.552, -2.942),
                (side * 0.038, 0.532, -2.934),
            ],
            0.0065,
            gold,
        )
    band = add_cube("French_figurehead_fleur_band", (0, 0.558, -2.939), (0.058, 0.012, 0.010), gold, 0.002)
    band.rotation_euler = (tilt, 0.0, 0.0)


def add_french_refinement(materials):
    """Add the French pilot's graceful visual language without altering the hull."""
    ivory = materials["ivory"]
    blue = materials["french_blue"]
    for side in (-1, 1):
        rail_z = [0.88, 0.44, 0.02, -0.40, -0.82, -1.24, -1.66, -2.02]
        curve = []
        for z in rail_z:
            x, y, _ = side_point(z, side, 1.0, 0.050)
            curve.append((x, y + 0.285 + 0.040 * math.cos((z + 0.20) * 1.45), z))
        add_polyline(f"French_grace_rail_{side}", curve, 0.018, ivory)
        for z in (-1.50, -0.70, 0.18):
            x, y, _ = side_point(z, side, 1.0, 0.048)
            add_cylinder_between(f"French_rail_support_{side}_{z}", (x, y + 0.050, z), (x, y + 0.275, z), 0.012, ivory, 10)
        add_polyline(
            f"French_bow_flowing_rail_{side}",
            [side_point(-1.70, side, 0.92, 0.045), side_point(-2.18, side, 0.96, 0.030), (side * 0.10, 1.03, -2.57), (side * 0.025, 1.00, -2.72)],
            0.017,
            ivory,
        )
    # Slim ornament: it is deliberately shallow so the base transom and
    # gameplay socket locations do not change.
    # Kept below the taffrail cap (top ~1.204): when this poked above the rail
    # its runtime-cream recolor read as a floating white strip between the
    # lanterns.
    add_tapered_box("French_transom_blue_inset", (0, 1.105, 2.458), 0.68, 0.58, 0.145, 0.022, blue, 0.008)
    # Crown arch in taffrail wood (user feedback: the ivory strip between the
    # lanterns read as a floating white bar).
    add_polyline("French_transom_arched_crown", [(-0.32, 1.285, 2.475), (-0.18, 1.355, 2.485), (0, 1.375, 2.490), (0.18, 1.355, 2.485), (0.32, 1.285, 2.475)], 0.016, materials["dark_wood"])
    for side in (-1, 1):
        add_french_stern_lantern(materials, side)
        add_polyline(f"French_quarter_scroll_{side}", [(side * 0.48, 1.235, 2.40), (side * 0.55, 1.285, 2.32), (side * 0.51, 1.325, 2.25)], 0.014, ivory)
    # Build the carving at authoring size, then pose the whole set as one unit.
    # Snapshotting object names is how the pose finds its own geometry without
    # every add_* call having to thread a list back out.
    before = set(bpy.data.objects.keys())
    add_french_figurehead(materials)
    pose_french_figurehead([obj for name, obj in bpy.data.objects.items() if name not in before])


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
    if FACTION_KIT != "france":
        # The France kit replaces the billethead with the sea-nymph figurehead
        # (add_french_figurehead), which occupies this same prow volume.
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
    if FACTION_KIT == "france":
        add_french_refinement(materials)

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
    if FACTION_KIT == "france":
        # Doubled bobstay chains passing either side of the sea-nymph
        # figurehead, which occupies the centerline ahead of the prow.
        for side in (-1, 1):
            bowsprit.append(rope_points((0, 1.28, -3.24), (side * 0.10, 0.12, -2.26), 0.03))
    else:
        bowsprit.append(rope_points((0, 1.28, -3.24), (0, 0.10, -2.28), 0.03))        # bobstay -> stem
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
    if n.startswith(("quarterdeck_bulwark_cap_rail", "quarterdeck_bulwark_gold_deckline", "french_grace_rail", "french_rail_support", "french_bow_flowing_rail")):
        return "Railings"
    if n.startswith(("french_transom_", "french_stern_", "french_quarter_")):
        return "Sterncastle"
    if n.startswith("french_figurehead_"):
        return "HullMesh"
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


def lantern_glass_mat():
    # Warm glass with a gentle baked emission: glTF carries the emissive
    # factor, so the lanterns hold a soft glow in Godot without any runtime
    # light nodes.
    material = mat("french lantern warm glass", (0.88, 0.58, 0.22, 1), 0.35)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (0.95, 0.58, 0.18, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.45
    return material


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
        "ivory": mat("french ivory ornament", (0.86, 0.82, 0.70, 1), 0.62),
        "french_blue": paint_mat("french blue ornament", (0.08, 0.19, 0.48, 1), (0.12, 0.28, 0.62, 1), (0.04, 0.08, 0.22, 1)),
        # Sea-nymph figurehead + lantern palette (France kit only). These names
        # must stay OUT of ShipVisualBuilder.LIVERY_MATERIAL_ROLES: France's
        # livery recolors the "trim" role to ivory-cream, which would erase the
        # figurehead's true-gold accents, and its "accent" role turns blue to
        # cream. The nymph's blues use navy_paint (paint role -> French blue at
        # runtime); everything below keeps its baked color.
        "nymph_stone": mat("nymph carved sandstone", (0.588, 0.520, 0.412, 1), 0.68),
        # Honey-gold, deliberately lighter and warmer than the deck wood, hull
        # timber, and tarred rope it sits among — at strand thickness a mid
        # brown was indistinguishable from the bowsprit rigging behind her.
        "nymph_hair": mat("nymph flowing hair", (0.520, 0.330, 0.120, 1), 0.56),
        "nymph_foam": mat("nymph seafoam crest", (0.512, 0.652, 0.612, 1), 0.62),
        "gilt_bronze": gold_mat("french gilt bronze accent"),
        "copper": mat("french lantern copper", (0.620, 0.340, 0.140, 1), 0.42, 0.55),
        "lantern_glass": lantern_glass_mat(),
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
