# Galleon Sails, Rigging & Godot Integration Plan

Status/tracking doc for completing the healthy galleon visual asset and integrating it into the game. Written 2026-08-15 from the user's "PPR Galleon Rigging, Sails & Godot Asset Integration Brief" (concept sheet: `visual-breif-masts-sails-and-rigging.png`, user's Downloads) plus five agreed amendments after repo review. **This doc is the cross-session tracker for this work** — update deliverable checkboxes and the session log as work lands. Related: ADR 0010 (architecture decisions), `ship-asset-pipeline.md` (pipeline context, harmonized 2026-08-15), `visual-improvement-plan.md` (master visual status).

## Objective

One beautiful, healthy, properly structured galleon — masts, sails, rigging, streamers — exported as a modular GLB and sailing in the existing naval battle scene. No damage variants this pass, but no architecture that blocks them later.

## Ground truth this plan is built on

- The galleon is generated end-to-end by `artifacts/blender_first_hull/create_galleon_hull.py` (regenerable, deterministic; the `.blend` and renders are derived output). Alpha hull complete as of commit `766dcfc`.
- Masts exist only as short stubs plus a bowsprit — full masts, tops, and yards are **new geometry**, roughly as much work as sails + rigging combined.
- The model is hundreds of tiny objects; raw export would swamp Godot. A join pass is required.
- Hull/paint/gold materials are procedural Blender node graphs; glTF export flattens them to base color + roughness. The Cycles renders will always read richer than the in-engine result.
- The model is authored Y-up / −Z-forward *inside* Blender; glTF export must skip the exporter's default Z-up→Y-up conversion or the ship imports on its side.
- Model hull length 4.35 matches the `galleon_basic` profile's pre-scale dimensions (profile applies scale 1.65), so the GLB drops into the existing slot.
- `ShipVisualBuilder.gd` already runs faction sail tint, sail trim/billow, flag billboards, damage overlay, fire sockets, and mast break (`set_mast_broken` hides `sail_nodes`) — integration extends this builder, never bypasses it.

## Agreed amendments to the brief (2026-08-15)

1. **Reorganize inside the generator, not by hand.** Assembly structure, renames, and joins are script changes followed by regenerate + render diff. The brief's "if separation is risky, leave intact" fallback is unnecessary.
2. **Mast construction is a headline deliverable** (D2), not a contingency — only stubs exist today.
3. **Join pass is mandatory** (D6): collapse decor into per-part meshes, target ≤ ~40 nodes in the GLB.
4. **Flat materials first.** Accept simplified/flat stylized materials for this pass; texture baking is a follow-up only if the in-game result misses the North Star at gameplay distance.
5. **Integrate via `mode: mesh` profiles with anchor-based flags.** Faction flags stay in the existing procedural flag system, attaching at anchor empties in the GLB; the GLB carries only decorative streamers. Sails use a neutral tint-friendly canvas material so faction palettes keep working.

## Target GLB hierarchy and naming contract

Verify this exact hierarchy after Godot import (D6/D7 acceptance). Empties export as plain Node3D.

```text
Galleon
├── Hull
│   ├── HullMesh            # hull skin + beakhead + figurehead + stern fairing
│   ├── Deck                # shaped deck, hatches, stairs, plank separators
│   ├── Sterncastle         # gallery tiers, windows, doors, balcony, ornament
│   ├── Railings            # posts, rails, caps, stanchions
│   ├── Gunports            # port assemblies both decks
│   └── Cannons             # barrels both decks
├── ForemastAssembly
│   ├── Mast_Fore           # lower mast + top + topmast, joined
│   ├── Yard_Fore_Lower
│   ├── Yard_Fore_Upper
│   ├── Sail_Fore_Course
│   ├── Sail_Fore_Topsail
│   └── Rigging_Fore        # all fore standing rigging, one joined mesh
├── MainmastAssembly
│   ├── Mast_Main
│   ├── Yard_Main_Lower
│   ├── Yard_Main_Upper
│   ├── Sail_Main_Course
│   ├── Sail_Main_Topsail
│   └── Rigging_Main
├── MizzenAssembly
│   ├── Mast_Mizzen
│   ├── Yard_Mizzen_Lateen
│   ├── Sail_Mizzen_Lateen
│   └── Rigging_Mizzen
├── BowspritAssembly
│   ├── Bowsprit            # existing spar, completed
│   ├── Sail_Bowsprit       # spritsail
│   └── Rigging_Bowsprit
├── Flags
│   ├── Streamer_Fore
│   ├── Streamer_Main
│   ├── Streamer_Mizzen
│   ├── Anchor_Flag_Stern   # empty — existing flag system's stern_ensign
│   └── Anchor_Flag_Main    # empty — existing flag system's mast_pennant
└── EffectsAnchors
    ├── Anchor_Fire_Deck    # empty — supersedes profile deck_fire_main coords
    └── Anchor_Fire_Sail    # empty — supersedes profile sail_fire_main coords
```

