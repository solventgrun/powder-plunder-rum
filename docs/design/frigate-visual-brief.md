# Frigate Visual Asset Brief

Written 2026-08-15 for a **fresh session**. Second ship through the proven galleon pipeline (`docs/design/galleon-sails-rigging-plan.md`, ADR 0010), and the first to build on the extracted shared kit. The reader is assumed to have this doc, the repo, and no other context.

## Objective

One healthy, battle-ready frigate: generator script → `assets/models/frigate.glb` → `FrigateVisual.tscn` → `frigate_basic` profile in `mode: mesh` → playtest sign-off. No damage variants. The galleon must remain untouched and pixel-identical throughout.

## What already exists (do not rebuild)

- **`artifacts/ship_kit/`** — the shared machinery, extracted from the galleon and verified against it: materials palette (`materials.py`), primitives (soft-beveled cubes, spars, polylines, tiered gallery masses), `HullForm` station-profile math with `create_hull` / `add_shaped_deck` / `add_side_gunport`, `add_mast_assembly` (square yards and/or lateen), sail grids (`add_sail`, `add_square_sail`, `add_streamer`, `add_anchor_empty`), rope bundles (`rigging.py`), assembly organization + cross-ship classifier (`assemblies.py`), the review lighting/render rig (`review.py`), and GLB flatten/export helpers (`export.py`).
- **The Godot side is finished and class-agnostic.** `ShipVisualBuilder`'s `mode: mesh` keys off the naming contract (`Sail_*`, `Anchor_Flag_*`, `Anchor_Fire_*`). A new ship needs only a 5-line wrapper `.tscn` and two profile lines. Zero engine code changes expected.
- **The gates**: regenerate → render review → build GLB → `godot --headless --import` → smoke test (`tools/run_smoke_test.ps1`) → content validation → `ScreenshotProbe` at gameplay cameras → playtest. Blender 5.2 at `C:\Program Files\Blender Foundation\Blender 5.2\`; Godot per `run_smoke_test.ps1`.
- **Worked example**: `artifacts/blender_first_hull/create_galleon_hull.py` + `build_galleon_glb.py` show exactly how a ship consumes the kit (station profile → decorate → sails → rigging → flags/anchors → organize; build script: partition → flatten → export with `export_yup=False`).

## Gameplay contract (authoritative numbers)

From `data/ships/ship_types.yaml` and `ship_visual_profiles.yaml` — author at these pre-scale dimensions so the asset drops into the existing slot (`visual_scale` 1.35 is applied to the ship body at runtime):

| Property | Value |
| --- | --- |
| Hull length / width / height | 4.2 / 1.5 / 0.62 |
| Bow length / stern height | 1.05 / 0.34 |
| Masts (z, height above deck) | fore −1.2 / 2.55 · main −0.05 / 2.95 · mizzen 1.0 / 2.45 |
| Fire anchors | `visual_states` in `frigate_basic` (deck_fire_main [0, 0.95, 0] etc.) |
| Gun ports (gameplay stat) | 34 — model a *readable* count instead: one full gun deck of ~12–13 ports/side (galleon precedent: stat 40, modeled 12+8) |
| Conventions | origin waterline center, forward −Z, +X starboard, authored Y-up in Blender, export with axis conversion disabled |

## Class character (the design work of this brief)

The frigate is the hunter: everything the galleon is, minus the castle, plus speed. Visual priorities, in order:

1. **Sleek sheer line.** Long, low, and fast-looking: less deck rise fore and aft, finer bow entry, modest stern. The silhouette difference from the galleon should read instantly at gameplay distance — if a screenshot of the two side by side doesn't say "fortress vs greyhound," iterate the station profile before decorating.
2. **Quarterdeck, not sterncastle.** A raised quarterdeck aft (roughly deck +0.25–0.35) with a simple transom: one row of stern windows, restrained gold trim, no tiered galleries, no balcony, no grand staircase. Small side steps up to the quarterdeck are enough.
3. **Single gun deck.** One clean row of ports per side using the kit's `add_side_gunport`, with muzzles. This is the frigate's most recognizable difference from the galleon's double row.
4. **Taller-looking rig on a lower hull.** Same mast grammar as the galleon (kit `add_mast_assembly`): fore and main with course + topsail yards, mizzen with lateen (matches the runtime profile's sail types). Main tallest.
5. **Jib instead of spritsail** (recommended, needs one small kit addition): a triangular headsail from the fore topmast head down the forestay to the bowsprit reads later-era and differentiates the bow. Build it as a triangle sheet the way the galleon's lateen was built (head edge along the stay line). If it fights the schedule, a small spritsail via `add_square_sail` is acceptable — decide at the silhouette check.
6. **Hull color scheme — decision point at F1.** The galleon owns burgundy + gold. Recommended frigate scheme: near-black dark wood with a deep navy painted band and restrained gold (reads "pirate hunter"; sails stay neutral canvas for faction tint). Confirm with the user against the North Star before decorating; a one-knob paint change later is cheap, so don't over-deliberate.

Ornament budget: roughly half the galleon's. No figurehead menagerie (a simple scroll/billethead), fewer rivets, plainer rails. The frigate should look like it was built in a hurry to catch something.

## Deliverables

Work in `artifacts/blender_frigate/` (`create_frigate.py`, later `build_frigate_glb.py`). Same gates as the galleon plan; keep a session log in this doc if work spans sessions.

- **F1 — Hull form + review scaffold.** Station profile to the dims above, `HullForm` + kit `create_hull`, review renders via kit `setup_review_scene`/`render_to`. Iterate the naked hull until the sheer line reads sleek. Confirm the color scheme with the user here. *Accept: side-view silhouette approved against "greyhound vs fortress."*
- **F2 — Decoration.** Shaped deck, hatch, rails, quarterdeck + transom, single gun deck with muzzles, bow/stem detail, planking/strake lines on the hull skin. Classification rules for frigate-specific names (kit `classify_common` handles the rest). *Accept: renders read clean at gameplay distance; organize pass reports zero unclassified.*
- **F3 — Rig.** Three kit mast assemblies + bowsprit; sails (fore/main course + topsail, mizzen lateen, jib); rigging bundles (stays, backstays, shrouds, lifts — route-check against the filled sails like the galleon's D4). *Accept: nothing pierces canvas or deck furniture; masts read connected.*
- **F4 — Streamers + anchors.** Two or three streamers; `Anchor_Flag_Stern`, `Anchor_Flag_Main`, `Anchor_Fire_Deck`, `Anchor_Fire_Sail` at the profile's `visual_states` coordinates. *Accept: empties present, streamers restrained.*
- **F5 — GLB build.** `build_frigate_glb.py` mirroring the galleon's: partition → `flatten_group` per contract (root **`Frigate`**, same tree/names with Fore/Main/Mizzen keys) → `flatten_materials_for_export()` → export `assets/models/frigate.glb`, `export_yup=False`. *Accept: ≤ ~40 nodes, round-trip upright/−Z-forward, sails carry only the neutral canvas material.*
- **F6 — Godot integration.** `game/scenes/FrigateVisual.tscn` (copy the galleon wrapper, swap the path); `frigate_basic` hull → `mode: mesh` + scene path; `godot --headless --import`; smoke test; content validation. *Accept: all gates green with no ShipVisualBuilder changes (if code changes seem needed, stop and reassess — the contract is supposed to cover this).*
- **F7 — In-game validation + sign-off.** Probes of both scenes; to see it in battle, temporarily set `player_ship.yaml` `ship_type: frigate` (restore after, or leave — user's call). Side-by-side with the galleon for the consistency check. *Accept: user playtest sign-off.*

## Constraints

- **The galleon is the regression suite.** Any kit change must be followed by a galleon regenerate + pixel-diff of its six renders (the extraction session's workflow — see `scratchpad` pattern or just hash/compare) and, if the kit export helpers changed, a galleon GLB rebuild. Never edit `create_galleon_hull.py` for frigate reasons.
- Kit additions are welcome (the jib builder belongs in `ship_kit/canvas.py`); galleon-specific behavior must never leak into kit defaults.
- Flat materials, no bake pass — accepted at gameplay distance per ADR 0010's resolved follow-up.
- Damage variants, cloth sim, per-rope objects: out of scope, same as the galleon plan.
- Scope guard: the frigate should cost **1–2 sessions**, not the galleon's full arc. If sterncastle-grade ornament is creeping in, stop — it's the wrong ship for it.

## Definition of done

Silhouette approved (F1) · zero unclassified objects · all six sails + rigging clear of collisions · GLB on contract · smoke test + content validation green · probes captured · user sign-off in playtest · this doc updated with a completion note · commits proposed (asset + integration split, like the galleon).

## Session log

### 2026-08-15 — F1–F7 build session

- **Color scheme (F1 decision point):** the user supplied a "Vanguard-class"
  frigate concept sheet mid-session that matches the brief's recommendation —
  near-black hull, deep navy gun band edged in gold, restrained gold stern,
  jib headsails, red masthead streamers. Built to that reference; sails stay
  neutral canvas for the faction tint.
- **F1:** station profile at the contract dims (stations z 2.45 → −2.75, max
  half-width 0.85, mid deck 0.61 vs the galleon's 0.73; softer sheer and
  gentler stern rake than the kit defaults). The quarterdeck is a raised
  platform on a deliberately low hull sheer, with solid side bulwarks planted
  on the hull skin so it reads integrated, not pasted on.
- **F2:** shaped full-length deck, two hatches, single gun deck of 12 ports
  per side at band center (t 0.64) with run-out muzzles, navy band bounded
  rows 7–12 with gold strakes at its edges, three plank lines below, plain
  rails with small gold caps, scroll billethead (no figurehead), one head rail
  per side, breast bulkhead with side steps, navy transom with one row of
  five gold-framed windows, taffrail + ensign staff. Ornament ≈ half the
  galleon's: no rivets, no panel dividers, no galleries.
- **F3:** three kit mast assemblies (fore 2.55 / main 2.95 / mizzen 2.45
  above local deck, matching frigate_basic), fore+main course & topsail,
  mizzen lateen (kit `lateen_half=0.92`), jib on the fore topmast stay via the
  new kit `add_jib` (sheet_offset keeps the fore stay clear of the leech);
  low-steeved bowsprit (~29°). Mizzen shrouds anchor forward of the mast —
  the galleon's lesson — so nothing pierces the aft-raked lateen.
- **F4:** three restrained streamers; `Anchor_Flag_Stern` on the ensign
  staff, `Anchor_Flag_Main` at the main masthead, fire anchors at the exact
  profile visual_states coordinates (0, 0.95, 0) / (0, 2.1, −0.05).
- **F5:** `build_frigate_glb.py` mirrors the galleon build; GLB is exactly
  40 nodes, root `Frigate`, same tree/names with Fore/Main/Mizzen keys, sails
  carry only neutral canvas, materials flattened (no white-export regression),
  `export_yup=False`.
- **F6:** `FrigateVisual.tscn` wrapper + `frigate_basic` switched to
  `mode: mesh`. Zero ShipVisualBuilder changes needed — the naming contract
  held. Headless import, smoke test, and content validation all green.
- **F7:** `player_ship.yaml` set to `ship_type: frigate` (left in place so
  the playtest sails it — restore to galleon if preferred). Probes captured:
  NavalBattle shows the frigate under pirate-tinted sails engaging the
  galleon target (side-by-side consistency check); Overworld shows it
  sailing. Smoke test re-run green with the frigate as player.
- **Kit additions** (galleon defaults preserved, regression-gated):
  `create_hull(paint_to_row=...)` for bounded paint bands,
  `add_mast_assembly(lateen_half=...)`, `canvas.add_jib(...)`, and a review-rig
  repair: Blender 5.2 renders the world's node Background, not the legacy
  `world.color`, so `setup_review_scene` now sets both (the committed galleon
  render set predates this and is internally mixed — dark backgrounds on the
  stern/bow angles).
- **Review-camera note:** the kit's `render_to` tracks camera-up toward world
  Z, which rolls angled shots (visible in the committed galleon stern/bow
  renders). The frigate generator uses a ship-side `render_level` for angled
  shots instead; the kit function is untouched to keep the galleon
  regression gate meaningful.
- **Galleon regression gate: PASSED.** Same-environment comparison (the
  committed render set is not a valid baseline on Blender 5.2 — see the
  background note above): stashed the kit to HEAD, regenerated the galleon
  with the review background pinned, restored the kit changes, regenerated
  again, pixel-compared all six renders — bit-identical (max channel delta
  0.0 across 19M subpixels per image; only PNG metadata differed).
  `export.py` unchanged, so no galleon GLB rebuild was required.

**Status: COMPLETE. User playtest sign-off received 2026-08-16 (battle-tested
against varied opponents alongside the brig and galleon). All technical gates
green. Commits pending (asset + integration split).**
