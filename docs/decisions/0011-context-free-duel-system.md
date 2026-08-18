# ADR 0011: Context-Free Duel System and Boarding Handoff

## Status
Accepted

## Context

The CROSS SWORDS backlog item adds boarding to naval battles, with a sword duel against the opposing captain deciding the outcome. Two forces shaped the design beyond that description:

1. **The user's reuse warning (2026-08-17):** the duel will be reused in contexts that do not exist yet — tavern brawls, land battles, story duels — so it must not be built in a way that assumes it lives inside a naval battle.
2. **The project's own philosophy** (design brief, "Distinct Minigames, Continuous Consequences"): minigames stay separate; what matters is that results flow between them.

The obvious implementation — a duel that reads the two ship nodes, computes its own stakes, and applies its own consequences — satisfies today's requirement and makes every later reuse a rewrite.

There is also a mechanical question: how does a minigame hand control back and forth? The existing precedent is `GameSession.start_encounter` / `finish_battle`, which swaps whole scenes and carries state through an autoload. Applied to boarding, that would mean serialising an entire naval battle mid-fight so it could be restored after the duel.

## Decision

**Two layers with a data contract between them.**

`game/scripts/duel/` is context-free. It receives a **DuelContext** dictionary (combatants, weapon choices, flavour strings, an opaque `caller_payload`) and emits a **DuelResult** dictionary (outcome, vigor fractions, hits, weapons, duration, and the `caller_payload` echoed back verbatim). It reads no game state, looks up no autoloads, and decides no consequences. A fighter is data — pools, timings, tendencies, a coat colour — so a tavern drunk and a fleet captain are the same code with different numbers.

`game/scripts/combat/BoardingController.gd` is the naval-specific half and the only file that knows about both worlds. It decides when grapples may be thrown, converts the enemy's crew and morale into a weaker captain, builds the context, and turns the verdict back into ship state.

**The duel is an overlay, not a scene change.** `DuelArena` is built into the caller's own running scene at a far offset, takes over the camera, pauses the tree, and hands both back when the fight ends. No caller ever has to serialise its world to run a duel.

**Ships gain a "struck colours" state** (`ShipCombatComponent.strike_colors()`), distinct from sinking: the hull is intact and someone now owns it. This produces two new battle results, `enemy_captured` and `player_defeated`, which `GameSession` records for the Post-Battle Consequences item to build on.

User calls folded into this pass:

- Controls are the numpad with attacks in the left column by height, evasions in the middle placed by which way the body moves (jump at the top, duck at the bottom), taunt on 6, pistol on 9; slot 3 is reserved for a future weapon-specific move. The mirror of this — keying the evasion column to the incoming blade's height, so each attack shares a row with its answer — was built, played, and reversed on feel. Both arrangements have now been tried in the hand; treat the body-motion layout as settled unless a playtest says otherwise.
- Resolution is **vigor pools**, not an advantage tug-of-war.
- Presentation is a **3D deck arena** with chunky procedural figures, not a 2D stage — the backlog's "small 2D minigame" wording is superseded.
- Boarding is offered **whenever you are alongside**; how softened the enemy is scales the captain you meet rather than gating the prompt.
- **Losing the duel loses the battle**: you are cut down and your ship strikes.
- Weapons (cutlass / longsword / broadsword) trade speed against weight and are chosen per fight; either fighter may carry **one** pistol shot, fired when they choose, spoiled if they are hit mid-draw.

## Alternatives Considered

**Duel reads the ships directly.** Fewer moving parts today, and every future caller either fakes a ship or forks the duel. Rejected on the user's explicit reuse warning.

**Scene-change handoff through `GameSession`, matching the overworld → battle precedent.** Consistent with existing structure, but it requires serialising and restoring a live battle (ship positions, damage, fires, reload timers, AI state) for no gameplay benefit. The overworld → battle transition is a genuine change of place; a boarding is not. Rejected.

**Advantage tug-of-war bar** (as in the reference image) instead of vigor pools. It would show the crew-softening bonus directly on the bar as a head start. The user chose vigor pools so individual hits carry weight; the softening bonus is expressed through the opponent's stats and surfaced by the boarding prompt's "THEIR DECK: WEARY" line instead.

**Gating boarding behind crew/morale thresholds**, so grape shot unlocks boarding. Teaches the mechanic bluntly but restricts the player; rejected in favour of the design brief's "prefer decisions over arbitrary restrictions" — you may always board a fresh crew, you will simply meet a captain at full strength.

**A 2D minigame**, as the backlog originally proposed. Cheaper to make look intentional, but it becomes a second art pipeline beside the 3D ships and can never grow into the reference image.

## Consequences

**Easier.** A new duel context is now a dictionary, not a feature: a tavern brawl needs no changes inside `game/scripts/duel/`. Weapons, opponent archetypes, timings, damage, and which captain defends which deck all live in `data/duels/` and are validated like every other content file. The rules engine is drivable outside the scene tree, so exchanges are tested headlessly and deterministically rather than by playing.

**Harder / deferred.** Two layers mean the boarding-specific translation (crew and morale to captain strength) lives away from the duel that consumes it, so tuning difficulty means editing both `data/duels/duel_profiles.yaml` and `data/combat/boarding.yaml`. Pausing the tree is a blunt instrument: the caller's world stops completely, which is right for a boarding but may not suit a future duel meant to run while something else continues. The caller must hide its own HUD (`BoardingController.battle_hud_path`), since the duel cannot know what a caller's HUD looks like.

**Intentionally not built.** Prize handling and rewards (Post-Battle Consequences, the next item), NPC-initiated boarding, crew-vs-crew melee beyond the captains' duel, and duel audio.
