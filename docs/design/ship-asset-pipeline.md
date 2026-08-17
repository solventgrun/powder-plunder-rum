# Powder, Plunder & Rum — 3D Ship Asset Pipeline

Adapted 2026-08-14 from the user-supplied "Ship Asset Generation Pipeline" document (2D sprite edition). That document's process skeleton — agent-orchestrated deterministic tools, a versioned art contract, one-ship proof before fleet scale-out, measurable review criteria — is preserved here. Its output format is not: it targeted 8-heading pre-rendered sprites, which would discard this game's 3D wave motion (bob/pitch/roll/heel from `ShipWaveMotion`), continuous rotation, dynamic sail billow, and two scenes with different camera elevations. This version produces **game-ready segmented 3D models (glTF)** instead.

Status: **pilot complete and signed off (2026-08-15).** The pilot class was the **galleon** (user call — the hero ship, not a small class as the MVP table below assumed), built end to end by the deterministic generator `artifacts/blender_first_hull/create_galleon_hull.py` + `build_galleon_glb.py` → `assets/models/galleon.glb` → `GalleonVisual.tscn` → ShipVisualBuilder `mode: mesh`, and playtest-approved in battle ("proved the pipeline end to end"). Full history in `galleon-sails-rigging-plan.md`; decisions in ADR 0010 — sails are **model geometry**, not procedural attachments (see the superseded hybrid rule below), and flat export materials were accepted at gameplay distance (no bake pass). **Next: fleet scale-out** — the remaining ship classes go through this pipeline, which is when the deferred generalization (spec YAML, `assets/ships/` layout, validation script, M7–M8) gets built.

## Design principle

The agent is the orchestrator, not the artist of record. It drives deterministic, scriptable tools — Blender headless (`blender --background --python <script>.py`), Godot headless/windowed (smoke test, `ScreenshotProbe`), and optional image-generation or image-to-3D services — through repeatable scripts and a versioned specification. A GUI is for inspection, never a required production step.

**The honest bottleneck** (the source doc hand-waves this): Stage 2, acquiring the canonical source asset, is still the artistic hard part. The pipeline makes iteration reproducible; it does not make the model good. Budget the modeling/purchase/commission decision separately (see `visual-improvement-plan.md` North Star notes: CC0 kits → purchase → commission → DIY, in rising cost-of-user-time order).

## Goals

- One canonical 3D source per ship class, convincing from the actual gameplay cameras (battle follow camera and overworld oblique camera — both, since the model is live 3D).
- Full compatibility with existing runtime systems: wave motion, heel, sail tint/trim/mast-break plumbing, wakes, faction recolor, damage states, fire sockets.
- Chunky silhouettes readable at 1080p gameplay zoom, per the North Star. Stylized, not photoreal.
- A repeatable build: art-direction change → re-run → whole fleet updates.
- Deterministic naming, scale, orientation, pivots, and import settings, mechanically validated.
- Special vessels (faction flagships, the Flying Dutchman) extend the pipeline via overrides, never bypass it.

## Non-goals

- Film-quality models or universal geometric correctness — only the game cameras matter.
- Rigged/simulated cloth sails — modeled sails bake a static wind fill (ADR 0010); no cloth sim or armatures.
- Replacing the engine's transient effects with baked geometry.
- Training or fine-tuning custom generative models.

## The hybrid rule — SUPERSEDED for sails (ADR 0010, 2026-08-15)

Original rule: model ships without sails; `ShipVisualBuilder`'s procedural billowing sails attach at yard sockets. **Superseded:** sails are now modeled into the GLB — one named mesh per sail, subdivided deformable grids with moderate wind fill baked in, on a neutral tint-friendly canvas material. Rationale: the galleon is the hero visual; the concept-sheet silhouette, per-sail damage swaps, and material control want real meshes, and procedural quads beside modeled rigging would read as the weakest part of the flagship. Cost accepted: runtime billow deformation doesn't apply to mesh sails (trim degrades to scale/rotation), and mast break/faction tint are preserved by mapping the named sail meshes into the builder's existing `sail_nodes` instead of attaching procedural ones.

**Flags DO remain procedural** (runtime-generated 96x64 faction textures on flat quads) — the model carries decorative streamers plus `Anchor_Flag_*` empties where the existing flag system attaches, so faction swapping needs no model work.

## Toolchain