**Material slots** (joins keep materials as slots): `Wood_Dark`, `Wood_Deck`, `Paint_Red`, `Gold_Trim`, `Black_Iron`, `Canvas_Sail` (neutral/whitish — tinted per faction at runtime), `Rope_Rigging`, `Streamer`.

**Conventions:** origin at waterline center, forward −Z, +X starboard, 1 unit = 1 pre-scale Godot meter, hull length 4.35. Sail pivots at their yard attachment; mast pivots at deck partner.

## Deliverables

Work top to bottom; each deliverable ends with regenerate + render check (and from D6 on, the smoke test gate).

### D1 — Generator reorganization and assembly tagging  `[x]` (2026-08-15)

Restructure `create_galleon_hull.py` output into the hierarchy above without changing appearance: parent empties per assembly, contract names on kept-separate objects, existing stubs/bowsprit assigned to their assemblies. No new geometry.

**Accept:** regenerated renders visually identical to current set; Blender outliner shows the assembly tree; no orphan objects at root.

### D2 — Masts and yards  `[x]` (2026-08-15)

Full-height fore/main masts (lower + top + topmast) grown from the existing stubs' deck sockets, mizzen mast, completed bowsprit, and all yards per the sail plan (fore/main lower + upper, mizzen lateen yard, sprit yard if needed). Proportions per the concept sheet side view: mainmast tallest, mast rake subtle.

**Accept:** side-view render silhouette matches the concept sheet's sail-plan panel proportions; masts visually seated in their deck sockets; ornamental stern mast retained and untouched.

### D3 — Sails (healthy, moderately filled)  `[x]` (2026-08-15)

Six sail meshes, each its own object with the contract name: Fore Course, Fore Topsail, Main Course, Main Topsail, Mizzen Lateen, Spritsail. Subdivided grids (~12×10) with the moderate wind fill baked into the mesh, billowed toward −Z (bow-ward, matching the runtime wind convention). `Canvas_Sail` material only — neutral/whitish so runtime faction tint reads.

**Accept:** each sail independently hideable in Blender; render at gameplay distance reads clearly; no sail merged into hull, mast, or another sail; topology deformable (no zero-area strips, even grid).

### D4 — Rigging (stylized, per-assembly)  `[x]` (2026-08-15)

Major lines only: forestays, backstays, shrouds (with a simple ratline hint at most), yard lifts, mizzen and bowsprit stays — matching the concept sheet's stern-detail rigging points. Low-poly tubes (4–6 sides), joined into one mesh per group: `Rigging_Fore/Main/Mizzen/Bowsprit`. `Rope_Rigging` material.

**Accept:** masts read as physically connected to the hull from the gameplay camera; gun decks and silhouette not obscured; four rigging meshes total; no per-rope objects survive export.

### D5 — Streamers and anchor empties  `[x]` (2026-08-15)

Three restrained streamers (fore/main/mizzen mastheads) with gentle baked curl, `Streamer` material. Four anchor empties: `Anchor_Flag_Stern`, `Anchor_Flag_Main`, `Anchor_Fire_Deck`, `Anchor_Fire_Sail`, placed to match/improve the current profile coordinates.

**Accept:** streamers read as movement accents, not clutter; empties present and correctly placed in the Blender scene.

### D6 — Join pass, export script, GLB  `[x]` (2026-08-15)

Join pass in the generator collapsing hull decor into the six Hull meshes and per-mast parts per the contract. Headless export step (extend the generator or a sibling script) producing `assets/models/galleon.glb` with the Y-up conversion **disabled** (model is already Y-up) and transforms applied. Run Godot `--headless --import` after adding the file (known gotcha for new assets).

