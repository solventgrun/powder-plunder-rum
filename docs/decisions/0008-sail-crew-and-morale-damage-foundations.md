# ADR 0008: Sail, Crew, and Morale Damage Foundations

## Status

Accepted

## Context

Milestone 1 already defines ammo damage values for hull, sails, crew, and morale, but the runtime originally only applied hull damage plus armament disable chances. Before Milestone 2 adds active enemy boats, the combat damage contract should carry all declared damage channels so future behavior does not need to change projectile or ammo data shape.

## Decision

Ship combat profiles now define `max_sail`, `max_crew`, and `max_morale` alongside `max_hull`.

Player and target ships track current `sail`, `crew`, and `morale` pools. Projectile hits apply `sail_damage`, `crew_damage`, and `morale_damage` from ammo context, clamp those pools at zero, and expose fraction helpers for debug UI and future systems.

These pools intentionally have no gameplay consequences yet.

## Alternatives Considered

One alternative was to wait until Milestone 2 and add these channels when enemy steering or surrender needed them. That would keep Milestone 1 smaller but make the projectile hit contract more likely to churn during AI work.

Another alternative was to immediately make sail damage reduce movement and morale damage trigger surrender. That was rejected as premature because Milestone 2 should first establish the enemy boat fight loop and then tune consequences in context.

## Consequences

Ammo type differences are now represented in runtime state, not just YAML.

Milestone 2 can use these values for:

- sail damage reducing speed or turn response
- crew damage affecting reload or boarding readiness
- morale damage contributing to surrender

The debug UI and smoke test cover the damage plumbing, but balance and gameplay effects remain deferred.
