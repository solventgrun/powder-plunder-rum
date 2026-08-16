# Sloop Visual Asset Brief

Written 2026-08-15 for a **fresh session**. Fourth ship through the proven pipeline (`docs/design/galleon-sails-rigging-plan.md`, ADR 0010, frigate + brig briefs), and the last hull class in the data — after this, every ship in the game sails a mesh. The reader is assumed to have this doc, the repo, and no other context.

The gameplay id is `sloop`; its visual slot is the `sloop_basic` profile.

## Objective

One healthy, battle-ready sloop: generator script → `assets/models/sloop.glb` → `SloopVisual.tscn` → `sloop_basic` profile in `mode: mesh` → playtest sign-off. No damage variants. The galleon, the frigate, **and the brig** must remain untouched and pixel-identical throughout.

## What already exists (do not rebuild)

- **`artifacts/ship_kit/`** — materials palette, primitives, `HullForm` station math with `create_hull` (`paint_to_row` bounds a paint band from above — see the tar note below), `add_shaped_deck` / `add_side_gunport`, `add_mast_assembly`, sail grids (`add_sail`, `add_square_sail`, `add_jib`, `add_streamer`, `add_anchor_empty`), rope bundles, assembly organization + `classify_common`, the review rig, and GLB flatten/export helpers.
- **Three worked examples.** `artifacts/blender_brig/create_brig.py` + `build_brig_glb.py` is the one to copy — closest hull size, and it already contains everything the sloop's rig needs: the **ship-side gaff sail** (`gaff_geometry()` + boom/gaff `add_spar` calls + the quad `add_sail` closure with billow vanishing on all four edges), the `Yard_Main_Gaff` flatten pattern, the ship-side `render_level` for angled shots, the `BRIG_STAGE`/`BRIG_QUALITY` env-knob pattern, and two hull fixes to carry over verbatim from its `create_hull`: the kit's bow/stern **cap faces wind inward and paint the bow slivers with the band material** (reorient + repaint them ship-side), and **aft-facing surfaces blow out pale under the review rig's fill light** (the brig gives its counter a dedicated darker "shadowed counter timber" — the wash-out is the rig, visible on the committed frigate stern render too; don't chase it).
- **The material-slot trick** from the brig: the kit reads `materials["gold"]` for every fitting (mast bands, slings, port sills) — bind that key to blackened iron and the whole ship comes out workmanlike with zero kit changes.
- **The Godot side is finished and class-agnostic.** `ShipVisualBuilder` `mode: mesh` keys off `Sail_*` / `Anchor_Flag_*` / `Anchor_Fire_*` names, with no mast-count assumptions (proven at three masts, then two). A new ship needs a 5-line wrapper `.tscn` and two profile lines. NPC mesh mode is also already proven: the overworld Spanish Patrol is a brig and renders the brig mesh under Spanish tint.
- **The gates**: regenerate → render review → build GLB → `godot --headless --import` → smoke test (`tools/run_smoke_test.ps1`) → content validation (`tools/run_content_validation.ps1`) → `ScreenshotProbe` at gameplay cameras → playtest. Blender 5.2 at `C:\Program Files\Blender Foundation\Blender 5.2\`; Godot per `run_smoke_test.ps1`. (The smoke test occasionally exits non-zero on teardown despite printing "Smoke test passed" — rerun before investigating.)

## Gameplay contract (authoritative numbers)

From `data/ships/ship_types.yaml` (`sloop`) and `ship_visual_profiles.yaml` (`sloop_basic`). `visual_scale` is **1.0** — authored dimensions ARE runtime dimensions, no headroom from scaling:

| Property | Value |
| --- | --- |
| Hull length / width / height | 3.0 / 1.2 / 0.46 |
| Bow length / stern height | 0.9 / 0.12 |
| Mast (z, height above deck) | main −0.12 / 2.15 — **the only mast** |
| Runtime sail set | mainsail (fore_aft 1.1×1.45, center ≈ [0.12, 1.38, 0.02]) · jib (0.85×1.0, ≈ [0, 1.05, −1.05]) |
| Fire anchors | `Anchor_Fire_Deck` [0, 0.75, 0.0] · `Anchor_Fire_Sail` [0, 1.65, −0.12] (exact `visual_states` values) |
| Flag anchors | stern ensign near [0, 1.15, 1.45]; the profile has **no mast pennant** — ship `Anchor_Flag_Main` anyway (uniform contract, the builder ignores unused anchors) |
| Gun ports (gameplay stat) | 8 — model **4 ports/side**: the first class where the modeled count IS the stat |
| Conventions | origin waterline center, forward −Z, +X starboard, authored Y-up in Blender, export with axis conversion disabled |

Extra-sail precedent (frigate +2, brig +1) does **not** apply here: two sails IS the sloop. Decide at S3 only if the S1 silhouette reads empty — the most that's justified is a small gaff topsail between masthead and gaff peak.

## Class character (the design work of this brief)

The sloop is the minnow — and the fleet's outright fastest (max_speed 6.4) and most agile (turn_rate 106, 2.5× the brig) ship. It's the starter boat and the working coaster the player meets everywhere (the overworld Dutch Trader sails one). Everything the brig is, minus the gun row swagger, plus honesty. Silhouette test: galleon = fortress, frigate = greyhound, brig = knife, sloop = **dart**. Visual priorities, in order:

1. **Single-mast fore-aft rig readability.** One tall mast just forward of center carrying a big gaff mainsail whose **boom overhangs the transom** — the classic sloop giveaway — and a jib to a proud bowsprit. At gameplay distance the class must read from rig count alone: one stick, two triangular-ish sails. Copy the brig's ship-side gaff construction; **do not promote `add_gaff_sail` into the kit** — a kit change now costs a *three*-ship regression pass, and the closure is ~15 lines.
2. **Flush deck, no aft structure at all.** stern_height 0.12 is a taffrail board, not a platform: no half-deck, no step, no breast bulkhead. Near-zero sheer (flatter than the brig — amplitude ≈ 0.018, gentle bow rake ≈ (0.22, 0.08)). A tiller at the stern, not a wheel.
3. **No paint budget — the honest workboat.** Recommended scheme (decision point at S1, confirm against the North Star): pale working oak topsides (the profile's `deck_color` is `wood_light` — lean into it), **tarred black bottom** via the existing band knob used upside-down (`paint_from_row=0, paint_to_row=7` with the paint slot bound to near-black tar — a fresh use, no kit change), one black wale strake, `materials["gold"]` bound to blackened iron (brig precedent), muted red port lids only. Each sibling owns its color: burgundy+gold / black+navy / brown+buff / **bare pale wood + tar**. Sails stay neutral canvas for faction tint — the Dutch Trader will wear this hull under dutch canvas.
4. **One honest port row.** 4 ports/side with the kit gunport + run-out muzzles, sitting in bare wood above the wale — no band to carry them.
5. **Ornament budget: half the brig's, i.e. nearly nothing.** Stem cap (iron, not brass — the sloop doesn't even spend on brass), plain open rails aft only or none amidships, one hatch, the tiller, maybe a coiled-rope or barrel deck prop if the deck reads empty. If brig-grade trim is creeping in, stop.

## Deliverables

Work in `artifacts/blender_sloop/` (`create_sloop.py`, later `build_sloop_glb.py`). Same gates as the brig; keep a session log in this doc.

- **S1 — Hull form + review scaffold.** Station profile to the dims above (span ≈ length + bow ≈ 3.9, stern z ≈ +1.75, bow tip ≈ −2.15, max half-width ≈ 0.68, mid deck ≈ 0.46). Naked-hull renders via the kit rig + ship-side `render_level`; iterate until the sheer reads dart-flat. Confirm the color scheme with the user here. *Accept: side silhouette approved against the three-ship lineup ("fortress / greyhound / knife / dart").*
- **S2 — Decoration.** Shaped deck, one hatch, tiller, taffrail board + tiny flat transom (no stern lights at all, or one), 4 ports/side with muzzles, wale + tar line, stem cap. Sloop-specific classification rules layered on `classify_common`. *Accept: clean at gameplay distance; organize pass reports zero unclassified.*
- **S3 — Rig.** One bare kit mast assembly (no square yards) + ship-side boom/gaff (~35° rake, boom past the transom) + gaff mainsail + jib + bowsprit; rigging bundles (forestay = jib luff, shrouds, backstay pair to the quarters, peak halyard, boom sheet). Shrouds anchor *forward* of the mast, away from the aft canvas (three ships' worth of precedent now). The ship-side `ASSEMBLY_TREE` **drops both `ForemastAssembly` and `MizzenAssembly`** — MainmastAssembly + BowspritAssembly carry the whole rig; transom pieces take the `Sterncastle` slot. *Accept: nothing pierces canvas or deck furniture; the mast reads connected.*
- **S4 — Streamer + anchors.** ONE restrained masthead streamer; `Anchor_Flag_Stern` on the taffrail staff, `Anchor_Flag_Main` at the masthead, and the two fire anchors at the exact profile coordinates. *Accept: empties present, streamer restrained.*
- **S5 — GLB build.** `build_sloop_glb.py` mirroring the brig's minus the foremast: partition → `flatten_group` (root **`Sloop`**, Main key only; boom+gaff+jaws → `Yard_Main_Gaff` pivoted at the boom jaw, brig precedent) → `flatten_materials_for_export()` → export `assets/models/sloop.glb`, `export_yup=False`. *Accept: ≤ ~24 nodes (one mast — leaner than the brig's 32), round-trip upright/−Z-forward, sails carry only the neutral canvas material.*
- **S6 — Godot integration.** `game/scenes/SloopVisual.tscn` (copy the brig wrapper, swap the path); `sloop_basic` hull → `mode: mesh` + scene path; import; smoke test; content validation. Two sloop-specific notes: the smoke test builds a **sloop stats fixture** for its loadout-swap case (stats only, no visuals — should be unaffected, but if it trips, that's the place to look), and this flip puts a mesh on an **overworld NPC** (Dutch Trader) for the first time via the sloop class — the Spanish Patrol brig already proves the path. *Accept: all gates green with no ShipVisualBuilder changes.*
- **S7 — In-game validation + sign-off.** Probes of both scenes; the Overworld probe must show the Dutch Trader sailing the mesh under dutch tint. To sail it yourself, temporarily set `player_ship.yaml` `ship_type: sloop` (it currently reads `brig` from the brig session — restore or leave, user's call). **Loadout fixture trap, sized for the sloop:** the smoke test requires starboard to outrange/outweigh/out-slow port AND total weight within `usable_load_capacity` **40** — use port 4× `light_4_pounder` (16) + starboard 3× `long_9_pounder` (21) = 37; fewer cannons than ports is legal (the validator only warns above 4/side), and crew ≤ 75. Battle probe against the galleon target for the four-ship consistency check. *Accept: user playtest sign-off.*

## Constraints

- **The galleon, frigate, AND brig are the regression suite.** Any kit change requires regenerating **all three** and pixel-diffing their renders with the same-environment procedure from the frigate session log (`git stash push -- artifacts/ship_kit` → regenerate with the review background pinned → restore → regenerate → **compare decoded pixels, not file hashes**, max channel delta 0). If `ship_kit/export.py` changes, rebuild all three GLBs too. The bar for touching the kit is now very high — the brig shipped with zero kit changes; the sloop should too.
- Never edit `create_galleon_hull.py`, `create_frigate.py`, or `create_brig.py` for sloop reasons.
- Flat materials, no bake pass — accepted at gameplay distance per ADR 0010.
- Damage variants, cloth sim, per-rope objects: out of scope.
- Keep the procedural path alive: `mode: mesh` hides the scene placeholders but the fallback must still work (don't remove or rename `Hull`/`Bow`/`Mast` nodes in ship scenes).
- Scope guard: the sloop should cost **about half a session** — it is the smallest and plainest ship in the fleet, with three worked examples to lean on. Brig-grade decoration is already too much.

## Definition of done

Silhouette approved (S1) · zero unclassified objects · both sails + rigging clear of collisions · GLB on contract · smoke test + content validation green · probes captured, including the Dutch Trader NPC sailing the mesh · user playtest sign-off · this doc updated with a completion note · commits proposed (asset + integration split, like the three before it).

## Session log

### 2026-08-15 — S1–S7 build session

- **Color scheme (S1 decision point):** the user supplied a "Rapide-class"
  sloop concept sheet with the task, superseding this brief's pale-oak
  recommendation (frigate/brig precedent). Built to it, structure per the
  contract (the sheet draws two masts; the profile says one — palette and
  character only were taken): dark charcoal-brown hull, **warm ochre/gold-tan
  band** as the sloop's ownable accent, small navy stern panel, muted red
  port lids, red streamer. Kit "gold" slot bound to blackened iron (brig
  trick); true gilt rationed to the stem cap, stern mouldings, one stern
  light lintel, and the ensign truck — total gold well below the frigate's.
- **S1:** stations z 1.75 → −2.06 (bow tip −2.14 raked), max half-width 0.68,
  mid deck 0.455, sheer amplitude 0.018 — the dart. Brig hull fixes carried
  over verbatim (cap-face repaint + reorient; counter stack in the darker
  "shadowed counter timber" so the rig's aft-face wash-out stays tarred).
- **S2:** full-length flush deck, one hatch, **tiller** (rudder head + curved
  handle, no wheel), 4 ports/side at band center (t 0.70) with muzzles, three
  plank lines, dark strakes edging the band, one black wale, single-top-rail
  posts (no mid rail, no caps), tiny transom with taffrail board and ONE
  stern light, gilt stem cap.
- **S3:** one bare kit mast (2.15) with ship-side boom + gaff copied from the
  brig pattern (~35° rake, throat kept below the kit top platform, **boom end
  z 1.92 past the transom at 1.75** — the sloop giveaway); jib on the
  forestay via kit `add_jib`, tack seated on the proud ~21° bowsprit. Sparse
  rig by design: forestay/shrouds (anchored forward of the mast)/quarter
  backstays/peak halyard/boom sheet — vangs were checked against the leech
  (0.06 clearance) and dropped rather than shipped tight.
- **S4:** ONE streamer; `Anchor_Flag_Stern` at the staff head,
  `Anchor_Flag_Main` shipped for the uniform contract (profile has no
  pennant), fire anchors at the exact visual_states coordinates
  (0, 0.75, 0) / (0, 1.65, −0.12).
- **S5:** `build_sloop_glb.py` mirrors the brig build minus the foremast; GLB
  is exactly **24 nodes**, root `Sloop`, Main key only, boom/gaff/jaws/collar
  in `Yard_Main_Gaff` pivoted at the boom jaw, sails carry only neutral
  canvas, `export_yup=False`.
- **S6:** `SloopVisual.tscn` wrapper + `sloop_basic` switched to `mode: mesh`.
  Zero kit changes, zero ShipVisualBuilder changes. Headless import, smoke
  test (including the sloop stats fixture case and mast-break against a
  one-mast profile), and content validation (0 warnings) all green.
- **S7:** `player_ship.yaml` set to `ship_type: sloop`, crew 70, fixture
  loadout port 4× light 4-pounder / starboard 3× long 9-pounder (37 of 40
  load — the brief's numbers held). Probes captured: NavalBattle shows the
  sloop under pirate colors against the galleon target (four-ship consistency
  check); the Overworld probe shows the **Dutch Trader NPC sailing the mesh**
  under its Dutch flag — first NPC-sailed mesh flip for a class, as flagged.

**Status: S1–S7 complete except the user playtest sign-off. All technical
gates green with zero kit changes and zero engine changes. `player_ship.yaml`
sails the sloop; restore `ship_type` afterward if preferred.**

### 2026-08-15 — proof-review tuning pass (four changes)

- **Band color:** deepened from warm ochre to the Rapide sheet's gold-amber —
  base (0.520, 0.360, 0.130) → (0.505, 0.305, 0.058), highlight
  (0.640, 0.465, 0.190) → (0.655, 0.425, 0.095), shadow (0.300, 0.195, 0.065)
  → (0.285, 0.152, 0.026). Clearly separated from the brig's desaturated
  buff-sand.
- **Gaff foot lacing:** tack/clew dropped 0.02 (boom +0.030/+0.036 →
  +0.010/+0.016) so the foot laces onto the boom instead of riding above it.
- **Rails:** trimmed to the brief's aft-only run — posts/top rail now
  z 0.70–1.58 around the quarters and tiller (was z −1.78–1.30 full length).
  The bow closing sweeps went with the fore rails; each forward rail end now
  sweeps down to the full-length deck edge cap so nothing terminates
  floating. Waist shrouds re-anchored from rail height (+0.08) to the deck
  cap line (+0.025, chainplate look); the quarter backstays still land on
  the rail.
- **Shoal coastal draft — tried and REVERTED:** keels were reduced ~28%
  across all stations (with the black wale moved t 0.50 → 0.46 to follow the
  waterline), but on proof review the user found the hull read too shallow.
  Keels restored to the original column (−0.22, −0.30, −0.37, −0.43, −0.47,
  −0.46, −0.42, −0.34, −0.18, −0.02) and the wale returned to t 0.50; ports/
  band rows and the bobstay/bowsprit-shroud endpoints re-verified against the
  deep hull (they were authored against it — all seated). The band, foot
  lacing, and rail changes above are retained.
- Gates re-run after each pass: GLB rebuilt (still 24 nodes), headless
  import, smoke test, and both probes green; content data untouched so
  validation unchanged. The Dutch Trader NPC confirmed on the final mesh in
  the refreshed Overworld probe.

### 2026-08-16 — completion

**Status: COMPLETE. Final proofs approved by the user ("much better") and
playtest sign-off received across the fleet the same day. All technical gates
green with zero kit changes and zero engine changes. Commits pending (asset +
integration split). Every ship class in the game now sails a mesh.**
