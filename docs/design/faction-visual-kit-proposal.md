# Faction Visual Kit Proposal

Status: **accepted framework, phased — not yet scheduled.** Pirate conversion kit **deferred by user directive (2026-08-17)**.
Provenance: proposal drafted by ChatGPT, supplied by the user 2026-08-17; assessment and adaptation to this codebase follow at the end. Companion to the expansion brief's "Faction Livery Kits" backlog entry, which states the goal this serves.

## Core rule

> **Ship class controls silhouette. Faction kit controls visual language. Subtype controls military/commercial role. Variation pass gives individual character.**

Scales to future merchantmen, war variants, named captains, and legendary ships. Flags remain separate and act as the **confirmation**, not the primary identifier.

## Shared kit structure

Each faction kit contains five reusable layers:

| Layer | Purpose | Examples |
| --- | --- | --- |
| Material palette | Immediate color read | hull stain, painted bands, trim |
| Stern package | Highest-value faction differentiator | galleries, windows, carvings |
| Bow package | Secondary silhouette cue | figurehead, rails, ornament |
| Deck dressing | Personality/detail | barrels, boats, rope, weapon fittings |
| Sail/rigging treatment | Subtle reinforcement | patching, cleanliness, pennants |

## The four national kits

### Spain — Imperial / Ornate

*Fantasy: wealthy imperial power projecting authority; expensive, imposing, slightly old-fashioned.*

- **Palette:** dark reddish/brown timber, ochre or deep red accents, gold/brass trim, cream canvas, red/yellow pennant accents.
- **Geometry:** elaborate stern galleries, carved rail details, ornate transom, large stern lanterns, decorative quarter galleries, religious/royal figureheads, prominent scrollwork.
- **Deck:** neatly secured cargo, brass fittings, decorative officer areas, ceremonial elements on major ships.
- **Weathering:** polished but salt-stained; faded paint, tarnished brass, hull discoloration.
- **Class expression:** galleon = maximal Spanish identity (the faction benchmark); frigate richer-looking than northern equivalents; brig = restrained colonial patrol; sloop = functional colonial craft with red/yellow cues.
- **Recognition: dark wood + gold + red + ornate stern.**

### England — Naval / Martial

*Fantasy: the ship exists to fight — organization, gun power, disciplined professionalism.*

- **Palette:** very dark hull timber, black painted sections, ochre/yellow gun bands, sparing white/pale trim, cream/gray sails.
- **Geometry:** simplified stern architecture, strong horizontal hull lines, prominent gunport bands, minimal decorative railing, orderly cannon placement, modest military figureheads.
- **Deck:** cannon equipment, shot racks, neat rope, spare spars, disciplined boat storage, few decorative props.
- **Weathering:** hard-used but maintained — chipped black paint at gunports, worn decks, gun-smoke staining, patched-but-orderly sails.
- **Class expression:** galleon = austere heavy warship; **frigate = England's visual superstar** (long, clean, menacing); brig = compact naval escort; sloop = lean patrol craft.
- **Recognition: black/dark hull + ochre bands + guns + clean geometry.**

### France — Elegant / Refined

*Fantasy: naval engineering with style; grace over raw intimidation.*

- **Palette:** medium/dark brown hull, deep blue painted sections, white/ivory trim, limited gold, cleaner lighter canvas.
- **Geometry:** elegant curved rails, graceful stern windows, refined scrollwork, slimmer stern ornament, flowing figureheads, moldings rather than heavy carvings.
- **Deck:** cleaner decks, polished officer areas, organized rigging, decorative stern lanterns, restrained luxury.
- **Weathering:** visibly more cared-for than most factions (not pristine).
- **Class expression:** galleon grand but graceful; **frigate = prettiest conventional ship in the game**; brig sleek and fast-looking; sloop = elegant privateer/scout.
- **Recognition: blue + ivory + graceful curves + refined decoration.**

### Dutch — Commercial / Practical

*Fantasy: extremely competent traders who also know how to fight; sturdy, economical, purpose-built.*

- **Palette:** natural medium-brown timber, dark brown/black lower hull, orange accents, occasional muted red, weathered canvas.
- **Geometry:** simpler stern decoration, broad-looking stern elements, practical rails, few carvings, utilitarian figureheads, extra cargo-handling fixtures (dressing can fake broader construction — no hull dimension changes needed).
- **Deck (the strongest Dutch identity layer):** barrels, crates, cargo nets, spare rope, block-and-tackle, merchant boats, covered goods, loading equipment.
- **Weathering:** worked hard, maintained economically — rubbed rails, repaired timber, faded paint, practical patches.
- **Class expression:** galleon = armed merchant powerhouse; frigate = escort not aristocrat; **brig = the Dutch archetype** (trade escort/merchant cruiser); sloop = coastal trader/dispatch.
- **Recognition: natural wood + orange + practical fittings + visible commerce.**

