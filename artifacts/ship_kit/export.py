"""GLB export helpers: material flattening and modifier-applying group merge."""
import bmesh
import bpy
from mathutils import Matrix


def flatten_materials_for_export():
    # Wood/paint materials drive Base Color through procedural node graphs
    # (noise grain) that glTF cannot represent — the exporter falls back to a
    # WHITE base color factor, which once shipped an all-white galleon into
    # Godot. For the export build only, unlink those inputs so the flat base
    # colors already stored on each Principled BSDF export instead (ADR 0010's
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
    # into one mesh whose object origin sits at the requested pivot. A manual
    # bmesh merge, because bpy.ops.object.join keeps only the active object's
    # modifiers.
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