| Component | Role | Notes |
| --- | --- | --- |
| Agent (Claude Code session) | Planning, scripting, running builds, comparing renders against criteria, Godot integration | Uses the same probe-and-gate workflow as all visual work |
| Blender | Source asset assembly, normalization, segmentation, glTF export | Free; fully scriptable headless via Python API. Check installation before pilot (`blender --version`) |
| Godot 4.7 | Import, hybrid `ShipVisualBuilder` integration, in-game validation | Existing smoke test + `ScreenshotProbe.tscn` + `CombatEffectsProbe.tscn` |
| Python | Blender-side automation and export validation scripts | Only inside Blender's bundled interpreter; project glue stays GDScript/PowerShell |
| Image generation (optional) | Concept art for silhouette/ornament decisions | One canonical concept per class; never per-variant generation |
| Image-to-3D (optional) | Draft mesh from a strong concept | Treat output as a starting point needing topology cleanup; fine for props, risky for the hero hull |

Keep the Phase 1 stack to Agent + Blender + Godot. Add anything else only against a demonstrated bottleneck.

## End-to-end stages

**Stage 0 — Art specification.** Lock the machine-readable contract (below) before modeling: scale conventions, orientation, segmentation names, socket set, material slots, polygon budget, style rules.

**Stage 1 — Concept.** One or more concepts per ship class; judge on silhouette and 1080p readability, not detail. Select a single canonical design. The North Star reference image sets palette and richness.

**Stage 2 — Source asset construction.** Manual low-poly modeling, licensed/CC0 asset, or image-to-3D draft + cleanup. Only the game cameras must be convinced. This is the cost center — decide the sourcing route with the user per class.

**Stage 3 — Blender normalization.** Import into the standard template scene. Apply: 1 Blender unit = 1 Godot meter; ship forward = **-Z**, +X = starboard (matches `ShipWaveMotion` and controller conventions); origin at the waterline center so wave bob/pitch/roll pivot correctly; apply all transforms; consistent flat-shaded/low-poly material style. **Pilot caveat (paid-for lesson):** the galleon generator authors Y-up/−Z-forward *inside* Blender (Blender itself is Z-up; the render cameras compensate with a 90° roll), so glTF export must disable the exporter's default Z-up→Y-up axis conversion or the ship imports on its side. **Material caveat:** procedural node materials (noise grain, bump) flatten to base color + roughness on glTF export — plan flat/simplified export materials or a bake pass; the pilot ships flat-first (ADR 0010).

