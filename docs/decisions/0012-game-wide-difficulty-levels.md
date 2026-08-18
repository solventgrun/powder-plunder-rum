# ADR 0012: Game-Wide Difficulty Levels

## Status
Accepted

## Context

The sword duel needed a difficulty axis: playtesting the first boarding build (2026-08-17) found the opponent attacking too rapidly in succession, and there was no way to say "make normal gentler" without permanently weakening every captain.

The obvious fix is a difficulty setting for duels. The user's framing was wider (2026-08-17):

> Difficulty is something we're going to need to consume pretty widely as it's going to impact sword fights, naval combat, future land combat, and impact spawning behavior in the overworld.

Plus a rule about when it is chosen:

> Do not allow the player to set the difficulty coming into the fight. When we get around to writing the game intro we'll have players set the game difficulty when creating a new game. So we just need our sword fight to be able to consume that data.

So a duel-scoped difficulty would have been the wrong shape twice over: wrong scope, and it invites a per-encounter choice the game does not want.

## Decision

**One game-wide difficulty level, chosen once at new-game creation, with a section per consuming system.**

`data/difficulty/difficulty_levels.yaml` holds the levels (`easy` / `normal` / `hard` / `brutal`). Each record carries one nested section per system that reads it:

```yaml
difficulty_levels:
  - id: normal
    name: Buccaneer
    duel:        # sword fights
      ...
    boarding:    # how readily enemies board you, and defender strength
      ...
    # naval:     added when naval combat wants a difficulty axis
    # land:      added when land battles exist
    # overworld: added for spawn rates, patrol density, pursuit
```

Sections are written **when their system is built**, not speculatively. `ContentCatalog.load_difficulty_section(level, system)` returns an empty dictionary for an unwritten section, so a consumer added before its data always falls back to its own defaults.

`GameSession.game_difficulty` holds the chosen level for the session (the intro that sets it does not exist yet; it defaults to `normal`). Systems read it through `GameDifficulty`:

```gdscript
var tuning := GameDifficulty.section("naval")
var multiplier := float(tuning.get("enemy_accuracy_multiplier", 1.0))
```

The duel keeps its context-free contract from ADR 0011: it receives a `difficulty_id` string in its context and resolves its own `duel` section. It never asks what the player's setting is — the caller supplies it, so a future scripted duel can be fought at a fixed level regardless of the player's choice.

Difficulty scales the **opponent only**, and multiplies whatever the archetype already said, so a Fleet Captain stays harder than a Merchant Master at every level.

## Alternatives Considered

**Difficulty per system, chosen separately** (a duel difficulty, a naval difficulty). More tuning freedom, but four settings the player must reason about and keep coherent, and no single answer to "how hard is this game". Rejected; one level with per-system sections gives the same tuning freedom to *us* without giving the player four dials.

**Difficulty as multipliers computed in code** rather than data. Cheaper today, but it puts balance in GDScript, against the project's "content lives in data, reusable behaviour lives in code" principle, and makes a per-system split awkward.

**Selecting difficulty per fight** (a line on the pre-duel weapon panel). Explicitly rejected by the user: difficulty belongs to the game, not the encounter. The weapon panel offers only the blade, and the level is deliberately not even displayed there.

**Letting the duel read `GameSession` directly.** One less parameter, but it would break the ADR 0011 rule that nothing in `game/scripts/duel/` reads game state, and it would stop callers from staging a duel at a level other than the player's.

## Consequences

**Easier.** Tuning any level is a data edit, validated like all other content. Adding a consumer is two steps that touch nothing existing: add a section to each level, read it with `GameDifficulty.section()`. The duel remains reusable, since difficulty arrives as a plain string in its context.

**Harder / deferred.** There is no UI to set difficulty — it is fixed at `normal` until the new-game intro is written, and changing it today means editing `GameSession.game_difficulty`. Difficulty is not yet persisted (there is no save system). And nothing enforces that levels stay *ordered* across systems: a future naval section could make `easy` harder than `hard` and only the content validator's per-section rules would object.

## Notes

The duel tuning this produced is recorded in `docs/design/boarding-duel-brief.md`. The specific fairness fix behind it: a landed hit staggers you, and a stagger counts as a free opening, so with no delay the opponent's next wind-up began while you were still frozen — you were being asked to read a tell you could not answer. `punish_delay` (0.45s at normal) holds the follow-up until you are back on your feet. The smoke test asserts that no attack on normal begins during a player stagger, and that the average gap between attacks stays above 1.6s.