**Accept:** GLB ≤ ~40 nodes; imported scene in Godot shows the exact contract hierarchy; ship upright, bow toward −Z, hull length 4.35 before profile scale; regenerate → export is one command sequence reproducible from this doc.

### D7 — Godot integration via ShipVisualBuilder mesh mode  `[x]` (2026-08-15)

`GalleonVisual.tscn` wrapper (inherited scene over the GLB import, no gameplay logic). Profile support: `mode: mesh` + scene path on `galleon_basic` (hull section), keeping scale 1.65. `ShipVisualBuilder` mesh mode: instantiate the wrapper under `generated_root`, then wire existing systems by node name — `Sail_*` meshes into `sail_nodes` (faction tint applied to `Canvas_Sail`; mast break and approximate trim then work unchanged), flag system attaches at the `Anchor_Flag_*` empties, fire sockets read from `Anchor_Fire_*` empties, damage overlay sized from profile dims as today. `update_sail_trim`'s billow call must no-op safely on mesh sails (it already guards on the `sail_geometry` meta). Procedural path untouched for all other ships.

**Accept:** smoke test passes (update structure assertions if node names changed); galleon spawns in `NavalBattle.tscn` via its normal profile; faction sail tint visible; mast break hides sails; fire/flag anchors verified via `CombatEffectsProbe`/battle probe; other ship classes still procedural and unaffected.

### D8 — In-game validation and sign-off  `[x]` (2026-08-15)

`ScreenshotProbe` captures of battle and overworld scenes at real gameplay cameras; side-by-side of a Blender render vs the Godot screenshot (this is where the flat-material call is judged); wave motion/heel/wake visually correct with the new visual; consistency check beside the remaining procedural ships. User playtest sign-off.

**Accept:** user signs off at gameplay distance; smoke test passing; findings + follow-ups (e.g. "bake materials" yes/no) recorded in the session log below and in `visual-improvement-plan.md`'s progress log.

## Out of scope (deliberately)

Damaged/slack/reefed/torn sail variants, broken mast geometry beyond the existing hide-sails behavior, faction-specific hull materials, texture baking (unless D8 fails the North Star), animation/cloth systems, per-rope objects. Future sail state axes (`wind_fill` / `damage_level` / `operational_state`) are satisfied for now by: separate sail meshes, deformable grids, own material, hideable assemblies.

## Session log

