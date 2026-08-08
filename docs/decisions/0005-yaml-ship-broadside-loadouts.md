# ADR 0005: YAML Ship Broadside Loadouts

## Status

Accepted

## Context

The cannon prototype originally used one cannon type and one projectile count for both sides of the player ship. That was enough to prove broadside firing, but it could not represent meaningful equipment choices.

Future ships should be able to carry different cannon mixes, and heavier or longer-range cannons should eventually create tradeoffs. The project is not ready for a full inventory, cargo, or ship equipment system yet.

## Decision

Define the player ship's current broadside loadout in YAML under `data/ships/player_ship.yaml`.

Each side has a list of cannon IDs:

```yaml
player_ship:
  broadsides:
    port:
      cannons:
        - light_4_pounder
        - light_4_pounder
        - light_4_pounder
    starboard:
      cannons:
        - light_4_pounder
        - long_12_pounder
        - long_12_pounder
```

Each cannon entry fires one projectile. A side's reload time is the slowest `reload_time` among its cannons. Cannon weight is summed and displayed, but it does not affect gameplay yet.

## Alternatives Considered

One alternative was one cannon type plus count per side. That was simpler but would not prove mixed loadouts.

Another alternative was per-cannon reload timers. That would be more realistic but too complex for the current prototype.

## Consequences

The prototype can now test asymmetric broadside configurations and mixed cannon properties while keeping the combat loop readable.

Future ship types can build on this YAML shape. If weight later affects sailing, cargo, or crew choices, the data already exists and is visible in the debug UI.

## Follow-Up

Revisit side reload rules once enemy ships and longer naval combat exist. The current slowest-cannon reload rule is intentionally simple and may be replaced by per-cannon reload behavior later.
