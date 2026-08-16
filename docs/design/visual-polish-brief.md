# Flags, Combat Juice & Living Ocean — Visual Polish Brief

Written 2026-08-16 for a **fresh session**. The fleet pipeline is finished — all four ship classes (sloop, brig, frigate, galleon) sail Blender-built meshes, playtested and committed — so visual work returns to `docs/design/visual-improvement-plan.md`'s open items plus one new user directive on the ocean. The reader is assumed to have this doc, the repo, and no other context.

Three tracks, each independently shippable. Suggested order: **A (flags — small, visibly broken today) → C (ocean — the user's active complaint) → B (Tier 3 combat juice — the largest)**. Expect this to span more than one session; keep the visual plan's progress log current as items land.

## Objective

1. **Track A — Flags** that fit the mesh fleet: right-sized, wind-flown, rippling.
2. **Track B — Tier 3 completion**: fire visuals, magazine-explosion sequence, camera shake, damage listing, sinking moment, sail damage states.
3. **Track C — Ocean overhaul**: swells, livelier foam, a sea that reads *alive* — including an honest evaluation of where Blender-built assets help and where they can't.

## What already exists (do not rebuild)

- **`docs/design/visual-improvement-plan.md` is the master status doc** — North Star, guiding constraints, tier history, and two paid-for lessons that govern all of this work: *verify visuals by looking* (`tools/ScreenshotProbe.tscn` for scenes, `tools/CombatEffectsProbe.tscn` for projectile/impact effects — both self-quit, probe usage documented there), and *the smoke test gates every change* (`tools/run_smoke_test.ps1`; it occasionally exits non-zero on teardown despite printing "Smoke test passed" — rerun before investigating).
- **The mesh fleet + contract.** Ships render via `ShipVisualBuilder` `mode: mesh` (`game/scripts/visuals/ShipVisualBuilder.gd`): named `Sail_*` meshes join `sail_nodes` (faction tint via material_override, trim, mast break), `Anchor_Flag_*` / `Anchor_Fire_*` empties feed flags and fire sockets. Never edit the ship generators (`artifacts/blender_*`) or `artifacts/ship_kit/` for this work — model changes have their own regression-gated pipeline.
- **Motion architecture.** `ShipWaveMotion` on each ship's `VisualRoot` composes bob/pitch + three roll sources (wave, heel, recoil) into single rotation writes. Visual motion effects target `VisualRoot`, never the physics body. `FollowCamera` has combat framing (focus-bias anchor with smoothing).
- **Effect building blocks.** `EffectSprites.puff_texture()` / `ring_texture()` (procedural billboard sprites), `TemporaryVisual` (scale lerp + `fade_alpha`), world-space `GPUParticles3D` precedents in `Cannonball` (smoke trail) and `MuzzleFlashEffect` / `SplashEffect`.
- **The ocean stack.** `game/shaders/StylizedOcean.gdshader` + shared `StylizedOceanMaterial.tres` in both scenes: three-sine vertex displacement (`wave_height` 0.5, `wave_scale` 0.28, `wave_speed` 0.8), analytic per-pixel normals, distance-faded detail/glint layer, fbm foam web with crest boost, noise-broken whitecaps, turquoise mottling. `game/systems/OceanWaveField.gd` (autoload) owns `wave_time` and mirrors the displacement math on CPU.
- **Known gotchas** (all previously paid for): new `class_name` scripts and new assets need one `godot --headless --import` before the smoke test can resolve them; effect scene root *names* are asserted by the smoke test (the muzzle/splash upgrades kept "MuzzleFlash"/"Splash" roots — do the same); autoloads ARE live in `--script` runs, and the smoke test disables `auto_return_to_overworld` in scenes it instantiates.

## Track A — Flags

**Today:** `ShipVisualBuilder._build_flags` inflates profile flag sizes ×1.9 with hard minimums (skull 1.55×0.9, others 1.2×0.68), renders flat quads with runtime-generated 96×64 NEAREST faction textures (`_make_flag_material` — this part is good, keep it), and **billboards them at the camera every frame** (`flag_billboard_nodes` in `_process`). Mesh ships place them at the model's `Anchor_Flag_Stern` / `Anchor_Flag_Main`.

**Problems** (probe-visible): the inflation + minimums were tuned so flags read on featureless procedural boxes — on the mesh fleet they dwarf the sloop and brig outright; camera-billboarding looks wrong beside fixed modeled rigging; a rigid flat quad reads dead next to billowed sails.

**Deliverables:**
- Right-size: honor profile sizes (retire or sharply shrink the ×1.9/minimums; if skull legibility at distance still matters, scale minimums by ship `visual_scale` instead of one global floor).
- Fly with the wind, not the camera: orient flags aft/leeward like real bunting (battle scenes have a wind system; overworld NPCs don't — give them a sensible default the way wind-heel already degrades for NPCs).
- Ripple: subdivided grid with a traveling wave (the sail-billow precedent applies, including its hard-won lesson: **rebuilt meshes need explicit normals or the deformation is invisible**) — or a vertex-shader flutter; either way keep the procedural texture and anchor contract (ADR 0010: flags stay procedural).

*Accept: flags read correctly on all four classes at gameplay distance (probe all four: player battle, galleon target, Dutch Trader + Spanish Patrol overworld), no camera-facing rotation, smoke test green.*

## Track B — Tier 3 completion

The six unchecked items in the visual plan's Tier 3, with pointers:

1. **`set_fire_state()`** — still an empty stub, so fire severity (ADR 0007) has no on-ship visual. Severity-scaled flame flicker, ember particles, and a leaning smoke column at `get_fire_socket_position` positions (mesh ships feed these from `Anchor_Fire_*`). Verify with the battle probe — fires must read at gameplay distance.
2. **Magazine explosion sequence** — replace the scale-lerped emissive sphere: flash → smoke ball → flung plank debris → expanding water shockwave ring (`ring_texture` precedent). Keep the effect's root node name for the smoke test.
3. **Trauma-based camera shake** — on broadsides (hook beside `ShipWaveMotion.add_recoil_roll`), impacts, and magazine explosions; decay-based, capped, in `FollowCamera`.
4. **Damage listing** — *now a regression, do early:* the translucent black overlay box wraps visibly around detailed mesh hulls. Replace with progressive roll/pitch as hull fraction drops (a fourth roll source composed in `ShipWaveMotion`, recoil is the pattern) plus darkened hull treatment if cheap.
5. **Sinking moment** — `ShipCombatComponent._sink` currently snaps (drop 0.5, roll 9°). Make it a 3–4s tween with roll and foam; check what the smoke test asserts about the sunk end-state before changing timing.
6. **Sail damage states** — tatter/shrink mesh sails as sail fraction drops (they're in `sail_nodes`; trim already scales them) instead of only hiding at mast break.

*Accept: each item probe-verified (CombatEffectsProbe where possible, battle probe otherwise), smoke test green after each, visual plan checkboxes + progress log updated, user playtest for feel items (shake intensity, sink duration).*

## Track C — Ocean overhaul (new user directive, 2026-08-16)

User verdict on today's sea: **"it doesn't look great… I want swells, foam, and something that basically looks more alive"** — and an explicit invitation to evaluate whether building assets in Blender would help.

**The one load-bearing constraint:** ships bob, pitch, roll, and lay wakes by sampling `OceanWaveField`'s CPU mirror of the shader's vertex displacement. **Any change to vertex-stage displacement must be implemented identically in both places** — GPU shader and CPU mirror — or ships will float above / clip through the sea. Fragment-stage changes (color, foam, normals, textures) are unconstrained.

**Recommended core — Gerstner swell layer (shader + CPU, in lockstep):** the current three sines produce gentle rolling bumps; "swells" want long-wavelength Gerstner waves — horizontal displacement sharpens crests and flattens troughs, which is exactly the missing "alive" quality. Compose one or two wind-aligned swell components with the existing chop; key extra foam to crest sharpness (the Gerstner pinch term gives this almost for free). After any amplitude change, re-seat the crest-dependent heights — `JamaicaIsland.land_height`, Port Royal marker y, NPC `WaterMarker` y — all three were paid-for lessons last time.

**The honest Blender answer** (investigate, then implement what wins): Blender-sculpted *animated geometry cannot drive this sea* — the surface must stay an analytic function so the CPU mirror works. Where Blender genuinely helps:
- **Baked tileable textures** replacing in-shader fbm: foam/lace masks, normal-detail maps, maybe subtle caustics — art-directable in a way procedural noise fights you for, cheaper per-pixel, and closer to the North Star's painted look. This is the most promising Blender contribution.
- **A static horizon skirt** — sculpted swell geometry *outside* the gameplay/sampling range where nothing ever floats, melting into the fog band.
- Asset exceptions are pre-approved for this track (precedent: Cinzel font, ship models; the user asked for the Blender evaluation themselves) — but every candidate ships with side-by-side probe comparisons, and the final call on look is the user's.

**Iteration protocol:** probe both scenes at every step (the two cameras have opposite failure modes — remember the detail-layer wash-out and exponential-fog lessons), smoke test after every change since `OceanWaveField` touches ship motion.

*Accept: side-by-side before/after probes from both cameras; ships still sit correctly in the water (bob/wake alignment verified); smoke test green; user playtest sign-off against "swells, foam, alive."*

## Constraints

- The smoke test gates every change; probes verify every visual claim. No "looks right in theory."
- Never edit `artifacts/ship_kit/` or the ship generators for this work; ship models are regression-gated separately.
- Flags keep procedural faction textures and the `Anchor_Flag_*` contract (ADR 0010). Effects stay engine-side per `ship-asset-pipeline.md`'s model-vs-runtime table.
- Ocean vertex displacement stays analytic and CPU-mirrored — textures and fragment work are the free dimension.
- Keep `visual-improvement-plan.md` checkboxes and progress log current; it remains the master status doc.
- Commits: propose per-track commits as work lands; commit only on user request.

## Definition of done

Flags right-sized, wind-flown, rippling on all four classes · all six Tier 3 items checked off in the visual plan · ocean approved by the user against "swells, foam, alive" with the Blender evaluation documented (adopted or ruled out with reasons) · smoke test green throughout · probes captured for every track · user playtest sign-offs · visual plan progress log updated · commits proposed.