| Date | Session notes |
| --- | --- |
| 2026-08-15 | Brief reviewed against repo; five amendments agreed; this plan, ADR 0010, and doc harmonization (`ship-asset-pipeline.md`, `visual-improvement-plan.md`, decision log) written. |
| 2026-08-15 | **D1 done.** `organize_assemblies()` added to the generator: 819 objects parented into the contract tree by name-prefix classification (Hull: HullMesh 94 / Deck 33 / Sterncastle 330 / Railings 61 / Gunports 240 / Cannons 40; mast assemblies hold stub+band; MastPartner deck hardware deliberately under Deck). Verified zero visual change: all six regenerated renders pixel-identical to the pre-change baseline (hash deltas were PNG encoding only). Next: D2 masts and yards. |
| 2026-08-15 | **D3 done.** Six sail meshes via a generic 13×11 grid builder (smooth-shaded, thin solidify, shared neutral `Canvas_Sail`-style material): Sail_course/topsail on fore and main, Sail_lateen_mizzen (triangular sheet along the raked yard, billowing starboard, clew held clear of the sterncastle), Sail_sprit_bowsprit. One tuning iteration after the first render read card-flat: billow peak moved to ~70% height, depths up (courses 0.34/0.40), course feet raised for air, foot edges arced between clews. Renders read as filled canvas at gameplay distance. |
| 2026-08-15 | **D4 done.** `add_rigging()`: four multi-spline curve objects (Rigging_fore/main/mizzen/bowsprit, one per group — no per-rope objects), ~38 ropes total with parabolic sag: stays, backstays, 3 shrouds/side fore+main, 2/side mizzen, course yard lifts, lateen peak lift + downhaul + sheet, bobstay + sprit-yard guys/lifts. Sail-collision-checked routing: main stay lands on the fore masthead (a bow run would pierce the fore course), bobstay starts mid-bowsprit aft of the spritsail, sprit guys run from yard tips outside the sail width. Render check: masts read connected, nothing pierces canvas, gun decks unobscured. |
| 2026-08-15 | **D8 done — plan complete.** User played a galleon-vs-galleon battle (NavalBattle launched standalone; both ships on the new model): "This looks great the battle was fun. We have proved the pipeline end to end." **Flat-material call: accepted** — no texture-bake pass needed at gameplay distance (ADR 0010 follow-up resolved). User-stated next steps: model the remaining ship classes through this pipeline, and improve the flags. Note for those efforts: overworld encounters only spawn brig/sloop (`data/encounters/overworld_ships.yaml`) — a galleon encounter there is still a quick win; pipeline generalization targets live in `ship-asset-pipeline.md` (spec YAML, `assets/ships/` layout, validator — deferred until the second ship). |
| 2026-08-15 | **D6 done.** `build_galleon_glb.py` (sibling of the generator): rebuilds the ship without lights/camera, flattens every terminal group into one world-baked mesh via depsgraph evaluation + manual bmesh merge (applies bevel/solidify, converts rigging curves; `bpy.ops.object.join` would have dropped non-active modifiers), renames to the contract, sets pivots (mast foot / yard line), exports `assets/models/galleon.glb` with `export_yup=False` (model is authored Y-up in Blender — the exporter's default conversion tips it over). 40 nodes, 3.7 MB, round-trip verified (upright, −Z forward, anchors at gameplay-tuned coords). **Ghost-ship fix:** node-graph-driven Base Color exports as WHITE in glTF; the export build now unlinks Base Color/Normal on node materials so the stored flat colors export (renders keep full grain). Also added `artifacts/.gdignore` — Godot was scanning the Blender sources and erroring on the .blend. |
| 2026-08-15 | **D7 done.** `GalleonVisual.tscn` wrapper over the GLB; `galleon_basic` profile switched to `mode: mesh` + scene path (validator already whitelisted both fields). `ShipVisualBuilder` mesh mode: instantiates the wrapper under `generated_root`, hides + neutralizes the primitive Hull/Bow/Mast placeholders (a smoke-test assertion checks bow rotation), maps `Sail_*` meshes into `sail_nodes` with the faction tint material (mast break + trim keep working), attaches procedural flags at `Anchor_Flag_*`, overrides fire sockets from `Anchor_Fire_*`, damage overlay from profile dims. **User request mid-pass: player ship switched to `ship_type: galleon`** (`player_ship.yaml`) — both battle ships now use the model; 14-per-side loadout fits the galleon's 40 gun ports. Gates: smoke test passing (twice, incl. after the player switch), content validation 0 warnings, battle + overworld probes captured. |
| 2026-08-15 | **D5 done.** Three bright-red masthead streamers (tapering ribbon grids with baked aft S-curl, matching the concept banners): Streamer_fore/main/mizzen under Flags. Four anchor empties: Anchor_Flag_Stern (ornamental stern mast top), Anchor_Flag_Main (main masthead), Anchor_Fire_Deck / Anchor_Fire_Sail at the gameplay-tuned `visual_states` coordinates. Verified in renders + close-up stair-region shot. |
| 2026-08-15 | **D4 fix (user report: mizzen rigging through the stern staircase).** The aft mizzen shroud pair anchored on the bulwark at z=1.30, running through the staircase treads/handrails (stairs climb z 0.74–1.86). Rerouted: forward shroud pair lands ahead of the stair foot (z=0.66), aft pair became backstays landing on the balcony corner stanchion tops — above the stairs, reading as proper mizzen backstays. |
| 2026-08-15 | **D2 done.** `add_mast_assembly()` replaced the stubs: tapered lower masts (new `add_spar` cone helper) + round tops with gold rims + overlapping topmasts with doubling bands + gold masthead finials; course/topsail yards with slings on fore (spans 1.55/1.18) and main (2.05/1.50); raked lateen yard on the mizzen overhanging the sterncastle; sprit yard + gold collar on the bowsprit. Heights match the `galleon_basic` profile (fore 2.70 / main 3.20 / mizzen 2.55 above deck) so the export stays drop-in. Render review: main tallest, silhouette matches concept sail-plan panel, no clipping (lateen clears castle, spritsail region clear of beakhead). Assemblies now Fore 11 / Main 11 / Mizzen 9 / Bowsprit 4 objects, no unclassified. |
