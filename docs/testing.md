# Prototype Testing Guide

This project keeps small testing artifacts close to the prototype so tuning remains fast and visible.

## Commands

Validate YAML content:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_content_validation.ps1
```

Run the full headless smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_smoke_test.ps1
```

## Current Test Scenarios

### Asymmetric Broadside Range

Player cannon loadout lives in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml).

The current player ship intentionally has:

- port: three `light_4_pounder` cannons
- starboard: one `light_4_pounder` and two `long_12_pounder` cannons

This lets us test whether different cannon types on different sides produce meaningful range, reload, and weight differences.

### Ammo Range Differences

Ammo range multipliers live in [data/cannons/ammo_types.yaml](../data/cannons/ammo_types.yaml).

Current intent:

- round shot: longest range
- chain shot: medium range
- grape shot: close range
- fire shot: very close range, with burning and self-ignition risk

### Fire Shot Risk

Fire shot can apply `burning` to the target and has `self_ignition_chance`, which can set the firing ship on fire. This is intentionally reckless and should remain easy to tune.

### Wind Strength and Direction

Wind is loaded from [data/environment/environment_conditions.yaml](../data/environment/environment_conditions.yaml). The current active record is `default_battle`, which defines wind direction, strength, and reference strength.

The file is named for environment conditions rather than only wind because future battle scenes may receive additional overworld context such as storms, reefs, or visible landmarks. Only wind is consumed right now.

Debug playtest overrides:

Use:

- `[` / `]`: decrease / increase wind strength
- `,` / `.`: rotate wind direction

The debug panel shows wind heading, strength, and the current wind speed factor. Test ship speed in light, moderate, and strong wind before changing ship type speed values.

### Ship Visual Readability

Faction flags are generated from [data/visuals/flags.yaml](../data/visuals/flags.yaml). The pirate faction should display a bold black Jolly Roger with a white skull-and-crossbones style mark. Flags billboard toward the battle camera and use chunky high-contrast generated textures so emblems remain readable at prototype camera distance.

Bow visuals are generated as forward-facing wedge meshes. If the bow flickers during combat, check for overlapping hull/bow faces or waterline clipping before changing camera or combat code.

### Load Capacity and Gun Ports

Cannon weight lives in [data/cannons/cannon_types.yaml](../data/cannons/cannon_types.yaml). Ship usable load capacity and gun ports live in [data/ships/ship_types.yaml](../data/ships/ship_types.yaml).

The player ship can also define `cargo_weight` in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml). Cannon weight plus cargo weight may not exceed the ship's usable load capacity. Extra cannons may be carried beyond available gun ports, but only cannons that fit the side's gun ports can fire.

Load affects sailing:

- `<= 60%`: lightly loaded, small speed and handling boost
- around `80%`: heavy, noticeable speed and handling penalty
- `>= 90%`: overloaded, significant speed and handling penalty

The debug UI shows load weight/capacity, load movement multipliers, gun ports per side, and cannon weight so YAML tuning is visible immediately.

### Ship Types and Modifications

Ship types live in [data/ships/ship_types.yaml](../data/ships/ship_types.yaml).

Ship modifications live in [data/ships/ship_modifications.yaml](../data/ships/ship_modifications.yaml).

The current player ship uses a `sloop` so Milestone 2 boat fights can start with a nimble player vessel against a tougher brig. Swap to `reinforced_hull` in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml) to test higher hull durability with a speed tradeoff.

The current target ship lives in [data/ships/target_ship.yaml](../data/ships/target_ship.yaml). Change its `ship_type` between `sloop`, `brig`, `frigate`, and `galleon` to test target size, hull durability, and magazine explosion risk. Add modifications there to verify target-side stat layering without changing the player ship.

Ship speeds are intentionally tuned closer to sailing craft than speedboats. Larger ships should have more hull and worse turning, so compare a lightly loaded `sloop` against a heavily loaded `galleon` when testing handling extremes.

