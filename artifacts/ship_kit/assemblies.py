"""Godot-facing assembly organization (naming contract support).

The contract lives in docs/design/galleon-sails-rigging-plan.md: a root empty,
Hull with join-target sub-groups, per-mast assemblies, Flags, EffectsAnchors.
classify_common handles every cross-ship prefix; ships layer their own rules
on top (hull decor, sterncastle parts, class-specific railing pieces).
"""
import bpy

BASE_ASSEMBLY_TREE = {
    "Hull": ["HullMesh", "Deck", "Sterncastle", "Railings", "Gunports", "Cannons"],
    "ForemastAssembly": [],
    "MainmastAssembly": [],
    "MizzenAssembly": [],
    "BowspritAssembly": [],
    "Flags": [],
    "EffectsAnchors": [],
}

BASE_MAST_ASSEMBLIES = {
    "fore": "ForemastAssembly",
    "main": "MainmastAssembly",
    "mizzen": "MizzenAssembly",
    "bowsprit": "BowspritAssembly",
}


def classify_common(n, mast_assemblies=BASE_MAST_ASSEMBLIES):
    # n must already be lowercased. Returns a group name or None.
    if n.startswith(("mast_", "yard_", "sail_", "rigging_", "gold_mast_band_")):
        for key, assembly in mast_assemblies.items():
            if n.endswith("_" + key):
                return assembly
    if n.startswith(("streamer_", "anchor_flag")):
        return "Flags"
    if n.startswith("anchor_fire"):
        return "EffectsAnchors"
    if n.startswith("mastpartner_"):
        # Deck socket hardware stays visible when a mast assembly is hidden.
        return "Deck"
    if n.startswith("bowsprit_"):
        return "BowspritAssembly"
    if "gundeck_port" in n:
        return "Gunports"
    if "deck_cannon" in n:
        return "Cannons"
    if n.startswith(("rail_post", "top_rail_", "mid_rail_")):
        return "Railings"
    if n.startswith(("deck_", "quarterdeck_")):
        return "Deck"
    return None


def organize_assemblies_from(root_name, tree, assembly_locations, classify, default_group="HullMesh"):
    # Runs right after the ship geometry is built, while every scene object is
    # ship geometry (lights/camera/origin marker come afterwards and stay
    # unparented). Parents preserve world transforms — this must not move a
    # vertex. classify(name) -> group name or None (None falls back to
    # default_group and is reported).
    ship_objects = list(bpy.context.scene.objects)

    def add_empty(name, location=(0.0, 0.0, 0.0), parent=None):
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_size = 0.1
        empty.location = location
        bpy.context.collection.objects.link(empty)
        if parent is not None:
            empty.parent = parent
        return empty

    root = add_empty(root_name)
    groups = {}
    for assembly, children in tree.items():
        assembly_empty = add_empty(assembly, assembly_locations.get(assembly, (0.0, 0.0, 0.0)), root)
        groups[assembly] = assembly_empty
        for child in children:
            groups[child] = add_empty(child, parent=assembly_empty)

    bpy.context.view_layer.update()

    unclassified = []
    counts = {}
    for obj in ship_objects:
        group_name = classify(obj.name)
        if group_name is None:
            unclassified.append(obj.name)
            group_name = default_group
        group = groups[group_name]
        obj.parent = group
        obj.matrix_parent_inverse = group.matrix_world.inverted()
        counts[group_name] = counts.get(group_name, 0) + 1

    print("assembly organization:")
    for group_name in sorted(counts):
        print(f"  {group_name}: {counts[group_name]} objects")
    if unclassified:
        print(f"  WARNING {len(unclassified)} unclassified (defaulted to {default_group}):")
        for name in unclassified:
            print(f"    {name}")
    return root
