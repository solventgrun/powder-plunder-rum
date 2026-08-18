# Boarding & Sword Duel Brief

Design record for the **CROSS SWORDS** backlog item (`pirate-game-design-principles-and-expansion-brief.md`, Backlog Additions 2026-08-16). Written 2026-08-17 from user direction; reference image is the *Sid Meier's Pirates!* (2004) deck duel.

The sequencing rule from the backlog holds: boarding comes before post-battle consequences, because together they complete the naval sequence — **battle -> boarding -> duel -> consequences**.

## The Corner We Are Deliberately Not Building Into

User directive: the sword fight will be reused in contexts that do not exist yet (tavern brawls, land battles, story duels, jail breaks). So the feature is **two layers with a data contract between them**, not one system:

```text
  CALLER (naval boarding today; tavern/land/story later)
      |
      |  builds a DuelContext dictionary
      v
  DUEL SYSTEM  (knows nothing about ships, factions, or battles)
      |
      |  emits a DuelResult dictionary
      v
  CALLER interprets the result in its own terms
```

Rules that keep the duel reusable, and which future work must not break:

1. **The duel never reads game state.** It receives a `DuelContext` and reads only that. No `GameSession` lookups, no ship nodes, no faction logic inside `game/scripts/duel/`.
2. **The duel never decides consequences.** It reports who won and how; the caller decides what that means. "The ship strikes her colours" is a *boarding* concept, not a duel concept.
3. **The duel is an overlay, not a scene change.** The caller instantiates `SwordDuel.tscn` into its own running scene, so no caller ever has to serialise its world to hand off to the duel. The arena sits at a far offset with its own camera; the tree pauses and the arena runs with `PROCESS_MODE_ALWAYS`.
4. **Callers pass an opaque payload through.** `context.caller_payload` is echoed verbatim in `result.caller_payload`, so a caller can route a result without the duel knowing what it routed.
5. **Combatants are data, not classes.** A fighter is a dictionary (vigor, weapon, skill, pistol, name, look). A tavern drunk and a Spanish admiral differ only in numbers and strings.

The naval-specific half lives in `game/scripts/combat/BoardingController.gd` and knows about both worlds. That is the *only* file that should.

## Controls (user-selected 2026-08-17)

Numpad, three columns. Attacks on the left by height; evasions in the middle placed by which way the body moves; utility on the right. Top-row number keys mirror the numpad for keyboards without one.

```text
  7 CHOP     8 JUMP     9 PISTOL
  4 THRUST   5 PARRY    6 TAUNT
  1 SLASH    2 DUCK     3  --
```

What beats what — each attack has exactly one answer:

| Attack | Aimed at | Beaten by |
| --- | --- | --- |
| `7` Chop | head | `2` Duck (go under) |
| `4` Thrust | chest | `5` Parry (turn it aside) |
| `1` Slash | legs | `8` Jump (go over) |

