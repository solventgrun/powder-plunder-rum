"""Build assets/models/brig.glb from the generator (brief deliverable B5).

Run headless:
  blender --background --python artifacts/blender_brig/build_brig_glb.py

Rebuilds the ship without lights/camera, flattens every terminal group into a
single world-baked mesh (applying bevel/solidify modifiers and converting the
rigging curves), renames objects to the naming contract (root Brig, the
two-mast tree: Fore/Main keys, no Mizzen; the boom+gaff fold into a
Yard_Main_Gaff sibling so the fore-aft rig keeps a useful pivot at the mast),
and exports a GLB with the exporter's Z-up->Y-up conversion DISABLED: the
model is authored Y-up / -Z-forward inside Blender, which already matches the
glTF convention.
"""
import importlib.util
import os
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
KIT = os.environ.get("BRIG_KIT", "base")
GLB_NAME = "brig_dutch.glb" if KIT == "dutch" else "brig.glb"
GLB_PATH = HERE.parent.parent / "assets" / "models" / GLB_NAME

sys.path.insert(0, str(HERE.parent))

from ship_kit import flatten_group, flatten_materials_for_export

spec = importlib.util.spec_from_file_location("brig_gen", HERE / "create_brig.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


def main():
    gen.clear_scene()
    materials = gen.build_materials()
    gen.create_hull(materials)
    gen.decorate_hull(materials)
    gen.add_sails(materials)
    gen.add_rigging(materials)
    gen.add_flags_and_anchors(materials)
    gen.organize_assemblies()
    flatten_materials_for_export()
    bpy.context.view_layer.update()

    objs = bpy.data.objects
    fore_deck = gen.mast_deck_y(-0.85)
    main_deck = gen.mast_deck_y(0.32)

    # Hull: collapse each join-target sub-group into one mesh of the same name.
    hull = objs["Hull"]
    for sub_name in ("HullMesh", "Deck", "Sterncastle", "Railings", "Gunports", "Cannons"):
        sub_empty = objs[sub_name]
        children = list(sub_empty.children)
        bpy.data.objects.remove(sub_empty, do_unlink=True)
        flatten_group(children, sub_name, (0.0, 0.0, 0.0), hull)

    # Mast assemblies: partition children by prefix into contract objects.
    # Partition FIRST (pure reads), flatten after — flatten_group deletes the
    # originals, and iterating removed objects raises ReferenceError.
    def take(children, *prefixes):
        matched = [o for o in children if o.name.lower().startswith(prefixes)]
        for o in matched:
            children.remove(o)
        return matched

    # Foremast: the square-rigged mast, same shape as the frigate build.
    fore = objs["ForemastAssembly"]
    children = list(fore.children)
    fore_pivot = (0.0, fore_deck, -0.85)
    plan = [(take(children, "mast_", "gold_mast_band_"), "Mast_Fore", fore_pivot)]
    for prefix, contract, sail_prefix, sail_name, frac in (
        ("lower", "Lower", "sail_course_", "Sail_Fore_Course", 0.47),
        ("upper", "Upper", "sail_topsail_", "Sail_Fore_Topsail", 0.90),
    ):
        pivot = (0.0, fore_deck + 2.25 * frac, -0.85)
        plan.append((take(children, f"yard_{prefix}_"), f"Yard_Fore_{contract}", pivot))
        plan.append((take(children, sail_prefix), sail_name, pivot))
    plan.append((take(children, "rigging_"), "Rigging_Fore", fore_pivot))
    for group, name, pivot in plan:
        flatten_group(group, name, pivot, fore)

    # Mainmast: bare kit pole + the boom/gaff pair. Boom, gaff, jaws, and the
    # iron collar all fold into Yard_Main_Gaff pivoted at the boom jaw on the
    # mast axis, so a swing about the pivot moves the whole fore-aft rig.
    main = objs["MainmastAssembly"]
    children = list(main.children)
    main_pivot = (0.0, main_deck, 0.32)
    gaff_pivot = (0.0, main_deck + 0.345, 0.32)
    plan = [
        (take(children, "mast_", "gold_mast_band_"), "Mast_Main", main_pivot),
        (take(children, "yard_"), "Yard_Main_Gaff", gaff_pivot),
        (take(children, "sail_gaff_"), "Sail_Main_Gaff", gaff_pivot),
        (take(children, "rigging_"), "Rigging_Main", main_pivot),
    ]
    for group, name, pivot in plan:
        flatten_group(group, name, pivot, main)

    # Bowsprit assembly: spar as one piece, the jib, and its rigging.
    bowsprit_assembly = objs["BowspritAssembly"]
    children = list(bowsprit_assembly.children)
    spar_pivot = (0.0, 0.58, -2.14)
    spars = take(children, "bowsprit_")
    sails = take(children, "sail_")
    rig = take(children, "rigging_")
    flatten_group(spars, "Bowsprit", spar_pivot, bowsprit_assembly)
    flatten_group(sails, "Sail_Bowsprit", (0.0, 0.945, -2.98), bowsprit_assembly)
    flatten_group(rig, "Rigging_Bowsprit", spar_pivot, bowsprit_assembly)

    # Streamers: bake each individually (contract-case names); anchors stay empties.
    flags = objs["Flags"]
    for old, new, root in (
        ("Streamer_fore", "Streamer_Fore", (0.0, fore_deck + 2.25 + 0.05, -0.82)),
        ("Streamer_main", "Streamer_Main", (0.0, main_deck + 2.55 + 0.05, 0.37)),
    ):
        flatten_group([objs[old]], new, root, flags)

    bpy.context.view_layer.update()

    def print_tree(obj, depth=0):
        total = 1
        slots = ""
        if obj.type == "MESH":
            slots = "  [" + ", ".join(m.name for m in obj.data.materials) + "]"
        print("  " * depth + f"{obj.name} ({obj.type}){slots}")
        for child in sorted(obj.children, key=lambda o: o.name):
            total += print_tree(child, depth + 1)
        return total

    node_count = print_tree(objs["Brig"])
    print(f"GLB node count (incl. root): {node_count}")

    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        export_yup=False,
        export_apply=True,
        export_animations=False,
    )
    print(f"exported: {GLB_PATH}")


if __name__ == "__main__":
    main()