### Pirates — Captured / Improvised (DEFERRED)

Not a national kit: pirate visuals modify another faction's ship — `base ship + original national kit + pirate conversion kit` — so a pirate Spanish galleon still shows Spanish bones. Conversion package: patched/mismatched sails, repainted-over hulls with exposed replacement planks and scraped-off national markings, vandalized crests and trophies at the stern, boarding gear on deck, jury-rigged lines, mismatched cannon carriages. Highest cosmetic randomness of any faction (possibly cross-faction part mixing). Recognition: **damage + modification + mismatched repairs + boarding gear.**

**User directive 2026-08-17: do not implement the pirate conversion kit for now.** Pirates keep flag-led identity until this is picked up.

## Proposed asset architecture (as drafted)

Per-class faction component folders (material_set / stern / bow / rails / deck_props per faction, plus a pirate_conversion overlay set), assembled cosmetically from data:

```yaml
ship_class: frigate
faction: france
variant: war
condition: worn
cosmetic_seed: 18492
```

`cosmetic_seed` would eventually pick which sail is patched, which props appear, figurehead choice, paint wear, lantern configuration.

## Development priority (as drafted)

Build one representative ship per kit first — **Spanish galleon** (ornate), **English frigate** (military), **French frigate** (elegant), **Dutch brig** (commercial), **pirate sloop** (conversion/randomization) — for maximum contrast while forcing the pipeline to solve every category; then propagation is adaptation, not invention.

**Test requirement: turn the flags off.** Five ships at ordinary gameplay zoom — can you guess the faction before zooming in? If nationality only appears once the flag is legible, the kit language is too weak.

---

## Assessment and adaptation to this codebase (2026-08-17)

**Verdict: adopt the framework.** The core rule is exactly the resolution of the class-color-vs-faction-color tension the backlog entry flagged, the flag-off test is our documented readability bar made operational, and the five-pilot build order mirrors how this repo already de-risks (the galleon proved the mesh pipeline before the fleet followed). Specific adaptations:

1. **The layers sort cleanly by cost on our architecture — phase them in that order.**
   - *Palette + sail treatment* are nearly free: the pipeline doc already reserves faction identity for material-slot recolors + runtime sail tint, and the GLBs keep named material slots (`Paint_Red`, `Gold_Trim`, `Canvas_Sail`, …). A palette pass is runtime material overrides driven from data — no Blender work, no reimport. **Phase 1: palettes for all four nations across all four classes, then run the flag-off test.**
   - *Stern/bow geometry packages* collide with the standing rule (pipeline doc Stage 5, ADR 0010 rationale): ships export as flattened ~40-node GLBs, no per-faction meshes. If Phase 1 recognition fails, the honest amendment is **build-time faction parameters in the deterministic generators** — the `create_*` scripts take a faction kit and export per-faction GLBs. Scripted, so the marginal cost is design time, not manual art; but it multiplies assets (4 factions × 4 classes) and every variant needs the render-diff gate. Do it only for the pairings that need it, flagships first (Spanish galleon stern, English frigate gun bands).
   - *Deck dressing* likely reads poorly at our gameplay camera distance — the repo's consistent quality bar. Evaluate last, only if the flag-off test says the Dutch read fails without it.
2. **Assembly stays bake-time for geometry, runtime for color.** The proposal's runtime component assembly (Godot picks stern/bow/props per faction) doesn't fit our regression-gated bake pipeline; palette-by-slot-name at runtime does, and is how sail tint already works.
3. **The current class schemes become faction seeds, not casualties.** The galleon's burgundy+gold *is* essentially the Spanish benchmark (the proposal says so itself); the frigate's near-black+navy+gold can seed England (black + ochre bands) or France (blue + ivory) — a decision point when Phase 1 starts. Classes keep identity through silhouette, which the four hulls already deliver.
4. **Subtype / condition / cosmetic_seed axes**: good future-proofing, premature now (no merchantmen or named captains exist). Recorded here; build nothing for them yet.
5. **Pirate conversion kit deferred** (user directive). It is also objectively the most expensive layer (overlays, per-ship randomization, cross-faction mixing). When picked up, note the player ship already carries a `visual_variant: worn` concept to build on.

**Suggested pilot order for this repo** (amending the proposal's five): Phase 1 palettes fleet-wide first — it may carry the whole goal at gameplay distance — then the proposal's five-ship contrast lineup only where palette recognition falls short, minus the pirate sloop while deferred.
