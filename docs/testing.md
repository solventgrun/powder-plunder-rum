# Prototype Testing Guide

This project keeps small testing artifacts close to the prototype so tuning remains fast and visible.

## Commands

Validate YAML content:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_content_validation.ps1
```

Run the full headless smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_smoke_test.ps1
```

Screenshot the front-end screens (windowed, saves PNGs to `--out`):

```powershell
godot --path . res://tools/_MenuProbe.tscn ++ --out=C:/some/dir
```

Drive the whole front-end flow end to end — menu, setup, battle, back again — and
assert each hop landed where it should:

```powershell
godot --path . res://tools/_FlowProbe.tscn ++ --out=C:/some/dir
```

Both probes are disposable (`tools/_*`). Note that new `class_name` scripts are
invisible to `--script` runs until Godot has rescanned the project; if the smoke
test reports `Identifier "X" not declared`, run `godot --headless --path . --import`
once, or just open the editor.

## Current Test Scenarios

### Practice Naval Combat

The game boots to a menu ([game/scenes/MainMenu.tscn](../game/scenes/MainMenu.tscn))
with two ways in. `Practice Naval Combat` opens a setup screen where **both**
ships are built by hand — ship type, colours, crew, cargo, a count per cannon
type per side, and modifications — then fights them immediately. This is the
fast path for a loadout question: it replaces editing
[data/ships/player_ship.yaml](../data/ships/player_ship.yaml) and restarting, and
unlike the overworld it lets you choose the enemy.

The screen validates through the same rules that gate the YAML files
(`ContentValidator.validate_runtime_loadout`), so what it accepts is exactly what
the content files may contain:

- **Faults** (red, and `BEGIN BATTLE` is disabled): load past the hull's
  `usable_load_capacity`, crew past `max_crew`, an empty broadside, unknown ids.
- **Notes** (amber, still sailable): more cannons on a side than gun ports. Those
  guns are stowed — they weigh on the hull but cannot be run out, matching what
  `BroadsideController` does with them.

Load, crew and gun-port counts sit under each ship's title and turn colour the
moment a limit is crossed, so the ceilings are visible while you build rather
than only when you try to sail.

The seeded loadouts are read from `player_ship.yaml` and `target_ship.yaml`, so
the screen also reports faults already sitting in those files. A finished
practice battle returns here with the loadout intact and the result on the
header; `Escape` breaks one off early.

### Cargo, Prizes, and the Fleet

Cargo types live in [data/cargo/cargo_types.yaml](../data/cargo/cargo_types.yaml),
role-based hold generation in [data/cargo/cargo_roles.yaml](../data/cargo/cargo_roles.yaml).
A ship's hold is her `cargo:` block if she has one, otherwise rolled from her
`cargo_role` — seeded from her id, so a plundered ship stays plundered.

**Cargo weighs against the same allowance as guns.** The shipped player frigate
carries 220 tons of gun against a 220-ton hull, so she has *no* free hold: to
bring plunder home you must throw guns overboard at the after-action screen. Set
a lighter loadout in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml)
or on the practice screen to see the other side of that trade.

Value per ton is the number to tune. Sugar sits at 1.5 and luxury goods at 90;
that spread is what makes a small hold a decision. Scarcity balances it — edit
the manifests, not the prices, if bulk goods feel worthless.

Three goods do something today: **naval stores** repair hull and sail at the
after-action screen, **rum** lifts morale and makes the crew drunk, **medicine**
returns wounded to duty automatically, and **small arms** strengthen a boarding
party. `gunpowder` and `round_shot` are deliberately inert until ammunition is
consumed.

Damage now persists with no free repair. A ship carries her hull, sail, crew,
morale and drunkenness between battles; the fleet is the repair system — take a
fresh prize when yours is beaten up. Losing your last ship ends the campaign.

Morale drives gunnery (guns manned and reload), surrender, desertion between
battles, and boarding strength. All of it is tuned in the `morale:` and
`post_battle:` sections of
[data/difficulty/difficulty_levels.yaml](../data/difficulty/difficulty_levels.yaml).
If the game feels like a death spiral, `desertion_per_battle` and
`salvage_fraction` are the two most likely culprits.

