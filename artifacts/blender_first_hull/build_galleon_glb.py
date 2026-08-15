"""Build assets/models/galleon.glb from the generator (plan deliverable D6).

Run headless:
  blender --background --python artifacts/blender_first_hull/build_galleon_glb.py

Rebuilds the ship without lights/camera, flattens every terminal group into a
single world-baked mesh (applying bevel/solidify modifiers and converting the
rigging curves — a manual bmesh merge, because bpy.ops.object.join keeps only
the active object's modifiers), renames objects to the naming contract from
docs/design/galleon-sails-rigging-plan.md, gives masts/yards/sails useful
pivots, and exports a GLB with the exporter's Z-up->Y-up conversion DISABLED:
the model is authored Y-up / -Z-forward inside Blender, which already matches
the glTF convention, so the default conversion would tip the ship on its side.
"""
import importlib.util
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix

HERE = Path(__file__).resolve().parent
GLB_PATH = HERE.parent.parent / "assets" / "models" / "galleon.glb"

spec = importlib.util.spec_from_file_location("galleon_gen", HERE / "create_galleon_hull.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


def flatten_materials_for_export():
    # The wood/paint materials drive Base Color through procedural node graphs
    # (noise grain) that glTF cannot represent — the exporter falls back to a
    # WHITE base color factor, which shipped an all-white galleon into Godot.
    # For the export build only, unlink those inputs so the flat base colors
    # already stored on each Principled BSDF export instead (ADR 0010's
    # flat-materials-first decision; a bake pass is the future upgrade path).
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        tree = material.node_tree
        bsdf = tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        for socket_name in ("Base Color", "Normal"):
            socket = bsdf.inputs.get(socket_name)
            if socket is not None and socket.is_linked:
                for link in list(socket.links):
                    tree.links.remove(link)


def flatten_group(objects, name, pivot, parent):
    # Merge the group's evaluated geometry (modifiers applied, curves beveled)
    # into one mesh whose object origin sits at the requested pivot.
    deps = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    materials = []
    slot_of = {}
    for obj in objects:
        if obj.type not in {"MESH", "CURVE"}:
            continue
        evaluated = obj.evaluated_get(deps)
        mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=deps)
        mesh.transform(obj.matrix_world)
        remap = []
        for m in mesh.materials:
            if m is None:
                remap.append(0)
                continue
            if m.name not in slot_of:
                slot_of[m.name] = len(materials)
                materials.append(m)
            remap.append(slot_of[m.name])
        if remap:
            for poly in mesh.polygons:
                poly.material_index = remap[min(poly.material_index, len(remap) - 1)]
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    out = bpy.data.meshes.new(f"{name}Mesh")
    bm.to_mesh(out)
    bm.free()
    for m in materials:
        out.materials.append(m)
    out.transform(Matrix.Translation((-pivot[0], -pivot[1], -pivot[2])))
    out.update()
    joined = bpy.data.objects.new(name, out)
    bpy.context.collection.objects.link(joined)
    joined.location = pivot
    joined.parent = parent
    joined.matrix_parent_inverse = parent.matrix_world.inverted()
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    return joined


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
    fore_deck = gen.side_point(-1.08, 1, 0.985, -0.020)[1]
    main_deck = gen.side_point(-0.05, 1, 0.985, -0.020)[1]
    mizzen_deck = gen.side_point(1.05, 1, 0.985, -0.020)[1]

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

    build_mast("ForemastAssembly", "Fore", -1.08, fore_deck, 2.70,
               [("lower", "Lower", 0.47), ("upper", "Upper", 0.90)])
    build_mast("MainmastAssembly", "Main", -0.05, main_deck, 3.20,
               [("lower", "Lower", 0.47), ("upper", "Upper", 0.90)])
    build_mast("MizzenAssembly", "Mizzen", 1.05, mizzen_deck, 2.55,
               [("lateen", "Lateen", 0.55)])

    # Bowsprit assembly: spars (incl. sprit yard) as one piece, sail, rigging.
    bowsprit_assembly = objs["BowspritAssembly"]
    children = list(bowsprit_assembly.children)
    spar_pivot = (0.0, 1.28, -2.46)
    spars = [o for o in children if o.name.lower().startswith("bowsprit_")]
    sails = [o for o in children if o.name.lower().startswith("sail_")]
    rig = [o for o in children if o.name.lower().startswith("rigging_")]
    flatten_group(spars, "Bowsprit", spar_pivot, bowsprit_assembly)
    flatten_group(sails, "Sail_Bowsprit", (0.0, 1.84, -3.06), bowsprit_assembly)
    flatten_group(rig, "Rigging_Bowsprit", spar_pivot, bowsprit_assembly)

    # Streamers: bake each individually (contract-case names); anchors stay empties.
    flags = objs["Flags"]
    for old, new, root in (
        ("Streamer_fore", "Streamer_Fore", (0.0, 3.44, -1.05)),
        ("Streamer_main", "Streamer_Main", (0.0, 3.91, -0.02)),
        ("Streamer_mizzen", "Streamer_Mizzen", (0.0, 3.35, 1.08)),
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

    node_count = print_tree(objs["Galleon"])
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
