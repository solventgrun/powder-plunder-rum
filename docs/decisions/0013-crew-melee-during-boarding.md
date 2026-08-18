# ADR 0013: Crew Melee During Boarding

## Status
Accepted

## Context

The first boarding build treated crew as an input and an output but never a participant. Crew size gated whether you could board, scaled the captain you met, and took a flat percentage loss after the duel resolved — but during the fight itself, nothing happened to it. The user caught this (2026-08-17):

> The crew doesn't play any role in this duel and doing well or poorly doesn't impact the crew. It feels like while the captains are fighting the crew should be as well... we want crew to be dying during the boarding cause that's what would happen and the battle should end if one crew kills the other before the end of the duel.

The reference image shows the same thing: live crew counts for both sides under the fight.

This reopened the resolution question from ADR 0011. An advantage tug-of-war bar, where the bar *is* the crews' momentum, would model this naturally — that is how the reference does it — but it was considered and rejected once already in favour of vigor pools.

## Decision

**Keep vigor pools, and run the crew melee as a parallel track with its own end condition.**

Two ways to lose a boarding: your captain is cut down, or your boarding party is wiped out. Either ends the action, and the result reports which (`outcome` says who won, `reason` says how).

**The melee lives in the duel as a context-free "supporting force".** The duel gains an optional `support` block — a count, a label, and a strength per side — which it simulates and reports on. It never learns the word "crew". Boarding fills it with crew numbers and interprets the casualties; a tavern brawl passes nothing and behaves exactly as before.

Attrition is Lanchester-flavoured: each side kills at a rate proportional to its **own** numbers, so an advantage compounds and 2-to-1 is decisive over time. The captains' duel is coupled to it in both directions: a landed blow kills men on the losing side immediately (`hit_burst`) and surges their killers' rate for a few seconds (`surge_gain`, decaying, capped). Good fencing buys time against worse odds; it cannot erase them.

Casualties are now **whatever the melee actually cost**, replacing the flat winner/loser percentages. The player commits a `boarding_party_fraction` of their crew over the rail; defenders field their whole crew and fight slightly better for standing on their own deck.

## Alternatives Considered

**Switch to the advantage tug-of-war**, with crew bleeding as the bar moves. Closest to the reference and the simplest thing to read. Rejected because it collapses the captains' fight and the crews' fight into a single number, which destroys the most interesting situation the feature creates: *your crew is winning while you are personally losing*, or the reverse. It would also have reversed a considered earlier decision.

**Crew melee as the real battle, duel as a lever on it.** Makes crew unambiguously central, but demotes the sword fight — the thing just built and approved — to a minigame feeding a bar.

**Run the melee in `BoardingController` rather than in the duel.** Conceptually tidier, since crew is a boarding concept. Rejected on a hard technical constraint: the duel pauses the scene tree, so the boarding controller's `_process` does not run while the fight is on screen. The melee would have needed its own always-process path and a separate clock, which would have prevented a landed hit from moving the melee on the frame it happened. Making the concept generic ("supporting forces") keeps it on the duel's clock without teaching the duel about ships.

**Numbers alone, with no coupling to the duel.** Simplest to reason about, and it makes pre-softening decisive — but the two halves never touch, so the duel becomes a spectator sport with a timer attached.

## Consequences

**Easier.** Grape shot now pays twice: a weaker captain *and* fewer defenders, and the second one is visible ticking down during the fight. A boarding that costs you dearly shows up in your ship's crew afterwards without any bookkeeping. The duel gained a genuinely reusable concept — a future tavern brawl can pit two groups of shipmates against each other with no new code.

**Harder / deferred.** There are now two tuning surfaces that interact (melee rates in `duel_rules.yaml`, crew numbers in `boarding.yaml`), and a badly chosen `base_kill_rate` can make either the duel or the melee irrelevant. Measured behaviour at the current tuning: an even boarding (45 v 45) is decided by the captains, a properly softened crew (45 v 15) breaks around 35s, and boarding a fresh galleon with a small party (40 v 90) wipes the player out at ~28s.

**Known risk.** You can now lose a boarding you were personally winning. That is intended pressure — the crew bars are on screen throughout and a break is announced — but it is the first place in the game where the player loses to something they cannot directly control, and it should be watched in playtesting.