Exercise the after-action screen without fighting a battle:

```powershell
godot --path . res://tools/_AfterActionProbe.tscn ++ --out=C:/some/dir
```

It stages a captured treasure galleon, a sunk trader, and a lost ship, and
drives the capture case through to a confirmed outcome.

### Asymmetric Broadside Range

Player cannon loadout lives in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml).

The current player ship intentionally has:

- port: three `light_4_pounder` cannons
- starboard: one `light_4_pounder` and two `long_12_pounder` cannons

This lets us test whether different cannon types on different sides produce meaningful range, reload, and weight differences.

### Ammo Range Differences

Ammo range multipliers live in [data/cannons/ammo_types.yaml](../data/cannons/ammo_types.yaml).

Current intent:

- round shot: longest range
- chain shot: medium range
- grape shot: close range
- fire shot: very close range, with burning and self-ignition risk

### Fire Shot Risk

Fire shot can apply `burning` to the target and has `self_ignition_chance`, which can set the firing ship on fire. This is intentionally reckless and should remain easy to tune.

### Wind Strength and Direction

Wind is loaded from [data/environment/environment_conditions.yaml](../data/environment/environment_conditions.yaml). The current active record is `default_battle`, which defines wind direction, strength, and reference strength.

The file is named for environment conditions rather than only wind because future battle scenes may receive additional overworld context such as storms, reefs, or visible landmarks. Only wind is consumed right now.

Debug playtest overrides:

Use:

- `[` / `]`: decrease / increase wind strength
- `,` / `.`: rotate wind direction

The debug panel shows wind heading, strength, and the current wind speed factor. Test ship speed in light, moderate, and strong wind before changing ship type speed values.

### Ship Visual Readability

Faction flags are generated from [data/visuals/flags.yaml](../data/visuals/flags.yaml). The pirate faction should display a bold black Jolly Roger with a white skull-and-crossbones style mark. Flags stream downwind from their staff (aft on ships without a wind system), ripple with a traveling wave, and use chunky high-contrast generated textures so emblems remain readable at gameplay camera distance.

Bow visuals are generated as forward-facing wedge meshes. If the bow flickers during combat, check for overlapping hull/bow faces or waterline clipping before changing camera or combat code.

### Load Capacity and Gun Ports

Cannon weight lives in [data/cannons/cannon_types.yaml](../data/cannons/cannon_types.yaml). Ship usable load capacity and gun ports live in [data/ships/ship_types.yaml](../data/ships/ship_types.yaml).

The player ship can also define `cargo_weight` in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml). Cannon weight plus cargo weight may not exceed the ship's usable load capacity. Extra cannons may be carried beyond available gun ports, but only cannons that fit the side's gun ports can fire.

Load affects sailing:

- `<= 60%`: lightly loaded, small speed and handling boost
- around `80%`: heavy, noticeable speed and handling penalty
- `>= 90%`: overloaded, significant speed and handling penalty

The debug UI shows load weight/capacity, load movement multipliers, gun ports per side, and cannon weight so YAML tuning is visible immediately.

### Ship Types and Modifications

Ship types live in [data/ships/ship_types.yaml](../data/ships/ship_types.yaml).

Ship modifications live in [data/ships/ship_modifications.yaml](../data/ships/ship_modifications.yaml).

The current player ship uses a `sloop` so Milestone 2 boat fights can start with a nimble player vessel against a tougher brig. Swap to `reinforced_hull` in [data/ships/player_ship.yaml](../data/ships/player_ship.yaml) to test higher hull durability with a speed tradeoff.

The current target ship lives in [data/ships/target_ship.yaml](../data/ships/target_ship.yaml). Change its `ship_type` between `sloop`, `brig`, `frigate`, and `galleon` to test target size, hull durability, and magazine explosion risk. Add modifications there to verify target-side stat layering without changing the player ship.

