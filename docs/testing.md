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

The current player ship uses `brig` plus `copper_bottom`, which should make it slightly faster than a base brig. Swap to `reinforced_hull` in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml) to test higher hull durability with a speed tradeoff.

The current target ship lives in [data/ships/target_ship.yaml](../data/ships/target_ship.yaml). Change its `ship_type` between `sloop`, `brig`, `frigate`, and `galleon` to test target size, hull durability, and magazine explosion risk. Add modifications there to verify target-side stat layering without changing the player ship.

Ship speeds are intentionally tuned closer to sailing craft than speedboats. Larger ships should have more hull and worse turning, so compare a lightly loaded `sloop` against a heavily loaded `galleon` when testing handling extremes.

Small targets keep their smaller visual scale, but target ships have a modest minimum cannon-hit footprint so shooting a sloop from a galleon does not feel like aiming at a sliver. Broadside shots also converge loosely toward a shared aim zone at distance; they should feel crew-aimed, not parallel spray and not sniper-precise.

### Fire Severity and Magazine Explosions

Fire levels live in [data/combat/status_effects.yaml](../data/combat/status_effects.yaml).

Repeated fire applications escalate:

```text
small -> medium -> large
```

Round shot has a low direct magazine explosion chance. Burning ships roll an explosion chance over time based on fire severity and ship explosion multiplier.

Fires can also grow on their own. The debug UI should progress from `BURNING (small)` toward `BURNING (medium)` or `BURNING (large)` sometimes without another fire shot. The smoke test forces this path once so the behavior is automatically covered even when random playtesting does not trigger it.

## Editor Checks

Open [game/scenes/Main.tscn](../game/scenes/Main.tscn), run the game, and try:

- fire port broadside at long range
- fire starboard broadside at long range
- compare reload timing between sides
- select grape or fire shot and verify you need to get much closer
- use fire shot and watch for burning on either ship
- swap the target ship type in YAML and confirm the debug UI, target size, hull durability, and explosion feel change
- compare small ships and large ships for slower speed, heavier turning, and longer time-to-sink

If behavior changes because of YAML edits, run content validation before opening the editor.
