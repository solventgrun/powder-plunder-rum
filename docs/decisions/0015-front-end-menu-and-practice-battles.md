# ADR 0015: Front-End Menu and Practice Battles

## Status
Accepted

## Context

The game booted straight into the overworld. Trying a different loadout meant editing `data/ships/player_ship.yaml`, restarting Godot, sailing out from Port Royal, finding an NPC, and intercepting — for one broadside comparison. The enemy was worse: you got whichever overworld ship you happened to intercept, so "frigate against brig" was not a thing you could ask for.

That workflow also leaves faults in the data. When this work started, the working-copy `player_ship.yaml` carried fourteen 4-pounders on a sloop rated for forty tons — 56 tons, an error the content gate reports but which is invisible while you are hand-editing YAML between runs.

> We need to add a menu that loads at game start. It should give you two options one start game the other practice naval combat. [...] It should validate the load out options you give it so you don't overload a vessel with guns or something.

## Decision

**A main menu is the boot scene**, offering the campaign (`Start Game`) and the testing harness (`Practice Naval Combat`).

**Practice battles reuse the campaign's ship pipeline rather than paralleling it.** A hand-built ship is the same record shape the YAML files hold, so `build_ship_stats`, `ShipVisualBuilder`, `BroadsideController` and the damage model cannot tell the difference. Two seams carry it:

- The enemy already came from `GameSession.selected_encounter`, which `EnemyShipController` reads — the practice screen simply writes to it.
- The player did not; `ShipController` loaded `player_ship.yaml` directly. It now asks `GameSession.get_player_ship_record()`, which returns the practice override when there is one and the YAML file otherwise.

**Validation is the existing content gate, not a second copy of the rules.** `ContentValidator.validate_player_ship` was generalised into `validate_ship_loadout(label, ...)` so the same routine can speak as `player_ship` to the YAML gate and as `Your ship` to a player assembling a broadside. `validate_runtime_loadout` is the one-call form the screen uses.

**Errors block the battle; warnings do not.** Load past `usable_load_capacity`, crew past `max_crew`, unknown ids, an empty broadside — these disable `BEGIN BATTLE`. Carrying more guns than gun ports is a *note*, because the sim already handles it honestly: `BroadsideController` runs out as many as the ports allow and labels the rest `(+N stowed)`. They still weigh on the hull. Making that an error would contradict the model.

**A finished practice battle returns to the setup screen**, not the overworld, with the loadout intact and the result on the header. Escape breaks one off early.

## Alternatives Considered

**Cap the spinners so an illegal loadout cannot be entered.** Rejected: with several cannon types per side, each spinner's ceiling depends on every other, and the controls end up fighting the user. Showing `240 / 40` in red teaches the limit; silently refusing the keystroke does not.

**A debug console or command-line flags** (`--player-ship=frigate`). Cheaper to build, but invisible — and it would have no reason to run the validator, which is the half of the request that catches the overloaded sloop.

**Build the screens as `.tscn` files.** The control set is data-driven — a row per cannon type, a checkbox per modification, an entry per ship type — so it has to be assembled at runtime anyway. A hand-authored scene would freeze today's YAML into the layout; adding a cannon type now grows the screen with no one opening it.

## Consequences

**Easier.** Any matchup the content files can describe is two dropdowns and a few spinners away, and an illegal ship is caught before it sails rather than after. The screen doubles as a readout of what a hull can actually take: load, crew and gun ports against their ceilings, live.

**Harder / deferred.** The practice screen edits everything that affects a fight but not `visual_variant` or `sail_set`, which ride along from the seed record. Difficulty is still whatever `GameSession` holds (ADR 0012) — the menu is the obvious future home for choosing it at new-game creation, but does not yet. Wind, sea state and starting positions are the battle scene's defaults, so practice does not yet cover "the same matchup in a gale". `GameSession` now has campaign state and practice state side by side; if a third mode appears, that wants splitting.