Ship speeds are intentionally tuned closer to sailing craft than speedboats. Larger ships should have more hull and worse turning, so compare a lightly loaded `sloop` against a heavily loaded `galleon` when testing handling extremes.

For Milestone 2, the default sloop-vs-brig matchup intentionally exaggerates handling differences so the sloop feels nimble:

- sloop acceleration, deceleration, low-speed turn, and turn rate are much higher
- brig acceleration, deceleration, and turn rate are slower
- sloop sail trim responds faster than brig sail trim
- reload speed is not used as a mobility-balancing lever

Enemy AI has an initial firing delay and aim-commit time so the battle starts with a readable maneuvering moment instead of an immediate unavoidable broadside. If a larger player ship overwhelms a smaller target without return fire, tune `aim_tolerance`, `preferred_range`, `initial_firing_delay`, and `aim_commit_time` on `TargetShip`.

Ship combat profiles also define max hull, sail, crew, and morale pools. Sail, crew, and morale damage are tracked and shown in the debug UI, but they intentionally do not reduce movement, fire rate, or surrender behavior yet. Milestone 2 should attach gameplay consequences to those foundations.

Player and target ship YAML can define `crew` to set the starting crew for an encounter. Ship type `max_crew` remains the capacity; the per-ship `crew` value is the current complement.

Milestone 2 now attaches first-pass consequences:

- sail damage reduces effective sailing power
- zero sail health breaks the mast and stops movement
- crew damage reduces active broadside capacity at three crew per cannon
- surrender remains intentionally deferred

The target ship has editor-facing test toggles:

- `ai_enabled`
- `movement_enabled`
- `firing_enabled`

Use these to test a stationary target, a stationary target that fires, a moving target that does not fire, or the full boat fight.

Small targets keep their smaller visual scale, but target ships have a modest minimum cannon-hit footprint so shooting a sloop from a galleon does not feel like aiming at a sliver. Broadside shots also converge loosely toward a shared aim zone at distance; they should feel crew-aimed, not parallel spray and not sniper-precise.

### Fire Severity and Magazine Explosions

Fire levels live in [data/combat/status_effects.yaml](../data/combat/status_effects.yaml).

Repeated fire applications escalate:

```text
small -> medium -> large
```

Round shot has a low direct magazine explosion chance. That direct chance is heavily reduced unless the ship is already burning. Burning ships roll an explosion chance over time based on fire severity and ship explosion multiplier.

Fires can also grow on their own. The debug UI should progress from `BURNING (small)` toward `BURNING (medium)` or `BURNING (large)` sometimes without another fire shot. The smoke test forces this path once so the behavior is automatically covered even when random playtesting does not trigger it.

### Boarding and the Sword Duel

Boarding rules live in [data/combat/boarding.yaml](../data/combat/boarding.yaml). Duel weapons, timings, and opponent archetypes live in [data/duels/](../data/duels/).

**Boarding runs both ways.** An enemy that decides to board you stops holding its gunnery standoff and bears down; the prompt changes to `SHE MEANS TO BOARD US!` and you can still board her first. How readily they try it is difficulty-driven (`boarding` section: `enemy_boarding_chance`, `enemy_crew_advantage`), so test on `brutal` if you want it to happen every time. `BoardingController.enemy_boarding_enabled` is an editor toggle for exercising a battle without it.

Being boarded swaps the melee roles: you defend with your whole crew at defender strength, they come across with a party. Note the smoke test disables boarding in every non-boarding battle test — a grapple firing mid-test rewrites the battle a gunnery or fire test is measuring.

Boarding is offered whenever you are alongside at low relative speed — never gated on how battered the enemy is. What softening buys you is a weaker captain, so the intended test is a comparison:

- board a fresh enemy: full-vigor captain, sharp reads, fast reactions
- shoot the same enemy with grape until crew and morale are low, then board: the prompt reads `THEIR DECK: WEARY` or `BROKEN`, and the captain is slower, weaker, and reads attacks worse

