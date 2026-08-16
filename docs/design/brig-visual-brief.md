# Brig Visual Asset Brief

Written 2026-08-15 for a **fresh session**. Third ship through the proven pipeline (`docs/design/galleon-sails-rigging-plan.md`, ADR 0010, `docs/design/frigate-visual-brief.md`), and the second to consume the shared kit from day one. The reader is assumed to have this doc, the repo, and no other context.

The gameplay id is `brig` (display name "Brigantine"); its visual slot is the `brigantine_basic` profile. File and node names use **brig** to match the id.

## Objective

One healthy, battle-ready brig: generator script → `assets/models/brig.glb` → `BrigVisual.tscn` → `brigantine_basic` profile in `mode: mesh` → playtest sign-off. No damage variants. The galleon **and the frigate** must remain untouched and pixel-identical throughout.

## What already exists (do not rebuild)

- **`artifacts/ship_kit/`** — materials palette, primitives, `HullForm` station math with `create_hull` (now with `paint_to_row` for bounded paint bands) / `add_shaped_deck` / `add_side_gunport`, `add_mast_assembly` (square yards, lateen with `lateen_half`), sail grids (`add_sail`, `add_square_sail`, `add_jib`, `add_streamer`, `add_anchor_empty`), rope bundles, assembly organization + `classify_common`, the review rig (`setup_review_scene` sets the world **Background node** — Blender 5.2 ignores the legacy `world.color` for renders), and GLB flatten/export helpers.
- **Two worked examples.** `artifacts/blender_frigate/create_frigate.py` + `build_frigate_glb.py` is the one to copy — it is the kit-native consumer and carries the current best practice: stage/quality env knobs for fast iteration (`FRIGATE_STAGE`/`FRIGATE_QUALITY` pattern), a ship-side `render_level` for horizon-level angled review shots (the kit's `render_to` rolls them — left unfixed deliberately, see its session log), a raised deck platform with skin-planted side bulwarks, and rigging routes that land on structure. The galleon files show the fullest decoration vocabulary if needed.
- **The Godot side is finished and class-agnostic.** `ShipVisualBuilder` `mode: mesh` keys off `Sail_*` / `Anchor_Flag_*` / `Anchor_Fire_*` names. A new ship needs a 5-line wrapper `.tscn` and two profile lines. Zero engine code changes expected.
- **The gates**: regenerate → render review → build GLB → `godot --headless --import` → smoke test (`tools/run_smoke_test.ps1`) → content validation (`tools/run_content_validation.ps1`) → `ScreenshotProbe` at gameplay cameras → playtest. Blender 5.2 at `C:\Program Files\Blender Foundation\Blender 5.2\`; Godot per `run_smoke_test.ps1`. (The smoke test occasionally exits non-zero on teardown despite printing "Smoke test passed" — rerun before investigating.)

## Gameplay contract (authoritative numbers)

From `data/ships/ship_types.yaml` (`brig`) and `ship_visual_profiles.yaml` (`brigantine_basic`) — author at these pre-scale dimensions (`visual_scale` 1.12 applied at runtime):

| Property | Value |
| --- | --- |
| Hull length / width / height | 3.45 / 1.36 / 0.54 |
| Bow length / stern height | 0.95 / 0.24 |
| Masts (z, height above deck) | fore −0.85 / 2.25 · main 0.32 / 2.55 (main tallest — aft mast) |
| Runtime sail set | fore_course (square 1.25×0.95) · main_fore_aft (1.2×1.45) · jib (0.9×1.05) |
| Fire anchors | `Anchor_Fire_Deck` [0, 0.85, 0.18] · `Anchor_Fire_Sail` [0, 1.88, 0.32] (exact `visual_states` values) |
| Flag anchors | ensign staff near [0, 1.42, 1.62] · main masthead (profile `flags` block is the guide) |
| Gun ports (gameplay stat) | 14 — model a *readable* count: one short row of **7 ports/side** (precedent: galleon 40→20, frigate 34→24) |
| Conventions | origin waterline center, forward −Z, +X starboard, authored Y-up in Blender, export with axis conversion disabled |

Modeling extra sails beyond the runtime list is established precedent (the frigate shipped six against a four-sail profile): add a **fore topsail** so the square foremast reads complete.

## Class character (the design work of this brief)

The brig is the raider: the fastest ship in the data (max_speed 5.0 — quicker than the frigate) and the smallest through this pipeline so far. Everything the frigate is, minus the grandeur, plus scrappiness. Visual priorities, in order:

1. **Two-mast rig readability.** This is the class signature at gameplay distance: a square-rigged foremast (course + topsail) and a taller mainmast carrying a big **gaff mainsail on boom and gaff spars** — no ship in the fleet has one yet. Silhouette test: galleon = fortress, frigate = greyhound, brig = *knife*. If the two-mast profile with the tall fore-aft main doesn't read instantly against the frigate, fix the rig before decorating.
2. **Flush, workmanlike sheer.** Even lower-slung than the frigate: near-flat deck line, a *low* aft platform step (half the frigate's quarterdeck, or just a raised half-deck) and a small plain transom — two rectangular stern lights at most, no window row, no galleries, no balcony.
3. **Jib on the fore topmast stay** via the kit's `add_jib` (proven on the frigate — seat the tack ON the bowsprit spar; the frigate session log records the piercing checks). Low-steeved bowsprit like the frigate's.
4. **One short gun row.** 7 ports/side with the kit gunport + run-out muzzles, sitting in the paint band.
5. **Gaff sail construction (decide at B3).** Boom + gaff as ship-side `add_spar` calls; the sail is a quad sheet (head along the gaff, foot along the boom, billow to starboard like the lateen/jib). Bias: build it **ship-side** with `add_sail` — the lateen precedent. Promote a `add_gaff_sail` into `ship_kit/canvas.py` only if a second fore-aft-rigged ship is realistically next; every kit change now costs a two-ship regression pass.
6. **Hull color scheme — decision point at B1.** The galleon owns burgundy+gold; the frigate owns near-black + navy + gold. Recommended brig scheme: **tarred warm-brown hull with a buff/sand band** carrying the ports, blackened-iron fittings, and almost no gold (a working raider that spends nothing on shine; sails stay neutral canvas for faction tint). Confirm with the user against the North Star before decorating; paint is a one-knob change, don't over-deliberate.

Ornament budget: roughly half the *frigate's*. No billethead scroll — a simple stem cap. Plain rails, no rivets, no panel work. If frigate-grade trim is creeping in, stop — this ship was built to outrun customs, not to impress them.

## Deliverables

Work in `artifacts/blender_brig/` (`create_brig.py`, later `build_brig_glb.py`). Same gates as the frigate; keep a session log in this doc if work spans sessions.

- **B1 — Hull form + review scaffold.** Station profile to the dims above (span ≈ length + bow ≈ 4.4, stern z ≈ +2.05, bow tip ≈ −2.35, max half-width ≈ 0.77, mid deck ≈ 0.54). Naked-hull renders via the kit rig + ship-side `render_level`; iterate until the sheer reads knife-flat. Confirm the color scheme with the user here. *Accept: side silhouette approved against galleon + frigate ("fortress / greyhound / knife").*
- **B2 — Decoration.** Shaped deck, hatch, low aft platform + plain transom, 7 ports/side with muzzles, band + minimal strakes, plain rails, stem cap. Brig-specific classification rules layered on `classify_common`. *Accept: clean at gameplay distance; organize pass reports zero unclassified.*
- **B3 — Rig.** Two kit mast assemblies (fore with course + topsail yards; main with **no** square yards) + ship-side boom/gaff + gaff sail + jib + bowsprit; rigging bundles (stays, backstays, shrouds, lifts, boom sheet). Route-check against the filled sails; anchor shrouds *away* from fore-aft canvas (the mizzen-lesson from both prior ships). The ship-side `ASSEMBLY_TREE` **drops `MizzenAssembly` and keeps the rest of the contract names** (transom pieces take the `Sterncastle` slot, frigate precedent). *Accept: nothing pierces canvas or deck furniture; masts read connected.*
- **B4 — Streamers + anchors.** Two restrained streamers (fore + main); `Anchor_Flag_Stern` on a taffrail ensign staff, `Anchor_Flag_Main`, and the two fire anchors at the exact profile coordinates. *Accept: empties present, streamers restrained.*
- **B5 — GLB build.** `build_brig_glb.py` mirroring the frigate's: partition → `flatten_group` (root **`Brig`**, Fore/Main keys; gaff spars fold into `Mast_Main` or a `Yard_Main_Gaff` sibling — pick whichever keeps pivots useful) → `flatten_materials_for_export()` → export `assets/models/brig.glb`, `export_yup=False`. *Accept: ≤ ~32 nodes (two masts, so leaner than the frigate's 40), round-trip upright/−Z-forward, sails carry only the neutral canvas material.*
- **B6 — Godot integration.** `game/scenes/BrigVisual.tscn` (copy the frigate wrapper, swap the path); `brigantine_basic` hull → `mode: mesh` + scene path; import; smoke test; content validation. The smoke test's mast-break case runs against a two-mast profile — if anything in mesh mode assumes three masts, **stop and reassess** (the contract is supposed to cover this). *Accept: all gates green with no ShipVisualBuilder changes.*
- **B7 — In-game validation + sign-off.** Probes of both scenes; to sail it, temporarily set `player_ship.yaml` `ship_type: brig` (it currently reads `frigate` from the frigate session — restore or leave, user's call). Battle probe against the galleon or frigate target for the three-ship consistency check. *Accept: user playtest sign-off.*

## Constraints

- **The galleon AND the frigate are the regression suite.** Any kit change requires regenerating **both** and pixel-diffing their renders using the same-environment procedure from the frigate session log: `git stash push -- artifacts/ship_kit` → regenerate with the review background pinned → restore → regenerate again → **compare pixel data, not file hashes** (PNG bytes differ run-to-run in metadata; the frigate gate compared decoded pixels and required max channel delta 0). If `ship_kit/export.py` changes, rebuild both GLBs too. Never edit `create_galleon_hull.py` or `create_frigate.py` for brig reasons.
- Kit additions are welcome but now cost a two-ship gate — prefer ship-side construction (the gaff bias above); class-specific behavior must never leak into kit defaults.
- Flat materials, no bake pass — accepted at gameplay distance per ADR 0010.
- Damage variants, cloth sim, per-rope objects: out of scope.
- Scope guard: the brig should cost **about one session** — it is smaller and plainer than the frigate. Sterncastle-grade or even frigate-grade ornament is the wrong ship.

## Definition of done

Silhouette approved (B1) · zero unclassified objects · all five sails + rigging clear of collisions · GLB on contract · smoke test + content validation green · probes captured · user playtest sign-off · this doc updated with a completion note · commits proposed (asset + integration split, like the galleon and frigate).

## Session log

### 2026-08-15 — B1–B7 build session

- **Color scheme (B1 decision point):** the user supplied a brig concept
  sheet ("Versatile-class") with the task. Built to the brief's recommended
  raider scheme merged with the sheet: tarred warm-brown hull, buff/sand band
  carrying the ports (narrowed to rows 8–11 — tan-on-brown carries far more
  contrast than the frigate's navy-on-black, so the same row count read as a
  repaint), muted navy kept to the half-deck bulwarks, one sheer strake, and
  the transom panel; brick-red port reveals; **the kit's "gold" material slot
  is bound to blackened iron** so every kit fitting (mast bands, yard slings,
  port sills) comes out raider-plain. The entire true-gold budget is a brass
  stem cap and the ensign-staff truck. Sails stay neutral canvas.
- **B1:** stations z 2.05 → −2.25 (bow tip −2.35 raked), max half-width 0.77,
  mid deck 0.535, sheer amplitude 0.022 — the knife-flat line against the
  galleon/frigate set. Two ship-side hull fixes recorded for future briefs:
  the kit's bow/stern cap faces wind inward and paint the bow slivers with
  the band material (harmless on ships whose transom decor covers them; the
  brig reorients + repaints them), and aft-facing surfaces catch the review
  fill light square-on, so the exposed counter wears a dedicated darker
  "shadowed counter timber" — the same wash-out is visible on the committed
  frigate stern render, it is the rig, not the ship.
- **B2:** full-length shaped deck, two hatches, 7 ports/side at band center
  (t 0.70) with run-out muzzles, three plank lines, dark strakes edging the
  band, plain post-and-rail bulwark rails (no caps), low half-deck (+0.10
  step — half the frigate's) with navy skin-planted bulwarks, breast bulkhead
  with one shadowed doorway + side steps, small plain transom with exactly
  two stern lights, taffrail ensign staff. No billethead — brass stem cap.
- **B3:** fore kit mast (2.25, course + topsail yards) and bare main kit pole
  (2.55) carrying a **ship-side boom + gaff** (`add_spar`, `Yard_boom_main` /
  `Yard_gaff_main`, ~34° gaff rake) — per the brief's bias the gaff sail is
  ship-side `add_sail` (quad laced to gaff and boom, billow vanishing on all
  four edges, starboard belly); no `add_gaff_sail` kit promotion, so **zero
  kit changes and no regression pass was needed**. Jib on the fore topmast
  stay via kit `add_jib`, tack seated on the low-steeved (~24°) bowsprit.
  Main shrouds anchor forward of the mast, backstays land on the half-deck
  rail beside the leech, peak halyard + vangs frame the gaff.
- **B4:** two restrained streamers (fore/main); `Anchor_Flag_Stern` on the
  staff head, `Anchor_Flag_Main` at the masthead, fire anchors at the exact
  profile visual_states coordinates (0, 0.85, 0.18) / (0, 1.88, 0.32).
- **B5:** `build_brig_glb.py` mirrors the frigate build; GLB is exactly
  **32 nodes**, root `Brig`, two-mast tree (no Mizzen), boom/gaff/jaws/collar
  folded into `Yard_Main_Gaff` pivoted at the boom jaw on the mast axis,
  sails carry only neutral canvas, `export_yup=False`.
- **B6:** `BrigVisual.tscn` wrapper + `brigantine_basic` switched to
  `mode: mesh`. Zero ShipVisualBuilder changes — the contract held for two
  masts (the builder is fully name-keyed). Headless import, smoke test, and
  content validation (0 warnings) all green.
- **B7:** `player_ship.yaml` set to `ship_type: brig` (left in place so the
  playtest sails it). Note: the player loadout is a **smoke-test fixture** —
  starboard must outrange/outweigh/out-slow port and total weight must fit
  usable_load_capacity 90, so the brig carries 7× light 4-pounder port and
  7× long 9-pounder starboard (77 load). Probes captured: NavalBattle shows
  the brig under pirate flags engaging the galleon target (three-ship
  consistency check); Overworld shows it sailing off Jamaica.

**Status: COMPLETE. User playtest sign-off received 2026-08-16 (battle-tested
against varied opponents alongside the frigate and galleon). All technical
gates green with zero kit changes and zero engine changes. Commits pending
(asset + integration split).**