**Settled by play, 2026-08-17.** The evasion column is keyed to **your own body** — jump is at the top because you go up, duck at the bottom because you go down. The alternative (key the column to the incoming blade's height, so a high cut is answered on the high key, putting each attack on the same row as its answer) was built, played, and reversed: it reads better on paper and felt worse in the hand. Both have been tried; do not flip it a third time without a playtest saying so.

- Guessing the wrong evasion is worse than standing still: you are committed and wrong-footed (damage bonus to the attacker).
- Beating an attack staggers the attacker into a long recovery — that is your **riposte window**, and hits landed in it are worth far more.
- Attacking someone who is already winding up **interrupts** them, also for bonus damage. Trading blindly is punished; reading is rewarded.
- `6` Taunt does no damage. A landed taunt rattles the opponent: their next wind-up runs longer (easier to read) and their reads get worse for a few seconds. It leaves you wide open while you do it.
- `3` is deliberately unbound — reserved for a future weapon-specific move (dagger, kick, boot to the chest).

Every attack is telegraphed by a **wind-up** with a visible tell (weapon raised to the height it is coming from, plus a HUD cue). Reading the tell and answering it in the window is the whole game. Wind-up length is a weapon property, so a slow weapon is easier for your opponent to read.

## Resolution: Vigor Pools, and the Crew Beside You (user-selected)

Both fighters have a **vigor** pool shown as a bar. Hits subtract; first to zero yields. Not an advantage tug-of-war — hits are meant to feel individually weighty.

Vigor is the *duel's* currency and has no meaning outside it. The caller receives fractions remaining, never raw numbers it would have to interpret.

**The crews fight too** (ADR 0013). Each side can bring a **supporting force** — a count, a label, a strength — which fights on its own while the captains do. The duel never learns what they are; boarding fills them with crew, and a tavern brawl passes none at all and behaves exactly as a straight duel.

So there are two ways to lose a boarding:

```text
  your captain is cut down          -> reason: captain_yielded
  your boarding party is wiped out  -> reason: support_lost
```

`outcome` says who won; `reason` says how. Either ends the whole action, per the rule that losing a boarding loses the battle.

How the melee resolves:

- **Numbers set the baseline.** Each side kills at a rate proportional to its *own* numbers, so an advantage compounds and 2-to-1 is decisive given time.
- **The duel swings it hard.** A landed blow kills men on the losing side on the spot and surges their killers for a few seconds. Fencing well buys time against worse odds; it cannot erase them.
- **Casualties are what actually happened** — the flat winner/loser percentages are gone. You commit `boarding_party_fraction` of your crew over the rail; they defend with all of theirs, and fight slightly better for standing on their own deck.

Measured at the current tuning, which is what these numbers are for:

| Boarding party v defenders | What happens |
| --- | --- |
| 45 v 45 | Both bleed badly; the captains decide it (a wipe needs ~51s) |
| 45 v 28 | Nobody breaks; the duel decides it |
| 45 v 15 (well softened) | Their line breaks around 35s — you can win on weight of numbers |
| 40 v 90 (boarding a fresh galleon) | *You* are wiped out at ~28s |

This is where grape shot finally pays twice: a weaker captain, and fewer men to get through — the second one visibly ticking down while you fight.

## Weapons (user request 2026-08-17)

Chosen at the start of the fight from a pre-duel panel, driven by `context.weapon_choices`. Weapons trade **speed against weight**:

| Weapon | Wind-up | Recovery | Damage | Feel |
| --- | --- | --- | --- | --- |
| Cutlass | fastest | shortest | lowest | Flurry. Hard for the opponent to read, forgiving of mistakes. |
| Longsword | middle | middle | middle | The honest choice. |
| Broadsword | slowest | longest | highest | Every swing is a commitment; two clean hits change a fight. |

The same table applies to NPCs — a captain's weapon comes from their profile, so an opponent with a broadsword genuinely fights differently from one with a cutlass.

## The Pistol (user request 2026-08-17)

Either fighter may carry **one** shot, fired at a moment of their choosing (`9`).

- Drawing takes a beat before it fires — you are defenceless during the draw.
- Taking a hit mid-draw **spoils the shot**: it is spent, and nothing comes out of it.
- It cannot be evaded once it goes off. It is the biggest single chunk of damage in the fight.

So the decision is *when*, not *whether*: fire into an opponent's recovery and it is nearly free; fire while they are winding up and you eat the attack and waste the shot. The NPC brain obeys the same rule with a `pistol_discipline` parameter — a disciplined officer waits for the window, a wild pirate fires early.

Whether a fighter carries one is context data (`fighter.pistol`), so a future tavern brawl can simply say nobody is armed.

## Difficulty

Difficulty is **game-wide and chosen once at new-game creation** (ADR 0012) — never a per-fight option, and deliberately not even displayed on the weapon panel. The duel receives a `difficulty_id` in its context and reads its own `duel` section from `data/difficulty/difficulty_levels.yaml`; it never asks what the player picked. Levels scale the **opponent only**, multiplying whatever their archetype already said.

The tuning target is `normal`. What actually governs how hard a duel feels is pacing, not stats:

| Knob | What it does |
| --- | --- |
| `attack_pause_slow` / `attack_pause_fast` | Gap between voluntary attacks; the fighter's own aggression picks a point between them. |
| `punish_chance` | How often a free opening — your recovery, your stagger — is taken at all. At 1.0 every mistake is punished the instant you make it, which reads as relentless rather than skilful. |
| `punish_delay` | How long they wait before taking one. **The fairness knob.** |

**The pacing fix (playtest 2026-08-17).** The first build attacked too rapidly in succession. The cause was not the attack rate: a landed hit staggers you for 0.5s, a stagger counts as a free opening, and the opponent took every opening after only a reaction delay — so the next wind-up began while you were still frozen, leaving a fraction of the tell to read once you could move again. You were being asked to answer a tell you never got to see. Two changes fixed it, both now regression-tested:

- The punish decision is made **once per opening** instead of re-rolled every frame. Re-rolling a 45% chance sixty times a second means it always fires.
- `punish_delay` (0.45s at normal) holds the follow-up until you are back on your feet, so every tell starts from a settled guard.

Normal now averages ~2.3s between attacks against a passive target, and never begins a wind-up during a player stagger. The smoke test asserts both.

**The defence bug (playtest 2026-08-17, same day).** The next playtest reported the opposite complaint: the opponent did not fight back at all and could be hit repeatedly without effort. The cause was not pacing:

> The opponent's reaction time was measured against the *player's* wind-up, and nothing kept it inside one.

A cutlass wind-up is 0.45s; a normal-difficulty captain's reaction is 0.41s (0.33 profile x 1.25) and a boarding-softened one 0.62s. When reaction exceeds `wind-up - evade_startup`, the reaction timer never expires while the blade is in the air, so **no answer was attempted at all** — the captain simply stood there. Softening a crew with grape shot did not weaken their captain's defence, it switched it off. Measured before the fix: zero evasions in a 60-second exchange for every case except a fresh captain against a longsword.

Two fixes, both regression-tested:

- The reaction is **clamped to what the incoming wind-up can accommodate** (`ANSWER_MARGIN` in `DuelOpponentBrain`). A fighter always gets to *attempt* an answer; `read_accuracy` decides whether the answer is right. That is the honest difficulty axis anyway — a weak captain should guess wrong, not fail to guess.
- The boarding softening now has **floors** (`minimum_read_accuracy`, `minimum_aggression` in `boarding.yaml`), so a broken crew's captain fences badly rather than not at all. The reward for grape shot is an easy fight, not an unopposed one.

The general lesson, worth remembering for any future reaction-timed AI: a reaction time that is not bounded by the window it must react within does not make an opponent slower, it makes them absent.

## Opponent Strength Scales With How Softened They Are (user-selected)

Boarding is offered **whenever you are alongside** — no crew or morale gate on the prompt. What softening buys you is a weaker opponent, not permission:

```text
  enemy crew fraction + morale fraction
        -> condition 0..1
        -> scales opponent vigor, reaction speed, read accuracy, aggression
```

A fresh galleon crew fields a captain at full vigor with sharp reads; a crew shot to pieces with grape fields a slow, weary one. This is where **grape shot finally earns its strategic purpose** (backlog), and it teaches by feel rather than by a locked prompt.

The scaling lives in the *boarding* layer, not the duel — the duel just receives a fighter that happens to be weak.

Boarding also reads difficulty directly (`boarding` section of the difficulty level): how readily an enemy boards you, the crew advantage they want first, and how well a defender fights on their own deck.

## Who Boards Whom

Boarding runs both ways (user call 2026-08-17). The enemy evaluates it once per opportunity — deciding every frame would mean any chance above zero fires instantly — and needs a crew advantage before trying, both tuned by difficulty. Having committed, they **bear down on you instead of holding their gunnery standoff**, which is the warning you get: the HUD reads `SHE MEANS TO BOARD US!` and you may still choose to board her first.

Being boarded is the same fight with the roles swapped: you defend your own deck with your **whole crew** at defender strength, while they come across with a party. The duel itself is unchanged — only the context differs.

Two deliberate omissions, decided rather than overlooked:

- **You cannot break off a boarding.** Once grapples are away it is settled one way or the other. `DuelController.abandon()` exists as an API escape hatch for callers whose world disappears under a duel, but nothing in the game offers it to the player.
- **You do not choose how many hands to bring.** `boarding_party_fraction` is a constant. Making it a decision was considered and rejected as more complexity than the choice is worth.

## Stakes (user-selected)

- **Win the duel:** the enemy strikes her colours. The battle ends as a capture. Reward/prize handling belongs to the next backlog item (Post-Battle Consequences); for now the result is carried to `GameSession` as a distinct outcome so that item has something to build on.
- **Lose the duel:** the duel loss *is* the battle loss. You are cut down on the deck and the battle ends against you.

Boarding costs crew on both sides even when you win — whatever the melee actually cost, applied to both ships — so a boarding you barely survive shows up in your ship's state afterwards.

## Presentation (user-selected)

A **3D deck arena** matching the reference framing: side-on camera, plank deck, rail and sea behind, two fighters facing off. We have no character models, so the first pass builds **chunky procedural figures** (blocky limbs, coat, hat, sword) posed by code — consistent with the north star's "bold silhouettes, readable at 1080p" and honest about being a first pass. Better geometry later is a swap-in behind `DuelFighter`.

HUD, in the established `HudStyle` register (gold-framed dark wood, parchment text):

```text
   YOU  [############------]        [##########--------]  CAPTAIN
        Cutlass                          Broadsword
                                                        +-----------+
                                                        |7  |8  |9  |
                                                        |4  |5  |6  |
                                                        |1  |2  |3  |
                                                        +-----------+
```

The numpad legend stays on screen (the reference keeps it up permanently) with live key states: greyed when an action is unavailable, lit while active, struck through once the pistol is spent.

## What This Pass Does Not Do

Deliberately deferred, in rough order of when they will start to hurt:

- **Post-battle consequences / prize handling.** Next backlog item; capture currently just ends the battle with a distinct result.
- **Individual crew combatants.** The melee is an attrition model with a background brawl standing in for it, not a simulation of named fighters. The figures on deck thin out to match the numbers; they are not the ones dying.
- **Multi-round duels, wounds carried between fights, captain persistence.** Waits on the persistent-captains idea in the design brief.
- **Audio.** The whole game is near-silent; the duel joins the queue for the audio pass.
