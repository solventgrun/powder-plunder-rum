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

### Cannon Weight Visibility

Cannon weight currently has no gameplay effect. The debug UI shows total cannon weight so we can verify ship loadouts are being read and summed correctly before weight affects sailing or cargo decisions.

## Editor Checks

Open [game/scenes/Main.tscn](../game/scenes/Main.tscn), run the game, and try:

- fire port broadside at long range
- fire starboard broadside at long range
- compare reload timing between sides
- select grape or fire shot and verify you need to get much closer
- use fire shot and watch for burning on either ship

If behavior changes because of YAML edits, run content validation before opening the editor.
