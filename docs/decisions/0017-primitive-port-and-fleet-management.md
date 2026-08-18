# ADR 0017: Primitive Port and Fleet Management Screens

## Status
Accepted

## Context

ADR 0016 made battles produce durable state: cargo, damage, crew shortages, prizes, a fleet, and a purse-shaped need that did not yet have a port to answer it. The backlog's Primitive Port milestone called for the smallest useful port interaction: sell cargo, repair ship, hire crew, leave port.

The fleet also needed a campaign-level management surface. A kept prize can already follow on the overworld and the player can shift flagships after a capture, but there was no calm screen for reviewing the whole company or changing the flagship later.

## Decision

Port Royal is the first primitive port. The overworld treats it as a proximity context action: when the flagship is close enough, `Enter` opens the port menu instead of starting an interception. `M` opens fleet management from the overworld.

The port is a menu of separate activities, each with its own screen:

- sell cargo from any ship in the fleet into the session purse
- buy provisions into any ship with room in her hold
- repair hull and sails on any ship, paid from the purse
- hire crew up to each hull's maximum complement, paid from the purse
- manage fleet
- leave port

Fleet management is shared. It can be reached from the overworld or from the port menu, and returns to the place that opened it. It lists every ship, its condition, free hold, cargo summary, and lets the player make another ship the flagship. It also owns each ship's standing rum ration, because rations are a fleet policy rather than a post-battle choice.

## Consequences

**Easier.** Post-battle consequences now have a home port loop: plunder becomes money, money becomes repairs and crew, and captured ships can be reviewed outside the after-action moment.

**Harder / deferred.** Prices are prototype-flat rather than market-driven. Treasure-fleet and military-payroll specie is not modeled yet; all money currently enters the purse by selling weighted cargo. Provisions can be bought now, but provisions and rum are not consumed until the campaign clock pass exists. Port inventory, named ports, asymmetric refits, ammunition stores, ship sales, and consort orders are still future work.
