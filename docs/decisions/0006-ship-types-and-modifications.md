# ADR 0006: Ship Types and Modifications

## Status

Accepted

## Context

Before Milestone 2 introduces reactive enemy ships, the project needs basic ship stat profiles so handling, hull durability, size, cannon limits, and explosion risk can vary by ship. The game also intends to support ship upgrades similar in spirit to classic pirate games.

## Decision

Define ship types in `data/ships/ship_types.yaml` and ship modifications in `data/ships/ship_modifications.yaml`.

Ship types provide base stats:

- sailing speed, acceleration, deceleration, and turn rate
- max hull
- primitive visual scale
- magazine explosion multiplier
- max cannons per side
- cannon weight capacity

Ship modifications layer multipliers on top of the base ship type. The initial modifications are:

- `copper_bottom`: improves speed and acceleration
- `reinforced_hull`: improves hull durability with a small speed/acceleration penalty

The player ship config selects a ship type and modifications in `data/ships/player_ship.yaml`. The current target ship does the same in `data/ships/target_ship.yaml` so explosion-risk, hull, and size testing can happen without touching scene exports.

## Alternatives Considered

Hardcoding player stats would be faster, but it would not help test future enemy ship profiles.

A full inventory and upgrade system would be more complete, but it is premature before Milestone 2.

## Consequences

The prototype can now test whether ship identity matters while keeping the implementation simple. Enemy ships can reuse these profiles without new hardcoded stats.

Cannon weight and capacity are validated/displayed but do not affect sailing yet. That keeps the tradeoff visible without forcing balance decisions too early.

## Follow-Up

When enemy AI exists, decide whether enemy combat loadouts also belong in YAML ship config files or in encounter definitions. Revisit whether cannon weight should affect speed, acceleration, or cargo capacity.
