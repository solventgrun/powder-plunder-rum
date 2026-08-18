# ADR 0014: Hull Collisions and Ramming

## Status
Accepted

## Context

Ships already stopped each other — both are `CharacterBody3D` with collision shapes — but nothing came of it. Sailing into an enemy at speed did no damage, made no sound, and moved no camera (playtest 2026-08-17):

> We also need to add ships being able to collide and damage one another to the naval battle I realized that earlier when I ran into a ship and didn't do anything.

The same playtest surfaced a related measurement problem: boarding triggered from far too far away. Boarding compared **centre distance** against a tuned constant that had grown to `9.0 + 3.4 x each ship's scale` — about 19 units for a frigate and a galleon, when two ships lying alongside have their centres roughly 2.2 units apart. It was also blind to orientation: a ship lying beam-on and one lying bow-on were treated identically.

## Decision

**One shared measure of where a hull ends** (`ShipGeometry`), used by everything that cares how close two ships are. `hull_gap()` returns the water between the two hulls — zero is touching, negative is overlapping — by projecting each ship's collision box onto the line between them. Half-extents are read from the ship's own `CollisionShape3D`, so the measure cannot drift from the body that physically stops it.

Boarding now asks for a **gap** (`alongside_gap: 1.6`, metres of water) instead of a centre distance, which is both correct and independent of ship size and heading.

**Collisions are resolved centrally** in `ShipCollisionSystem`, a node in the battle scene, rather than on either ship. One collision produces one set of numbers instead of each hull deciding separately how hard it was hit.

Damage scales with closing speed **above a threshold**, and with the size difference. The threshold is what lets ramming and boarding coexist: coming alongside at a matched pace is free, which is exactly the approach boarding asks for. Driving a bow into a beam is a ram.

Feedback is deliberately loud: camera trauma, a foam ring at the waterline, and `HullSplinterEffect` — timber bursting from the seam in both directions with a dust puff, thrown on real gravity.

## Alternatives Considered

**Detect collisions on each ship** via `get_slide_collision()` after `move_and_slide()`. Natural, and it puts the check where the physics already is — but two ships would each resolve the same impact, so damage would be applied twice or need a handshake to avoid it.

**Keep the centre-distance measure and just shrink the constant.** Faster, and still wrong for orientation: no single number describes both a ship lying beam-on and one lying bow-on. The hull-gap version costs two dot products.

**Full mass influence on damage** (`mass_influence: 1.0`). Measured before shipping: a sloop grazing a galleon took 267 damage against its 110 hull — dead instantly, from a scrape. Reduced to 0.6 and the per-speed damage cut, so ramming a bigger ship is a bad idea rather than suicide. Impact speed is also capped so a freak closing speed cannot one-shot a hull.

## Consequences

**Easier.** Ramming is a real tactic for a big ship and a real mistake for a small one, using stats the game already has. Boarding distance is now correct and self-correcting: change a ship's collision box or scale and both boarding and ramming follow automatically.

**Harder / deferred.** Damage is applied on a cooldown while hulls are in contact, so a long grinding scrape costs several ticks rather than modelling sustained contact. Collisions do not currently foul rigging, lock ships together, or care where along the hull the impact landed — a bow-on ram and a broadside scrape differ only by closing speed. Nothing consumes collisions strategically yet: an enemy will never deliberately ram you.

At the current tuning, a sloop ramming a galleon at full closing speed takes about 40% of its hull and deals about 2% of the galleon's; the reverse is a cheap and effective tactic.
