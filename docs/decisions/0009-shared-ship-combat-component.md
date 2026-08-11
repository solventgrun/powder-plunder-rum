# ADR 0009: Shared Ship Combat Component

## Status

Accepted

## Context

Milestone 1 left the player ship and target ship with duplicated damage behavior. That was acceptable while the target was a static cannon dummy, but Milestone 2 turns the target into an active enemy vessel that needs the same hull, sail, crew, morale, fire, explosion, sinking, mast-break, and armament-damage rules as the player.

Keeping separate implementations would make combat tuning error-prone as soon as enemy fire, player sinking, mast breaks, or crew-limited broadsides mattered on both sides.

## Decision

Shared ship combat state now lives in `game/scripts/combat/ShipCombatComponent.gd`.

Player input remains in `ShipController.gd`. Enemy steering and firing decisions live in `EnemyShipController.gd`. Broadside firing asks the owning ship for disabled guns, disabled gun ports, and active cannon capacity instead of owning damage state directly.

Milestone 2 uses the shared component for:

- hull, sail, crew, and morale pools
- projectile hit handling
- fire and magazine explosions
- sinking
- mast breaking when sail health reaches zero
- crew-limited active cannon count at three crew per cannon
- disabled cannons and gun ports

The target ship also exposes `ai_enabled`, `movement_enabled`, and `firing_enabled` toggles so tests and playtests can isolate stationary targets, non-firing movement, stationary firing, or the full boat fight.

## Alternatives Considered

One alternative was to keep `DamageableShip.gd` for targets and add AI around it. That would have been faster for a single enemy, but the player and enemy would immediately diverge on mast break, sinking, and crew-limited firing behavior.

Another alternative was to make player and enemy inherit from a shared base ship controller. That was rejected for now because input and AI are likely to change independently, while damage/status rules need to stay identical.

## Consequences

Combat consequences are now easier to keep consistent between player and enemy vessels.

The component introduces one extra node dependency in ship scenes, but the separation keeps Milestone 2 readable: controllers decide how ships move and fire, while the component owns what damage means.

Surrender, boarding, capture, rewards, and multi-ship combat remain deferred to a future advanced naval combat milestone.