Duel controls are the numpad (top-row number keys mirror it). Attacks are the left column by height, evasions the middle column by which way the body moves:

```text
7 CHOP     8 JUMP     9 PISTOL
4 THRUST   5 PARRY    6 TAUNT
1 SLASH    2 DUCK     3  --
```

Each attack has exactly one answer: chop is ducked, thrust is parried, slash is jumped. The mirrored layout (evasions keyed to the attack's height instead of the body's motion) was played and rejected on feel — retest before proposing it again. Things worth checking by hand:

- answering a tell with the right evasion turns the blow and leaves the attacker in a long recovery (the riposte window)
- guessing the wrong evasion hurts more than not guessing at all
- attacking someone mid-wind-up interrupts them for bonus damage
- weapon choice changes the feel: a cutlass wind-up is much shorter than a broadsword's, and a broadsword hits far harder
- the pistol (`9`) fires once at a moment of your choosing, and a hit taken during the draw spoils it outright
- a taunt (`6`) leaves you open, but a landed one makes the opponent's next wind-up longer and their reads worse

Duel timing note: `evade_active` in [data/duels/duel_rules.yaml](../data/duels/duel_rules.yaml) must stay comfortably wider than the spread between a fast and a slow human answer to a tell. If it is too narrow, reacting *quickly* is punished because the evasion expires before the blow lands, which is the opposite of the intended skill.

### Ramming and Hull Collisions

Rules live in [data/combat/ship_collisions.yaml](../data/combat/ship_collisions.yaml). Ships have always stopped each other physically; now it costs them (ADR 0014).

- gentle contact does **nothing** — that is deliberate, and it is what lets you come alongside to board. If closing gently starts hurting, `minimum_impact_speed` is too low and boarding becomes impossible
- ramming with the bigger ship is a tactic; ramming with the smaller one is a mistake. A sloop hitting a galleon at full speed loses roughly 40% of its hull and takes about 2% off the galleon
- every impact should throw splinters, kick a foam ring, and shake the camera

`mass_influence` is the dangerous knob: at 1.0 a sloop grazing a galleon died instantly from a single scrape. Verify with `tools/_BattleProbe.tscn`, which fires a broadside and then rams, printing both hull totals.

Boarding distance uses the same measure — the **gap between hulls**, not between centres, so it is correct regardless of ship size or which way either is lying. If boarding ever triggers from implausibly far away again, check `alongside_gap` in `boarding.yaml` and `ShipGeometry.hull_gap`.

### Difficulty

Levels live in [data/difficulty/difficulty_levels.yaml](../data/difficulty/difficulty_levels.yaml) and are game-wide (ADR 0012): one level, chosen at new-game creation, with a section per consuming system. Only the `duel` section is written so far. There is no UI yet — to test another level, set `game_difficulty` on the `GameSession` autoload, or pass a `difficulty_id` in a duel context.

`normal` is the tuning target. The two knobs that decide how hard a fight feels are `punish_chance` (how often a free opening is taken) and `punish_delay` (how long they wait first). If a duel starts feeling unfair rather than hard, check whether wind-ups are beginning while you are still staggered — that is the failure mode `punish_delay` exists to prevent, and the smoke test guards it.

Two failure modes have already been found by playing and are now guarded by the smoke test — check for both after touching the opponent brain:

- **Attacks too rapid in succession.** Wind-ups beginning while you are still staggered from the last hit, so you never get to read the tell. Fixed by `punish_delay`.
- **Opponent does not fight back.** A reaction time longer than the wind-up it must answer means no defence is ever attempted — the captain stands there being hit. This is invisible in the data (his stats look merely "slow") and obvious in play. Any AI reaction must be bounded by the window it reacts within.

To measure pacing rather than argue about it:

```powershell
godot --headless --path . --script res://tools/_duel_check.gd
```

It prints attacks-per-minute and the average gap between attacks at every difficulty. Normal currently sits around a 2.7s gap against a passive target; the smoke test fails below 1.6s.

### The Crew Melee