For Milestone 2, the default sloop-vs-brig matchup intentionally exaggerates handling differences so the sloop feels nimble:

- sloop acceleration, deceleration, low-speed turn, and turn rate are much higher
- brig acceleration, deceleration, and turn rate are slower
- sloop sail trim responds faster than brig sail trim
- reload speed is not used as a mobility-balancing lever

Enemy AI has an initial firing delay and aim-commit time so the battle starts with a readable maneuvering moment instead of an immediate unavoidable broadside. If a larger player ship overwhelms a smaller target without return fire, tune `aim_tolerance`, `preferred_range`, `initial_firing_delay`, and `aim_commit_time` on `TargetShip`.

Ship combat profiles also define max hull, sail, crew, and morale pools. Sail, crew, and morale damage are tracked and shown in the debug UI, but they intentionally do not reduce movement, fire rate, or surrender behavior yet. Milestone 2 should attach gameplay consequences to those foundations.

Player and target ship YAML can define `crew` to set the starting crew for an encounter. Ship type `max_crew` remains the capacity; the per-ship `crew` value is the current complement.

Milestone 2 now attaches first-pass consequences:

- sail damage reduces effective sailing power
- zero sail health breaks the mast and stops movement
- crew damage reduces active broadside capacity at three crew per cannon
- surrender remains intentionally deferred

The target ship has editor-facing test toggles:

- `ai_enabled`
- `movement_enabled`
- `firing_enabled`

Use these to test a stationary target, a stationary target that fires, a moving target that does not fire, or the full boat fight.

Small targets keep their smaller visual scale, but target ships have a modest minimum cannon-hit footprint so shooting a sloop from a galleon does not feel like aiming at a sliver. Broadside shots also converge loosely toward a shared aim zone at distance; they should feel crew-aimed, not parallel spray and not sniper-precise.

### Fire Severity and Magazine Explosions

Fire levels live in [data/combat/status_effects.yaml](../data/combat/status_effects.yaml).

Repeated fire applications escalate:

```text
small -> medium -> large
```

Round shot has a low direct magazine explosion chance. That direct chance is heavily reduced unless the ship is already burning. Burning ships roll an explosion chance over time based on fire severity and ship explosion multiplier.

Fires can also grow on their own. The debug UI should progress from `BURNING (small)` toward `BURNING (medium)` or `BURNING (large)` sometimes without another fire shot. The smoke test forces this path once so the behavior is automatically covered even when random playtesting does not trigger it.

## Editor Checks

Open [game/scenes/Overworld.tscn](../game/scenes/Overworld.tscn), run the game, and try:

- sail around Jamaica and confirm the ship cannot pass through land
- use the compass to compare heading against the ship's visual direction
- confirm the wind arrow stays fixed while the ship turns
- sail near an NPC route and press `Enter` when the intercept prompt appears
- confirm the battle target matches the intercepted NPC's faction and ship type
- sink the target and confirm the game returns to the overworld

For direct battle testing:

Open [game/scenes/NavalBattle.tscn](../game/scenes/NavalBattle.tscn), run the game, and try:

- fire port broadside at long range
- fire starboard broadside at long range
- compare reload timing between sides
- select grape or fire shot and verify you need to get much closer
- use fire shot and watch for burning on either ship
- swap the target ship type in YAML and confirm the debug UI, target size, hull durability, and explosion feel change
- compare small ships and large ships for slower speed, heavier turning, and longer time-to-sink
- disable target `movement_enabled` to test cannon behavior against a stationary target
- use chain shot until sail health reaches zero and confirm the mast breaks
- use grape shot and confirm lower crew reduces enemy firing capacity
- change `crew` in player or target ship YAML and confirm the debug crew percentage and cannon limit update
- confirm the opening gives the player several seconds to orient before the enemy can fire

If behavior changes because of YAML edits, run content validation before opening the editor.