**Stage 4 — Segmentation and sockets** *(replaces the 2D doc's "base render set")*. Separate and name nodes per the contract: hull part meshes, per-mast assemblies (mast, yards, sails, rigging — for mast break and future sail damage), and empties for flags and fire points. No merged single-mesh exports — but also no object spray: script-generated models must include a **join pass** collapsing decor into the contract meshes (the galleon generator emits hundreds of tiny objects; the GLB targets ≤ ~40 nodes).

**Stage 5 — State variants.** Durable structural states only: damaged-hull material set or geometry swaps (scorch/holes), broken mast stumps as hidden-by-default segments, damaged sail mesh swaps (future — healthy sails only in the pilot). Faction identity comes from material slot recolors + runtime sail tint + procedural flags, not per-faction meshes. The goal this mechanism serves — every faction identifiable from the vessel itself at combat distance — is specified in the expansion brief's "Faction Livery Kits" backlog entry (2026-08-17), including the class-color-vs-faction-color tension to settle first.

**Stage 6 — Export and mechanical validation.** Export `.glb` (glTF binary). A validation script (Blender-side Python) checks: node names against the contract, socket presence, scale/orientation, transform application, triangle budget, material slot names. Emit a manifest (source file hash, spec version, node/socket inventory).

**Stage 7 — Godot integration.** Extend `ShipVisualBuilder` to mesh mode: when a ship profile specifies `mode: mesh`, instantiate the wrapper scene (e.g. `GalleonVisual.tscn` over the imported `.glb`) under `generated_root` in place of the procedural meshes; map named `Sail_*` meshes into `sail_nodes` (faction tint, mast break, and approximate trim then work unchanged); attach the procedural flag system at `Anchor_Flag_*` empties; read fire positions from `Anchor_Fire_*` empties (superseding the profile's hand-authored `visual_states` coordinates for that class). Everything downstream — `ShipWaveMotion`, `ShipWake`, combat effects, damage flow — is untouched because it targets `VisualRoot`/body, not the meshes.

**Stage 8 — In-game validation.** Smoke test must pass (structure assertions may need the hybrid node names). Probe both scenes plus `CombatEffectsProbe`; then playtest at real gameplay zoom against the review criteria. Iterate by changing the smallest upstream variable and re-running the build — never by hand-editing exported output.

Canonical flow: `ART SPEC → CONCEPT → SOURCE 3D → NORMALIZE → SEGMENT/SOCKET → EXPORT+VALIDATE → GODOT HYBRID → IN-GAME QA`

## Art direction contract (versioned, machine-readable)

Store as `art_direction/ship_model_spec.yaml`. Illustrative shape — exact fields evolve with the pilot:

```yaml
ship_model_spec:
  version: 1
  units: meters                # 1 Blender unit = 1 Godot meter
  forward_axis: "-Z"           # matches ShipWaveMotion / controllers
  starboard_axis: "+X"
  origin: waterline_center     # wave motion pivots here
  triangle_budget:
    sloop: 8000
    frigate: 15000
    galleon: 20000
  style:
    shading: stylized_flat     # chunky, readable at 1080p; no photoreal PBR
    palette_ref: docs/design/visual-improvement-plan.md#north-star
  required_nodes:
    hull: "Hull"
    masts: "Mast_{n}"          # each mast a separate segment
    mast_stumps: "MastStump_{n}"   # hidden by default; shown on mast break
  required_sockets:            # glTF empties; positions read at import
    flags: "Anchor_Flag_{n}"   # sails are model meshes since ADR 0010, no sail sockets
    fire_points: "Anchor_Fire_{n}"
  material_slots:
    faction_recolor: ["HullPaint", "Trim"]
    fixed: ["Deck", "Wood", "Rope"]
  export:
    format: glb
    apply_transforms: true
  runtime_stays_in_engine: [sails, flags, wake, bow_spray, muzzle_flash,
                            cannon_smoke, splashes, fire, debris, selection]
```

Why this matters (unchanged from the source doc): a convention change regenerates the fleet instead of hand-edits; every class reviews against the same target; the agent validates mechanically; special ships override fields without leaving the pipeline.

## File conventions

**Pilot reality (2026-08-15):** the galleon's canonical source is the generator script `artifacts/blender_first_hull/create_galleon_hull.py` (the `.blend` and renders are derived output), and the build output goes to `assets/models/galleon.glb`. **The shared machinery now lives in `artifacts/ship_kit/`** (extracted post-sign-off and verified pixel-identical against the galleon): materials, primitives, `HullForm` hull math, mast assemblies, sail grids, rope rigging, assembly organization, the review render rig, and the GLB flatten/export helpers. Per-ship generators own only their station profile, decoration, sail plan, rigging routes, and anchors. **The galleon render-diff is the kit's regression gate** — any kit change requires a galleon regenerate + pixel compare. The spec YAML and validator below remain deferred; the naming/material contract lives in `galleon-sails-rigging-plan.md`. Ship #2 is briefed: `frigate-visual-brief.md`.

Target layout when the pipeline generalizes:

```
assets/ships/
  sloop/
    source/sloop.blend         # canonical source (committed)
    export/sloop.glb           # build output
    export/manifest.yaml       # spec version, node/socket inventory, hashes
  shared/                      # trim-sheet materials, common props (barrels etc.)
tools/ship_pipeline/
  normalize.py                 # Blender-side: template scene enforcement
  validate.py                  # Blender-side: contract checks
  build.ps1                    # one-command build: blender --background → validate → copy into project
art_direction/
  ship_model_spec.yaml
  review_criteria.md
```

## Static model states vs runtime (engine) visuals

| Baked into the model | Stays in Godot at runtime |
| --- | --- |
| Hull shape, planking, trim geometry | Sail faction tint + trim scaling (on model sail meshes) |
| Sails, rigging, streamers (ADR 0010) | Flags (procedural textures at anchors) |
| Faction paint via material slots | Wake ribbon + bow spray |
| Persistent hull damage state | Sail hiding on mast break (`set_mast_broken`) |
| Broken mast stumps (toggled) | Muzzle flash, cannon smoke, splashes |
| Figurehead, lanterns, deck props | Fire, debris, magazine explosion |
| Supernatural base materials (Dutchman) | Spectral glow/fog/particles, selection highlights |

Rule of thumb (kept verbatim in spirit): if it persists for many seconds and changes the silhouette, it's a model state; if it's transient, stochastic, or benefits from animation, it's engine-side.

## Review criteria (measurable; "looks better" is not a loop condition)

| Criterion | Question |
| --- | --- |
| Silhouette | Is the class recognizable at gameplay zoom in both scenes? |
| Wave-motion fit | Does bob/pitch/roll/heel pivot naturally (origin at waterline, no keel float/clip)? |
| Scale consistency | Does a sloop read smaller than a frigate without becoming unreadable? |
| Style cohesion | Does the model sit beside procedural ships/towns without making them look broken? (the consistency cliff — judged per playtest) |
| Sail integration | Do the modeled sails hang plausibly from their yards, read filled at gameplay zoom, and take faction tint cleanly? |
| Faction distinction | Do recolored slots + flags read at distance without hiding the class? |
| Damage readability | Healthy vs damaged vs critical distinguishable mid-combat? |
| Socket correctness | Muzzle flashes at gun ports, fire on deck, flags on masts — verified via `CombatEffectsProbe`/battle probe |
| Determinism | Does a clean re-run of the build reproduce the installed asset byte-for-byte (modulo timestamps)? |

Iteration pattern: change the smallest upstream variable → rebuild → validate → probe → (if structural) smoke test → evaluate in motion.

## Special and legendary vessels

Same pipeline, spec overrides only — same axes, origin, socket contract, and integration path.

- **Republic of Rum flagship:** visually excessive within conventions — custom trim materials, exaggerated flag sockets, decorative barrels/props from `assets/ships/shared/`, unconventional-repair geometry. The humor lives in art direction, not in breaking the contract.
- **Flying Dutchman:** layered approach. The model carries durable decay — warped spars, barnacle geometry, unnatural base palette, torn-sail *sockets* placed for tattered procedural sails. Godot adds the transient spectral layer: fog, glow pulses, particle wake, ghost-light flicker. Readability first, haunting second.

## Minimum viable pipeline: one ship

Prove it end-to-end on a single class before any fleet work. **The actual pilot is the galleon** (user call, 2026-08-15), and its milestone tracking lives in `galleon-sails-rigging-plan.md` — the table below stays as the generic template. Rough mapping: M1–M2 are done in spirit (contract in the plan doc, alpha hull built), M3–M6 correspond to plan deliverables D1–D8, M7–M8 remain future.

| Milestone | Exit condition |
| --- | --- |
| M1 — Lock spec | `ship_model_spec.yaml` v1 committed; user signs off on style + sourcing route |
| M2 — Canonical source | Rough 3D pilot ship normalized in the Blender template |
| M3 — Segment + socket | Contract nodes/sockets in place; validation script passes |
| M4 — Export | `.glb` + manifest emitted by one command |
| M5 — Integrate | Hybrid `ShipVisualBuilder` loads it; smoke test passes |
| M6 — Iterate | Probe + playtest against review criteria until it clearly beats the procedural ship |
| M7 — One variant axis | Damaged-hull state **or** second faction recolor proves reuse |
| M8 — Freeze v1 | Build documented and reproducible from `source/` in a fresh session |

## Automation interface (target shape)

```powershell
tools/ship_pipeline/build.ps1 -Ship sloop -Validate -InstallGodot
# internally: blender --background assets/ships/sloop/source/sloop.blend
#   --python tools/ship_pipeline/normalize.py
#   --python tools/ship_pipeline/validate.py   # emits manifest + report
# then copies .glb into the project and updates the ship profile's model entry
```

A build emits: the `.glb`, the manifest, a validation report, and a build log naming source hashes and spec version.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Stage 2 stalls (modeling is the real cost) | Decide sourcing per class *with the user* before starting; CC0/purchased base meshes are allowed inputs to normalization |
| Consistency cliff (one pretty ship makes procedural neighbors look worse) | Pilot is explicitly evaluated beside procedural ships in playtest before fleet commitment; style spec enforces chunky/flat shading, not asset-store realism |
| Integration tax rediscovered late | Segmentation/socket contract is Stage 0, validated at Stage 6, before any Godot work |
| Looks good in Blender, fails at gameplay zoom | Probe screenshots at real camera distances are mandatory every iteration (existing workflow) |
| Combinatorial variants | Durable states only in the model; factions via material slots; everything transient stays engine-side |
| Pipeline becomes a research project | Phase 1 stack is Agent + Blender + Godot only; image-to-3D and generators added only against a named bottleneck |
| Special ships fork the system | Spec inheritance/overrides; the Dutchman ships through the same validator |

## Definition of done, pipeline v1

- The pilot ship rebuilds from `source/` via one documented command.
- Node names, sockets, scale, orientation, and budgets validate automatically.
- The model integrates through hybrid `ShipVisualBuilder` with wave motion, procedural sails, wakes, damage, mast break, and effects all functioning — verified by the smoke test and probes.
- It looks materially better than the procedural ship at gameplay zoom, *and* the user judges the consistency cliff acceptable in a side-by-side playtest.
- One variant axis (damage or faction) is demonstrated.
- A fresh agent session can reproduce the build from this document without unstated manual steps.

## Relationship to the visual improvement plan

`visual-improvement-plan.md` remains the master status doc; this pipeline is referenced from its ship-detailing track. The agreed sequence (Tier 4 UI theme → pilot) played out: Tier 4 shipped 2026-08-14 and the galleon pilot started 2026-08-15. Active pilot work is tracked in `galleon-sails-rigging-plan.md`; incremental *procedural* detailing remains live for the other ship classes, which stay procedural until the fleet scale-out decision.