Both crews fight while the captains do (ADR 0013), with live counts and bars on each HUD panel and a brawl on deck behind the duellists that thins as men fall. Tuning lives in the `support:` block of [data/duels/duel_rules.yaml](../data/duels/duel_rules.yaml) and the party/defender settings in [data/combat/boarding.yaml](../data/combat/boarding.yaml).

Things to check by hand:

- landing a blow visibly costs their side men and flares your crew bar — if the melee looks like it is happening independently of your fight, the coupling (`hit_burst`, `surge_gain`) is too weak
- a well-softened crew can be overwhelmed before the duel finishes; an evenly matched one should not be
- boarding a fresh, larger crew with a small party gets your boarders wiped out — and that loses the battle even if you are winning your duel

Reference points at the current tuning, measured with `tools/_duel_check.gd`:

| Party v defenders | Expected |
| --- | --- |
| 45 v 45 | The captains decide it; a wipe needs ~51s |
| 45 v 15 | Their line breaks around 35s |
| 40 v 90 | Your boarders are wiped at ~28s |

Result paths to verify:

- win the duel: the enemy strikes her colours, the ship is captured rather than sunk, and the battle ends with `enemy_captured`
- lose the duel: you are cut down, your ship strikes, and the battle ends with `player_defeated`
- win or lose by the melee instead: same two outcomes, but the banner reads THEY ARE OVERWHELMED / YOUR BOARDERS ARE CUT DOWN, and the result's `reason` is `support_lost`
- either way, both ships lose exactly the hands the melee cost them — check the crew percentages afterwards

Two probes support this work (both need rendering, so do not use `--headless`):

```powershell
godot --path . res://tools/_DuelProbe.tscn ++ --out=C:/some/dir
godot --path . res://tools/_BoardingProbe.tscn ++ --out=C:/some/dir
```

`_DuelProbe` drives a duel through guard, tell, evasion, strike, taunt, pistol, and yield, saving one screenshot each. `_BoardingProbe` loads the real naval battle, lays the enemy alongside, and captures the prompt at each state plus the duel taking over the live battle scene. `tools/_duel_check.gd` is a headless bench for exchange outcomes and timings (`godot --headless --path . --script res://tools/_duel_check.gd`).

## Editor Checks

Open [game/scenes/Overworld.tscn](../game/scenes/Overworld.tscn), run the game, and try:

- sail around Jamaica and confirm the ship cannot pass through land
- use the compass to compare heading against the ship's visual direction
- confirm the wind arrow stays fixed while the ship turns
- sail near an NPC route and press `Enter` when the intercept prompt appears
- confirm the battle target matches the intercepted NPC's faction and ship type
- sink the target and confirm the game returns to the overworld

For direct battle testing:

Open [game/scenes/NavalBattle.tscn](../game/scenes/NavalBattle.tscn), run the game, and try:

- fire port broadside at long range
- fire starboard broadside at long range
- compare reload timing between sides
- select grape or fire shot and verify you need to get much closer
- use fire shot and watch for burning on either ship
- swap the target ship type in YAML and confirm the debug UI, target size, hull durability, and explosion feel change
- compare small ships and large ships for slower speed, heavier turning, and longer time-to-sink
- disable target `movement_enabled` to test cannon behavior against a stationary target
- use chain shot until sail health reaches zero and confirm the mast breaks
- use grape shot and confirm lower crew reduces enemy firing capacity
- change `crew` in player or target ship YAML and confirm the debug crew percentage and cannon limit update
- confirm the opening gives the player several seconds to orient before the enemy can fire
- sail alongside the enemy at matching speed and confirm the boarding prompt appears, then press `F` to cross swords
- confirm the battle HUD hides while the duel is on screen and returns afterwards

If behavior changes because of YAML edits, run content validation before opening the editor.

For primitive port testing:

- sail near Port Royal until the nearest-action line reads `Port Royal - Press Enter`
- press `Enter` and confirm the port menu opens
- sell cargo, then spend the purse on repairs or crew
- open Manage Fleet from the port, return, then open Manage Fleet from the overworld with `M`
