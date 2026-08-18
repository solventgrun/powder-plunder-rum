# ADR 0016: Post-Battle Consequences, Cargo, and the Player Fleet

## Status
Accepted

## Context

Winning a battle returned you to the overworld and nothing else happened. Sinking a ship and taking her surrender paid exactly the same — nothing — which left the boarding duel (ADR 0011) a system with no reason to exist: an elaborate way to reach an outcome identical to a broadside.

Damage did not survive a battle either. Every fight started from a hull rebuilt out of `data/ships/player_ship.yaml`, so nothing a battle did to you mattered once it ended. The brief's first principle is "distinct minigames, continuous consequences", and the naval loop had the minigame and none of the consequence.

Three user directives set the scope (2026-08-17):

> If we take the ship it can just follow us on the map for now. But we should be able swap ships. We also need to be able to track the players fleet and it was never intended for the player to stay with one ship I always wanted them to be able to build a fleet if they wanted or swap ships. I envision when we get further along players starting with a sloop and working up from there.

Damage carries **fully, with no free repair**. Morale gets **all four** consequences it was offered. Rum tracks drunkenness so a Republic of Rum event has something to fire on.

## Decision

**The player has a fleet, not a ship.** `GameSession` owns an array of ships and an index saying which one the player sails; `data/ships/player_ship.yaml` is now the fleet a new game *starts* with rather than the permanent truth. A fleet ship is two halves (`game/scripts/session/Fleet.gd`): a `loadout` in the same record shape the YAML uses — what she is — and a `condition` — what battles have done to her. Both are plain Dictionaries so the whole fleet serialises to readable data when save/load arrives.

**Damage persists by round-trip, not by special case.** `ShipCombatComponent` gained `apply_condition` / `export_condition`; the battle seeds from the flagship's condition on the way in and writes it back on the way out. Hull and sail travel as *fractions* so they survive retuning a ship type or bolting on a reinforced hull.

**The fleet is the repair system.** With no port and no free repair, a battered ship is mended by taking a fresh one — which is both historically apt and mechanically self-solving, and is why full persistence does not simply spiral. Naval stores jury-rig at sea; medicine returns wounded to duty; rum holds a crew together. All three are cargo.

**Cargo is twelve types in three roles**, named for the game: **plunder** (worth money — sugar, tobacco, cloth, spices, gold, luxury goods), **powder** (ship's and military stores — naval stores, gunpowder, round shot, small arms), **rum** (crew stores — rum, medicine). The field that matters is **value per ton**, spread about 60× from sugar to luxury goods, because a hold is small and what you leave behind is the decision. Scarcity balances that spread, not the numbers: manifests are hand-authored where it matters and rolled from a `cargo_role` otherwise, seeded from the ship's id so a plundered ship stays plundered.

**Cargo weighs against the same allowance as guns.** This needed no new system — `usable_load_capacity` already drove speed and handling — and it produces the sharpest consequence in the feature: the shipped frigate carries 220 tons of gun against a 220-ton hull, so **she cannot carry a penny of plunder until guns go over the side.** Principle 12 paying for itself.

**Morale stops being decorative.** It was tracked, damaged and displayed, but the only code that read it was the enemy's boarding odds. It now scales gunnery (guns manned and reload rate), triggers surrender at rock bottom, and bleeds deserters between battles — all through a new `morale:` section in `difficulty_levels.yaml`, per ADR 0012's pattern. Rum is a standing fleet ration policy rather than a post-battle button; once the world clock exists, that ration should consume cargo over time, affect morale, and build drunkenness.

**An after-action screen** stands between the battle and the overworld and asks one question several ways: what will you carry home? Cargo, guns and crew are metered live against the hull, and her fate — release, burn, sink, keep as consort, take as your own — sits outside the scroll where it cannot fall below the fold. It opens pre-loaded with the richest hold that actually fits, because a screen that greeted you already overloaded and already blocked would be teaching the constraint by punishing you for it.

**Consorts follow on the map and do not fight.** A kept prize keeps station on the flagship in the overworld. Prizes joining a battle is Multi-Ship Battle Readiness, deliberately not pulled forward.

**A fleet sails at the speed of its slowest ship** (user directive, 2026-08-17). This is what a consort actually costs, and it is what stops "keep every prize" from being strictly optimal: a fat galleon carrying the plunder your own hold could not take also makes you a galleon for travel purposes. The overworld debug panel names the fleet and says when a consort is holding you back, because an invisible speed penalty reads as the ship feeling wrong.

## Alternatives Considered

**Escorting prizes to port for sale**, the historically correct answer, was rejected for this pass because it drags Milestone 4 in with it. Consorts that simply follow give the fleet meaning now.

**Gold as a session counter** rather than a cargo type. Rejected for ordinary loot: coin that weighs nothing would be strictly better than every other prize and would gut the hold decision. Gold is dense and takes room, which is why luxury goods beat it per ton. Later note, 2026-08-17: treasure fleets and military payroll vessels are a different case. They should likely get explicit **specie / payroll** purse-value loot in addition to weighted cargo, hand-authored on special encounters so jackpots feel large without turning every hold into weightless money.

**Making gun-port overflow and hold overflow behave alike.** They do not: surplus guns are stowed (the sim already models it), while a hold past capacity is refused. One is a documented behaviour, the other has no downstream meaning.

**Capping the after-action sliders so an illegal hold cannot be entered.** Same reasoning as ADR 0015 — showing `265 / 220` in red teaches the limit; refusing the input does not.

**Applying medicine as a player choice.** Rejected: medicine has exactly one use, so a control would be a decision with one sensible answer. The surgeon works on whoever comes below, and the screen reports it.

## Consequences

**Easier.** Every battle now pays differently depending on how it ended, so boarding is finally worth its machinery. The loadout question has a second half — guns *or* plunder — that the practice screen (ADR 0015) already visualises. Ports (Milestone 4) inherit cargo, values and a purse-shaped hole to fill; save/load inherits a fleet that is already plain data.

**Harder / deferred.** Ammunition is still unlimited: gunpowder and round shot are valuable cargo that does nothing yet, deliberately, so the fleet playtest is not also an ammunition-scarcity playtest. Treasure-fleet and payroll jackpots need a separate specie/payroll payout layer so they can dwarf ordinary cargo without deleting the hold-capacity decision. Provisions now exist as cargo, but provisions and rum consumption still need a world clock; rum rations are currently policy only. Refits split guns evenly across sides — asymmetric loadouts want a port to do it in. Consorts do not fight, are not damaged, and cannot be given orders. Losing your last ship ends the campaign at the main menu with no ceremony.

**Three overworld bugs surfaced and were fixed here**, all older than this feature and all only visible once a ship had to follow another one. Overworld ships used `MOTION_MODE_GROUNDED`, so the island's flat collision top read as a floor and boats climbed the beach. A consort spawned on the flagship's exact position, and physics depenetrated the two overlapping hulls along the cheapest axis — vertically — leaving one riding 1.6 units high, clear above an island collision box only 1.55 tall, so she sailed over the land. And `OverworldNpcShip` measured its desired heading off one vector and its current heading off the opposite one, a half-turn apart: a ship with her target dead ahead computed a 180-degree correction and sailed away from it. Route-following NPCs had been doing this since they were written. All three are now covered by the consort smoke group.

**Watch in playtest.** Full persistence plus desertion plus surrender is a steep spiral by construction; the knobs are all in `difficulty_levels.yaml` (`morale`, `post_battle`) and `normal` is the tuning target. The two numbers most likely to be wrong are `desertion_per_battle` and `salvage_fraction`.
