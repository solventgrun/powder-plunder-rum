"""Shared ship-generator kit (extracted from the galleon pilot, 2026-08-15).

Ship-agnostic machinery for building stylized ship assets in Blender:
materials, mesh primitives, station-profile hull math (HullForm), mast
assemblies, sail grids, rope rigging, the Godot-facing assembly organization,
the shared review-render rig, and the GLB flatten/export helpers.

Per-ship generators (e.g. blender_first_hull/create_galleon_hull.py) own only
their station profile, decoration, sail plan, rigging routes, and anchors.
Kit changes must keep the galleon rebuild pixel-identical (render diff gate).
"""
from .assemblies import (
    BASE_ASSEMBLY_TREE,
    BASE_MAST_ASSEMBLIES,
    classify_common,
    organize_assemblies_from,
)
from .canvas import add_anchor_empty, add_sail, add_square_sail, add_streamer
from .export import flatten_group, flatten_materials_for_export
from .fittings import add_mast_assembly
from .hullform import (
    HullForm,
    add_hull_side_box,
    add_shaped_deck,
    add_side_gunport,
    create_hull,
)
from .materials import gold_mat, mat, paint_mat, wood_mat
from .primitives import (
    add_cube,
    add_cylinder_between,
    add_ellipsoid,
    add_panel_frame,
    add_polyline,
    add_spar,
    add_stern_gallery_tier,
    add_surface_cube,
    add_tapered_box,
    add_window,
    clear_scene,
    look_at,
    recalc_outward_normals,
)
from .review import render_clay, render_to, setup_review_scene
from .rigging import add_rope_bundle, rope_points
