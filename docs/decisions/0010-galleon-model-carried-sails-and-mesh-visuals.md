# ADR 0010: Galleon Model-Carried Sails and Mesh-Mode Ship Visuals

## Status

Accepted (2026-08-15)

## Context

The ship asset pipeline design (`docs/design/ship-asset-pipeline.md`, 2026-08-14) adopted a "hybrid rule": model ships without sails and attach the existing procedural billowing sails at yard sockets. Since then, the pilot ship — the galleon, built by the deterministic generator `artifacts/blender_first_hull/create_galleon_hull.py` — reached alpha hull quality, and the user supplied a rigging/sails briefing whose concept sheet defines the target silhouette with full modeled sails. Repo review also surfaced three facts the pipeline design didn't account for: the generator makes hand-editing risk arguments moot (everything regenerates), the model is hundreds of tiny objects that would swamp Godot if exported raw, and the procedural Blender node materials (wood grain, paint variation) cannot survive glTF export.

## Decision

For the galleon pilot (and, by default, future modeled ships):

1. **Sails are modeled into the GLB** — one named mesh per sail, subdivided deformable grids with a moderate wind fill baked in, on a neutral tint-friendly `Canvas_Sail` material. This supersedes the pipeline doc's hybrid rule for sails.
2. **Flags stay procedural.** The GLB carries decorative streamers plus anchor empties (`Anchor_Flag_*`); the existing runtime faction-flag system attaches there. Fire-effect positions likewise come from `Anchor_Fire_*` empties.
3. **Integration goes through `ShipVisualBuilder`** via a `mode: mesh` visual profile that instantiates a wrapper scene (`GalleonVisual.tscn`) and maps named GLB nodes into the builder's existing `sail_nodes`/flag/fire plumbing, so faction tint, mast break, damage, and combat effects work unchanged. The procedural path remains for all other ships.
4. **Asset organization happens inside the generator** (assembly parenting, contract naming, decor join pass targeting ≤ ~40 GLB nodes), verified by render diffs — never by hand-editing the .blend or the export.
5. **Flat/simplified materials ship first**; texture baking is deferred unless the in-game result misses the North Star at gameplay distance.
6. The model is authored Y-up/−Z-forward inside Blender, so export disables the glTF exporter's axis conversion; hull length 4.35 pre-scale keeps the asset drop-in for the `galleon_basic` profile (scale 1.65).

## Alternatives Considered

- **Keep the hybrid rule (procedural sails at sockets).** Preserves trim/billow animation for free, but the galleon is the hero visual: the concept-sheet silhouette, per-sail damage swaps, and material control all want real sail meshes. The procedural quads would sit visibly beside modeled rigging and read as the weakest element of the flagship asset.
- **Bake procedural materials to textures now.** Highest fidelity, but real added scope (UVs, bake rig, texture management) before we know whether flat materials fail at gameplay distance.
- **Model faction flags into the GLB.** Would duplicate the existing data-driven flag system and its per-faction textures; anchors reuse it instead.
- **One GLB per assembly.** More modular on disk, but a single GLB with named nodes is simpler to import, and Godot addresses child nodes equally well either way.

## Consequences

- Easier: per-sail hide/replace/deform for future damage states; faction tint via one neutral material; asset drops into the existing profile slot; a fresh session can regenerate and re-export deterministically.
- Harder/lost: runtime sail billow deformation doesn't apply to mesh sails (fill is baked; `update_sail_trim` degrades to scale/rotation); in-engine look will be flatter than the Cycles renders until/unless a bake pass lands.
- Deferred: texture baking, damaged sail variants, broken-mast geometry, the pipeline doc's full `assets/ships/<class>/` + spec-YAML + validator tooling (contract lives in the plan doc until a second ship needs the machinery).

## Follow-Up

- Judge the flat-material call at D8 of `docs/design/galleon-sails-rigging-plan.md` with a Blender-vs-Godot side-by-side; record the bake decision there.
- When a second modeled ship starts, promote the naming/material contract from the plan doc into the pipeline doc's machine-readable spec.
- Revisit sail trim feedback (mesh sails ignore billow) if playtests miss it during combat.
