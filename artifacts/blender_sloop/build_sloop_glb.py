"""Build assets/models/sloop.glb from the generator (brief deliverable S5).

Run headless:
  blender --background --python artifacts/blender_sloop/build_sloop_glb.py

Rebuilds the ship without lights/camera, flattens every terminal group into a
single world-baked mesh (applying bevel/solidify modifiers and converting the
rigging curves), renames objects to the naming contract (root Sloop, the
single-mast tree: Main key only, no Fore/Mizzen; boom+gaff fold into
Yard_Main_Gaff pivoted at the boom jaw on the mast axis, brig precedent), and
exports a GLB with the exporter's Z-up->Y-up conversion DISABLED: the model
is authored Y-up / -Z-forward inside Blender, which already matches the glTF
convention.
"""
import importlib.util
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
GLB_PATH = HERE.parent.parent / "assets" / "models" / "sloop.glb"

sys.path.insert(0, str(HERE.parent))

from ship_kit import flatten_group, flatten_materials_for_export

spec = importlib.util.spec_from_file_location("sloop_gen", HERE / "create_sloop.py")
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
    main_deck = gen.mast_deck_y(-0.12)

    # Hull: collapse each join-target sub-group into one mesh of the same name.
    hull = objs["Hull"]
    for sub_name in ("HullMesh", "Deck", "Sterncastle", "Railings", "Gunports", "Cannons"):
        sub_empty = objs[sub_name]
        children = list(sub_empty.children)
        bpy.data.objects.remove(sub_empty, do_unlink=True)
        flatten_group(children, sub_name, (0.0, 0.0, 0.0), hull)

    # Partition FIRST (pure reads), flatten after — flatten_group deletes the
    # originals, and iterating removed objects raises ReferenceError.
    def take(children, *prefixes):
        matched = [o for o in children if o.name.lower().startswith(prefixes)]
        for o in matched:
            children.remove(o)
        return matched

    # Mainmast: bare kit pole + the boom/gaff pair (jaws + iron collar fold
    # into Yard_Main_Gaff pivoted at the boom jaw on the mast axis).
    main = objs["MainmastAssembly"]
    children = list(main.children)
    main_pivot = (0.0, main_deck, -0.12)
    gaff_pivot = (0.0, main_deck + 0.300, -0.12)
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
    spar_pivot = (0.0, 0.44, -1.90)
    spars = take(children, "bowsprit_")
    sails = take(children, "sail_")
    rig = take(children, "rigging_")
    flatten_group(spars, "Bowsprit", spar_pivot, bowsprit_assembly)
    flatten_group(sails, "Sail_Bowsprit", (0.0, 0.762, -2.75), bowsprit_assembly)
    flatten_group(rig, "Rigging_Bowsprit", spar_pivot, bowsprit_assembly)

    # Streamer: bake individually (contract-case name); anchors stay empties.
    flags = objs["Flags"]
    flatten_group([objs["Streamer_main"]], "Streamer_Main", (0.0, main_deck + 2.15 + 0.05, -0.07), flags)

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

    node_count = print_tree(objs["Sloop"])
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
