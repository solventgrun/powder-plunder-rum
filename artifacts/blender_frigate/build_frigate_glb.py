"""Build assets/models/frigate.glb from the generator (brief deliverable F5).

Run headless:
  blender --background --python artifacts/blender_frigate/build_frigate_glb.py

Rebuilds the ship without lights/camera, flattens every terminal group into a
single world-baked mesh (applying bevel/solidify modifiers and converting the
rigging curves), renames objects to the naming contract (root Frigate, same
tree/names as the galleon with Fore/Main/Mizzen keys), gives masts/yards/sails
useful pivots, and exports a GLB with the exporter's Z-up->Y-up conversion
DISABLED: the model is authored Y-up / -Z-forward inside Blender, which
already matches the glTF convention.
"""
import importlib.util
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
GLB_PATH = HERE.parent.parent / "assets" / "models" / "frigate.glb"

sys.path.insert(0, str(HERE.parent))

from ship_kit import flatten_group, flatten_materials_for_export

spec = importlib.util.spec_from_file_location("frigate_gen", HERE / "create_frigate.py")
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
    fore_deck = gen.mast_deck_y(-1.20)
    main_deck = gen.mast_deck_y(-0.05)
    mizzen_deck = gen.mast_deck_y(1.00)

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
    def build_mast(assembly_name, key, z, deck_y, total_height, yards):
        assembly = objs[assembly_name]
        children = list(assembly.children)

        def take(*prefixes):
            matched = [o for o in children if o.name.lower().startswith(prefixes)]
            for o in matched:
                children.remove(o)
            return matched

        mast_pivot = (0.0, deck_y, z)
        plan = [(take("mast_", "gold_mast_band_"), f"Mast_{key}", mast_pivot)]
        sail_names = {"Lower": "Course", "Upper": "Topsail", "Lateen": "Lateen"}
        sail_prefixes = {"Lower": "sail_course_", "Upper": "sail_topsail_", "Lateen": "sail_lateen_"}
        for prefix, contract, height_fraction in yards:
            pivot = (0.0, deck_y + total_height * height_fraction, z)
            plan.append((take(f"yard_{prefix}_"), f"Yard_{key}_{contract}", pivot))
            sail = take(sail_prefixes[contract])
            if sail:
                plan.append((sail, f"Sail_{key}_{sail_names[contract]}", pivot))
        plan.append((take("rigging_"), f"Rigging_{key}", mast_pivot))
        for group, name, pivot in plan:
            flatten_group(group, name, pivot, assembly)

    build_mast("ForemastAssembly", "Fore", -1.20, fore_deck, 2.55,
               [("lower", "Lower", 0.47), ("upper", "Upper", 0.90)])
    build_mast("MainmastAssembly", "Main", -0.05, main_deck, 2.95,
               [("lower", "Lower", 0.47), ("upper", "Upper", 0.90)])
    build_mast("MizzenAssembly", "Mizzen", 1.00, mizzen_deck, 2.45,
               [("lateen", "Lateen", 0.55)])

    # Bowsprit assembly: spar as one piece, the jib, and its rigging.
    bowsprit_assembly = objs["BowspritAssembly"]
    children = list(bowsprit_assembly.children)
    spar_pivot = (0.0, 0.80, -2.38)
    spars = [o for o in children if o.name.lower().startswith("bowsprit_")]
    sails = [o for o in children if o.name.lower().startswith("sail_")]
    rig = [o for o in children if o.name.lower().startswith("rigging_")]
    flatten_group(spars, "Bowsprit", spar_pivot, bowsprit_assembly)
    flatten_group(sails, "Sail_Bowsprit", (0.0, 1.335, -3.34), bowsprit_assembly)
    flatten_group(rig, "Rigging_Bowsprit", spar_pivot, bowsprit_assembly)

    # Streamers: bake each individually (contract-case names); anchors stay empties.
    flags = objs["Flags"]
    for old, new, root in (
        ("Streamer_fore", "Streamer_Fore", (0.0, fore_deck + 2.55 + 0.05, -1.17)),
        ("Streamer_main", "Streamer_Main", (0.0, main_deck + 2.95 + 0.05, -0.02)),
        ("Streamer_mizzen", "Streamer_Mizzen", (0.0, mizzen_deck + 2.45 + 0.05, 1.03)),
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

    node_count = print_tree(objs["Frigate"])
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
