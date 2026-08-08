# Playtest 0002: Milestone 1 Cannon Readability

## Date

2026-08-08

## Context

First playable feedback after adding primitive broadside firing, ammo selection, and a target ship.

## Observations

- Cannonballs moved too quickly to read clearly.
- The first shot appeared to fire both sides after pressing one fire key, so broadside input needed a sanity pass.
- Firing needed immediate feedback at the ship.
- Misses needed visible end-of-range feedback.
- The target became easy to lose off screen.
- The player ship still felt too fast in an empty world with no reference points.

## Changes Made

- Reduced cannon projectile speeds in YAML.
- Reduced base sailing speed and acceleration.
- Added primitive muzzle flashes.
- Added a procedural placeholder cannon boom.
- Added primitive splash markers when cannonballs reach max range.
- Added primitive impact flashes on hits.
- Added a minimal burning status effect for fire shot.
- Added a chance for fire shot to ignite the firing ship.
- Added a sunk/disabled target state when hull reaches zero.
- Added visible reload bars.
- Added a HUD target direction indicator.
- Confirmed broadside input should allow deliberate two-key double-fire while preventing one-key accidental double-fire.

## Follow-Up

Re-evaluate sailing speed once there are world reference points or moving enemy ships. Muzzle flashes and splashes are deliberately primitive and should be replaced or improved only after the broadside loop feels good.
