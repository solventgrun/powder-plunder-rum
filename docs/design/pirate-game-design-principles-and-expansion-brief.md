# Pirate Game Design Principles and Expansion Brief

## Project Intent

This project is a small, personal retro-style pirate adventure game inspired by the compact, interconnected-minigame structure of *Sid Meier's Pirates!*.

The goal is not to create a realistic naval simulator or a modern open-world game.

The goal is to create something that feels like:

> A colorful, campy, early-2000s pirate game with modern systems underneath it.

The intended audience is initially the developers, family, and close friends.

This should remain fun to build, easy to experiment with, and comfortable with being deliberately retro.

## Core Design Philosophy

### 1. Distinct Minigames, Continuous Consequences

The game does not need one unified combat simulation.

It is acceptable, and preferred, for sailing, harbor combat, land combat, dueling, treasure hunting, and other activities to exist as separate gameplay modes or minigames.

What matters is that the results of one mode affect the next.

```text
OVERWORLD
    -> Harbor circumstances determined
    -> HARBOR BATTLE
    -> Fort and enemy fleet damaged
    -> LAND BATTLE
    -> Town captured
    -> Faction / economy / reputation changes
    -> OVERWORLD
```

The individual minigames may remain mechanically simple.

The strategic depth should come from how their consequences connect.

### 2. The Overworld Determines Combat Circumstances

Enemy ships should generally exist in the world before combat rather than appearing only because a battle begins.

For example, if the player attacks Havana while several Spanish ships are currently in or near the harbor, those ships should participate in the harbor defense.

If the harbor is empty, the attack should be easier.

This means when the player attacks matters.

```text
Monday:
Spanish frigate arrives.

Tuesday:
Merchant convoy arrives.

Wednesday:
Treasure fleet departs with frigate escort.

Thursday:
Harbor defenses remain, but naval presence is weak.
```

The player may deliberately wait for Thursday to attack.

This turns reconnaissance, observation, rumors, ship movements, and timing into useful strategic tools.

### 3. Information Should Be Valuable

Information gained from the world should often help the player make decisions.

Sources may eventually include:

- tavern rumors
- governors
- merchants
- captured sailors
- friendly captains
- visible ship traffic
- faction intelligence
- maps
- observation from the overworld

Example rumor:

> A powerful Spanish squadron is expected to arrive at Havana within the fortnight.

This should not merely be flavor text.

It could warn the player that attacking now may be easier than attacking later.

Another rumor might reveal:

- a fort is damaged
- a treasure fleet is departing
- a town is poorly defended
- a governor is offering rewards
- a rival captain was recently seen nearby

The player's knowledge of the simulated world should become a meaningful strategic advantage.

### 4. Harbor Assaults Should Be Their Own Battle

Major towns may require a harbor assault before a city can be taken from the sea.

The harbor battle could include:

- player's ship or fleet
- coastal fortifications
- fort artillery
- enemy ships currently present
- potentially ships arriving during the battle

Example pre-battle state:

```yaml
attack: havana
fort:
  name: El Morro
  guns: 24
  defenders: 320
ships_in_harbor:
  - Spanish Frigate
  - Galleon
  - Merchantman
player:
  ship: Brig
  guns: 18
  crew: 110
```

The player can then choose to attack or withdraw.

### 5. Enemy Reinforcements Can Arrive

If an enemy warship is physically nearby in the overworld when a harbor battle begins, it may arrive during the fight.

Example:

The player waits for a Spanish frigate to leave Havana.

The player attacks the fort.

Several minutes into the battle:

> SAIL SIGHTED!

The frigate returns and enters the combat area.

The player must now decide whether to:

- continue bombarding the fort
- engage the frigate
- attempt to disengage
- withdraw entirely

This creates emergent situations using relatively simple simulation rules.

### 6. Harbor Battles Feed Into Land Battles

A harbor battle should produce structured results that the land battle can consume.

Conceptually:

```yaml
harbor_battle_result:
  fort:
    structure_remaining: 0.42
    guns_remaining: 7
    defenders_remaining: 184
  enemy_ships:
    destroyed: 1
    captured: 1
    escaped: 0
  player:
    crew_remaining: 96
    hull_damage: 0.34
  landing_available: true
```

These values do not represent a final schema.

They show the intended relationship between game modes.

After a successful bombardment, the land attack might therefore begin with:

- Fortification strength: 42%
- Defenders: 184
- Operational fort guns: 7

If the player instead lands elsewhere and attacks overland, the fort may remain at full strength.

### 7. Multiple Ways to Attack a Town

Eventually, major settlements should support more than one broad approach.

#### Naval Approach

```text
Approach harbor
    -> Fight ships and coastal defenses
    -> Bombard fort
    -> Land crew
    -> Ground assault
```

Advantages:

- naval guns can weaken defenses
- ships may directly support the attack
- potentially faster

Disadvantages:

- fort guns can be extremely dangerous
- enemy warships may be present
- player ship may suffer serious damage

#### Overland Approach

```text
Land outside harbor
    -> Move toward town
    -> Fight defenders
    -> Use field artillery if available
    -> Assault fort / town
```

Advantages:

- avoids harbor batteries initially
- may bypass enemy ships
- allows different tactical approaches

Disadvantages:

- fort may remain fully intact
- troops must move over terrain
- artillery can slow the force

Neither approach should always be superior.

### 8. Cannons Must Exist on Land

A key design goal is avoiding the arbitrary separation found in some older pirate games where artillery effectively stops existing when the player goes ashore.

If the player owns or transports cannons, those cannons should potentially be useful on land.

Possible future artillery properties:

```yaml
id: bronze_12_pounder
name: Bronze 12-Pounder
type: field_artillery
weight: 1800
crew_required: 8
damage:
  personnel: 45
  fortification: 120
range: 400
reload_time: 14
mobility:
  road: moderate
  field: slow
  jungle: terrible
```

The values above are illustrative only.

The important design principle is:

> Artillery use should be limited by tradeoffs, not arbitrary mode restrictions.

For example, bringing six guns might require substantial crew and dramatically slow an army.

### 9. Artillery Should Create Decisions

Field guns should not simply be an automatic upgrade.

Potential tradeoffs include:

- heavy weight
- crew requirements
- slow movement
- difficulty through rough terrain
- ammunition
- vulnerability while repositioning
- cargo capacity aboard ships

After defeating an enemy army, the player may eventually have choices such as:

- capture enemy artillery
- destroy it
- abandon it
- transport it aboard ship
- use it in the next attack

The game should favor meaningful tradeoffs over invisible restrictions.

### 10. Naval and Land Equipment Can Interact

Long-term, captured equipment should ideally have persistent value.

Examples:

- captured cannons may become usable equipment
- captured ships may become usable ships
- captured supplies may support troops
- naval bombardment may reduce land defenses
- land victories may disable coastal batteries

Game systems do not need to be physically unified, but their state should logically interact.

### 11. Port Defenses Should Matter

Large, wealthy cities should feel substantially more dangerous than small settlements.

Potential defenses include:

- coastal forts
- heavy artillery
- garrisons
- patrol ships
- nearby naval squadrons
- walls
- militia

This creates progression naturally.

A small sloop may be excellent for:

- piracy
- scouting
- escaping larger ships
- attacking lightly defended settlements

It should probably not be capable of casually defeating a major fortified city.

The game should occasionally communicate:

> Attacking this place in this ship is an extremely poor decision.

The player is still free to try.

### 12. Ship Characteristics Should Matter Beyond Direct Combat

Different ships should influence strategic options.

Example:

A fast sloop may have:

- poor firepower
- low crew capacity
- high speed
- excellent disengagement capability

A galleon may have:

- enormous firepower
- strong hull
- large crew
- poor maneuverability
- difficulty escaping dangerous situations

This means choosing a ship affects not only who the player can defeat but also:

- where they can safely operate
- whether they can escape
- how much cargo they can carry
- how many troops and guns they can transport

### 13. World Simulation Should Produce Stories

The long-term world simulation should generate circumstances rather than scripted stories alone.

Example:

```text
Spain declares war on England
        -> Spanish naval activity increases
        -> English merchants alter routes
        -> Pirate opportunities increase
        -> Player sees consequences in the world
```

The world does not need an enormously detailed simulation.

A lightweight simulation at the level of:

- ports
- factions
- ships
- captains
- trade routes
- war state
- economic state

may be enough.

The player should frequently encounter situations that were not explicitly scripted.

### 14. NPC Ships Should Be Persistent Enough to Matter

Where practical, important ships should represent actual entities moving through the world.

For example:

```yaml
ship: Spanish Frigate San Marcos
current_mission: Escort treasure convoy
route:
  - Havana
  - Veracruz
  - Havana
```

If the player sees San Marcos leave Havana, that matters.

If the player later encounters it escorting a convoy, it should ideally be the same ship.

This persistence can remain lightweight.

The goal is simply to prevent the world from feeling as though ships exist only when the player looks at them.

### 15. Persistent Captains and Rivals

Important NPC captains may eventually persist across encounters.

Example:

```yaml
name: Esteban de Cordoba
faction: spain
ship: san_marcos
victories: 14
defeats: 2
relationship_with_player: rival
```

Possible outcomes:

- player defeats him
- he escapes
- he later returns with a stronger ship
- he captures one of the player's allies
- he becomes involved in a faction war
- he eventually dies or retires

This can create memorable campaign stories without requiring elaborate scripted narratives.

### 16. Keep Individual Mechanics Simple

The game should avoid unnecessary simulation complexity.

Naval combat should primarily revolve around readable concepts such as:

- wind
- position
- range
- firing angle
- ship speed
- ammunition
- maneuverability

Possible ammunition types:

```text
Round shot -> hull / fortifications
Chain shot -> sails / rigging
Grape shot -> crew / exposed personnel
```

Additional ammunition types may be added later, but simplicity should remain a goal.

### 17. Retro Feel Is Intentional

The visual target remains deliberately retro.

The eventual game should resemble an unusually polished game from approximately the early 2000s rather than a modern realistic production.

Possible characteristics:

- primitive / low-poly geometry
- simple models
- bold silhouettes
- colorful Caribbean environments
- painted or stylized textures
- illustrated UI
- exaggerated characters
- simple animation
- modern resolution
- tasteful modern lighting and effects

The project should not chase photorealism.

### 18. Prototype Graphics Can Be Extremely Primitive

The first sailing prototype does not need production art.

Acceptable visuals include:

```text
Blue plane
+
Capsule representing ship
+
Wind arrow
```

That is sufficient.

The first milestone exists only to determine whether sailing can feel enjoyable.

No art work should block the initial prototype.

### 19. Data-Driven Content Architecture

Content should eventually be defined primarily outside gameplay code.

Expected content categories include:

```text
data/
|-- ships/
|-- weapons/
|-- artillery/
|-- quests/
|-- ports/
|-- factions/
|-- captains/
`-- goods/
```

YAML is the intended human-editable content format.

Example ship:

```yaml
id: sea_dragon
name: The Sea Dragon
type: frigate
speed: 14
turning: 9
cannons: 42
crew: 180
```

Example artillery:

```yaml
id: bronze_12_pounder
name: Bronze 12-Pounder
crew_required: 8
weight: 1800
damage:
  personnel: 45
  fortification: 120
```

Example port:

```yaml
id: havana
name: Havana
faction: spain
defenses:
  fort: el_morro
  garrison: 320
economy:
  prosperity: high
```

These examples are conceptual rather than fixed schemas.

The principle is:

> Content lives in data. Reusable behavior lives in code.

### 20. Do Not Build the Full Content Engine Yet

The YAML-based system is a planned architectural direction.

Do not allow it to delay the sailing prototype.

The immediate priority remains:

```text
MILESTONE 0
MAKE THE LITTLE BOAT SAIL
```

Once the movement prototype is enjoyable, content systems can be implemented incrementally.

## Early Development Roadmap

### Milestone 0 - Little Boat Sail

Create the basic sailing prototype.

Required:

- blue ocean / background
- primitive player ship
- wind direction
- steering
- acceleration
- wind-relative sailing efficiency
- basic camera
- debug information

Success condition:

Moving the primitive boat around is enjoyable enough to continue.

### Milestone 1 - CANNON GO BOOM

Add the simplest possible naval weapon system.

Potential scope:

- broadside firing
- projectile
- hit detection
- basic damage
- satisfying visual/audio feedback
- second primitive ship as target

Success condition:

Shooting another primitive boat is fun.

Polish is secondary.

The cannon should go boom.

### Milestone 2 - Boat Fight

Introduce basic naval combat.

Required systems:

- single enemy ship
- same wind-relative sailing rules for player and enemy
- enemy maneuvering
- enemy broadside firing
- hull health
- sail damage reducing speed
- mast breaking when sails are destroyed
- crew damage reducing active cannon capacity
- cannon reload
- sinking
- player-sunk notice
- enemy-sunk placeholder victory notice

Deferred from this milestone:

- surrender
- boarding
- capture
- post-battle rewards
- multiple ships

### Milestone 3 - Overworld Encounter

Create a very small strategic map or world layer where ships exist outside combat.

The player can:

- move around
- observe NPC ships
- intercept one
- enter naval battle

### Milestone 4 - Primitive Port

**Built 2026-08-17.** Architecture: [ADR 0017](../decisions/0017-primitive-port-and-fleet-management.md). Port Royal is now reachable from the overworld when close enough, and presents separate screens for selling cargo, buying provisions, repairing ships, hiring crew, managing the fleet, and leaving port. Fleet management is shared with the overworld via `M`.

Create one port with minimal interaction.

Possible options:

- sell cargo
- repair ship
- hire crew
- leave port

No production-quality town art required.

### Milestone 5 - Harbor Fort

Create the first port-defense battle.

Required concepts:

- fort
- fort guns
- player ship
- fort damage
- player withdrawal

This establishes the basis for attacking towns.

### Milestone 6 - Harbor Ships

Ships currently associated with a port may participate in its defense.

This begins implementing the strategic timing system.

### Milestone 7 - Land Battle Prototype

Create a separate primitive land-combat minigame.

Do not attempt to seamlessly integrate it with naval combat.

### Milestone 8 - CANNON GO BOOM ON LAND

Add field artillery.

Success condition:

Player can bring a cannon into a land battle and use it against enemy troops or fortifications.

### Milestone 9 - Harbor-to-Land State Transfer

Harbor battle results affect the subsequent land battle.

Examples:

- damaged walls
- reduced garrison
- destroyed fort guns
- surviving player crew

This milestone establishes the "distinct minigames, continuous consequences" architecture.

### Future Milestone - Advanced Naval Combat

Expand boat fights beyond the single-ship duel.

Possible systems:

- multiple enemy ships
- allied ships
- boarding
- capture
- prize crews
- loot / rewards
- surrendered vessels
- more advanced enemy tactics
- battle result payloads for future overworld integration

### Backlog Additions (2026-08-16)

Added after the fleet visual pass (all four ship classes now sail Blender-built meshes). These are menu items like the milestones above, with one sequencing rule the user set: **boarding comes before post-battle consequences**, because together they complete the naval battle sequence — battle → boarding → duel → consequences.

That sequence is now closed: both are built (2026-08-17). The naval loop runs end to end — sail, fight, board, duel, decide what comes home, sail on carrying it.

#### Boarding Duel — CROSS SWORDS

**Built 2026-08-17.** Design record: [Boarding & Sword Duel Brief](boarding-duel-brief.md); architecture: [ADR 0011](../decisions/0011-context-free-duel-system.md). What shipped differs from the sketch below in ways the user decided during the build:

- **3D deck arena, not a 2D minigame** — the reference is the *Pirates!* (2004) deck duel, so the fight is staged on a plank deck with chunky procedural fighters.
- **Vigor pools**, not an advantage bar.
- **Attacks left, evasions centre** on the numpad, each attack answered by exactly one evasion (`7` chop ← `2` duck, `4` thrust ← `5` parry, `1` slash ← `8` jump — evasions sit where your body goes, jump up top and duck at the bottom; the mirrored arrangement was played and rejected on feel); taunt on `6`, a one-shot pistol on `9`, slot `3` reserved.
- **Weapon choice per fight** (cutlass / longsword / broadsword) trading speed against weight.
- **Boarding is offered whenever alongside** — softening the crew scales the captain you meet rather than unlocking the prompt.
- **Losing the duel loses the battle.**
- The duel is **context-free and reusable**: callers pass a context dictionary and receive a result, so tavern brawls and land duels need no changes inside `game/scripts/duel/`.

Original sketch, kept for the record:

A small, separate 2D minigame (per the distinct-minigames principle): when boarding conditions are met in a naval battle, the player crosses swords with the opposing captain in a 2D duel controlled on the **number pad**.

Illustrative shape, not a fixed design:

```text
NUMPAD
7 8 9    high cut   advance   high parry
4 5 6    mid cut    feint     mid parry
1 2 3    low cut    retreat   low parry
```

Design hooks already in place:

- Crew and morale pools (ADR 0008) can gate when boarding is offered and scale the duel's stakes or difficulty.
- Grape shot finally gets its strategic purpose: soften the crew before you board.
- The duel outcome feeds post-battle consequences: win the duel and the ship strikes her colors (capture/plunder); lose and you are repelled (crew losses, the enemy fights on).

Keep the duel readable and campy — a few clean actions with clear tells, not a fighting-game engine.

#### Post-Battle Consequences

**Built 2026-08-17.** Architecture: [ADR 0016](../decisions/0016-post-battle-consequences-cargo-and-the-player-fleet.md). What shipped is larger than the sketch below, because the user's answers during scoping turned "post-battle rewards" into "the player has a fleet":

- **A fleet, not a ship.** `GameSession` owns an array of ships; `player_ship.yaml` is the starting fleet rather than the permanent truth. Take a prize as a consort, or shift your flag to her. The long-term intent is starting in a sloop and working up.
- **Damage persists fully, with no free repair** (user call). The counterplay is the fleet itself: a battered ship is mended by taking a fresh one. Naval stores jury-rig at sea, medicine returns wounded to duty, rum holds a crew together.
- **Twelve cargo types in three roles** — plunder / powder / rum, named for the game. Value per ton spreads ~60× and scarcity lives in the manifests, hand-authored where it matters and rolled from a `cargo_role` otherwise.
- **Cargo weighs against the same allowance as guns**, so the shipped frigate (220 tons of gun, 220-ton hull) cannot carry plunder until guns go over the side.
- **Morale finally bites** — gunnery, surrender, desertion, and boarding strength — tuned from a new `morale:` difficulty section. Rum lifts it and makes the crew drunk; drunkenness persists per ship.
- **An after-action screen** decides what comes home: cargo, her guns, her crew, and her fate. UX correction, 2026-08-17: the adjustable post-battle choices use sliders with live selected/available readouts.

Original entry, kept for the record: *Winning a battle currently just returns to the overworld. Add the first real "continuous consequences" payload: a post-battle result screen (gold, cargo, crew losses, prize decisions once boarding exists), and persistence — a sunk or captured NPC ship should not simply respawn on its route. Feeds directly into the Primitive Port milestone's economy (repair costs, selling plunder).*

Deliberately deferred out of this pass: escorting prizes to port for sale (needs Milestone 4), consorts fighting alongside you (that is Multi-Ship Battle Readiness), asymmetric refits (want a port to do them in), and ammunition consumption (below).

#### Specie and Payroll Loot (added 2026-08-17, user directive)

Current treasure cargo sells too small for the fantasy and historical frame: the authored Spanish treasure galleon is rich as cargo, but a full sale is still only a low-thousands purse event. Treasure fleets and military payroll vessels need a second loot channel: **coin / plate / specie** that goes directly to the purse and does not occupy hold space once captured.

Design distinction:

- **Weighted treasure cargo** (`gold`, `luxury_goods`, spices, etc.) is the hold decision. It asks what the player can physically carry to port.
- **Specie / payroll loot** is the jackpot. It represents chests of coin, plate, pay, and account-cleared wealth that makes a named treasure ship or payroll vessel feel materially different from an ordinary trader.

Likely data shape: add an optional purse-value field to authored encounter loadouts, e.g. `specie_value` or `payroll_value`, and surface it at the after-action screen beside cargo. Treasure galleons might sit in the **3000-8000** purse range, military payroll ships around **2000-6000**, and ordinary traders at zero or token amounts. Keep this hand-authored where it matters; role-generated cargo should not automatically mint jackpot money.

This amends the ADR 0016 "gold as a session counter" rejection: weightless money is still wrong as ordinary cargo because it would erase the hold decision, but explicit treasure/payroll specie is a separate reward layer for ships whose identity is "floating treasury."

#### Ammunition as Cargo (added 2026-08-17)

`gunpowder` and `round_shot` exist as cargo types and are currently valuable-but-inert: they sell, they weigh, they do nothing. Spending them when the guns fire turns a raid into a resupply run and gives grape and chain a real opportunity cost. Held back deliberately so the fleet playtest is not also an ammunition-scarcity playtest — it rebalances every naval engagement and deserves its own.

#### Prisoners and Ransom (added 2026-08-17, user directive)

Captured officers, passengers and crew as a kind of cargo that argues with itself: worth a great deal ransomed, but they eat provisions and take hands to guard. Pairs with the after-action screen, which already asks what a hold will carry, and with the persistent-captains idea (principle 15) — ransoming a rival back is a story the simulation writes itself.

This is also where the game decides how it handles the period's human trafficking, which is a deliberate authorial choice rather than a systems one. Settle that with the user before building anything.

#### Captured, Not Finished (added 2026-08-17, user directive)

Being captured should not always be an immediate campaign-over screen, but it also should not become a soft failure state. This is a pirate game: pirates who are caught by lawful powers are often hanged. The world needs enough legal identity to decide whether the player is executed, ransomed, exchanged, imprisoned, or given one desperate chance to escape.

Core design rule:

> Rank can protect a pirate from law. Notoriety can burn that protection away.

The capture outcome should eventually depend on:

- **who captured the player** — lawful navy, town governor, pirate crew, rival captain, militia, or another authority
- **the player's standing with that captor** — rank, title, commission, citizenship, or protection from the captor or its enemies
- **stored wealth and estates** — whether the player is worth ransoming and whether they can pay their own ransom
- **war state** — a ranked enemy might be exchanged, ransomed, or held until hostilities end
- **notoriety with that faction** — atrocities and betrayals that make the captor prefer execution even when ransom would otherwise make sense
- **captor personality and policy** — a greedy governor, proud admiral, vengeful rival, or drunken pirate should not all judge the same case identically

This feature highlights several world systems that should be backlog items in their own right:

- **Faction Rank and Titles** — formal standing with Spain, England, France, the Dutch, pirate factions, and eventually the Republic of Rum as a real state/faction.
- **Letters of Marque / Legal Piracy** — whether the player's violence is treated as piracy, privateering, or wartime service.
- **Faction-Specific Notoriety** — separate from fame or reputation; this measures whether a faction wants the player punished personally. Executing captured sailors, sinking surrendered or disabled ships, torturing town leaders for treasure information, brutal sacks, breaking parole, betraying commissions, and similar dark deeds should raise it sharply.
- **Bounties** — related to notoriety but not identical: the money a faction offers for the player's capture.
- **Stored Gold and Long-Term Wealth** — cargo gold is physical plunder with weight; stored gold is secured wealth used for ransom, bribes, crew shares, estates, retirement, and future investments.
- **Land and Estates** — long-term prestige and wealth that can influence ransom value, social rank, retirement scoring, and political protection.
- **Crew Plunder Division** — periodic division of plunder where the crew expects gold, not simply abstract cargo value.
- **War Prisoner Logic** — ranked captives may be held until peace, exchanged for other prisoners, or used as diplomatic leverage.
- **Execution Timers and Rescue** — if the verdict is hanging, the player may have a limited window for escape, bribery, ally intervention, or crew rescue.

Smallest MVP slice:

1. Track one simple player legal status (`pirate`, `protected`, `ranked`) and one `notoriety_by_faction` map.
2. Split gold into physical `cargo_gold` and secured `stored_gold`.
3. On player defeat, run a simple capture judgment:

```text
if notoriety_with_captor >= execution_threshold:
    sentenced_to_hang
elif player_is_ranked_or_protected:
    ransom_or_exchange
elif stored_gold >= ransom_price:
    pay_ransom_or_attempt_escape
else:
    sentenced_to_hang_or_attempt_escape
```

4. Build one short escape chain, not a full stealth mode. Success returns the player to the overworld in a ruined state. Failure can end the campaign.

Escape should be a compact procedural pirate-story generator made of cheap modules: a guard-routine timing challenge, a drunken-guard bluff, a context-free duel breakout, a rope descent, feigned death, a supply-wagon escape, or an optional crew-rescue risk. The first implementation only needs one or two modules to prove the loop.

#### Republic of Rum (added 2026-08-17, user idea)

Drunkenness is already tracked per ship and persists between battles, precisely so events can watch it. The Republic of Rum is the comic far end of that scale — a crew far enough gone to declare its own polity. Needs an event system first; the state it would fire on already exists.

#### World Clock, Provisions, and Rations (added 2026-08-17, user directive)

The game still lacks a real campaign clock. The brief already depends on timing — convoys arriving on days, treasure fleets departing, waiting for defenses to thin — and ports/post-battle persistence now make time a mechanical need rather than just a story idea.

Food is now modeled at the cargo level as `provisions`: it can appear in hostile holds, be taken on the post-battle loot screen like any other cargo, and be bought at Port Royal. What does not exist yet is the daily consumption pass. That should change with the clock:

- `GameSession` tracks a date/day counter and advances it from overworld sailing, waiting in port, repairs, and future travel/actions.
- Each ship consumes provisions per day based on crew aboard.
- Rum is controlled by a standing per-ship ration setting, not by the post-battle screen. Fleet management owns that policy; post-battle only reports what the battle did and what loot is taken.
- Higher rum rations should consume rum faster, lift or stabilize morale, increase drunkenness, and eventually create event hooks such as Republic of Rum.
- Low food should hit morale, health/crew, desertion, and surrender risk more sharply than low rum. Running out of both should feel like a genuine campaign problem, not a UI warning.

Smallest remaining MVP: add `day`/`date` to `GameSession`, tick provisions and rum consumption once per elapsed campaign day, and show projected days of food/rum in fleet management and port screens.

#### Player Captain and NPC Character System (added 2026-08-17, user directive)

The game needs a visible character representation for the player captain, and the same system should eventually support NPC captains, governors, duel opponents, tavern characters, and other named people. This should be a modular Blender-to-Godot character kit, not a one-off player model, because the same representation must later appear in character creation, dialogue, wanted/ransom screens, sword fights, capture/escape scenes, rank rewards, and NPC records.

Tone target: period-inspired pirate adventure, not strict reenactment. The art should support broad expressive variety while staying readable and deliberately retro beside the ships.

Visual references:

- European male pirate briefing image: [european-male-pirate-concept.jpg](reference-images/european-male-pirate-concept.jpg) (user-supplied 2026-08-17, replacing the earlier shared-chat URL `https://chatgpt.com/s/m_6a839d40940881918842f53609546f92`). Treat this as the starting visual direction for the European male head/body presentation, not as a hard limit on the broader modular character system.
- African male pirate briefing image: [african-male-pirate-concept.jpg](reference-images/african-male-pirate-concept.jpg) (user-supplied 2026-08-17). Treat this as the starting visual direction for the African male head/body presentation, sharing the same base-adventurer clothing language while proving the character kit can support distinct head, skin, and hair reads.
- European female pirate briefing image: [european-female-pirate-concept.jpg](reference-images/european-female-pirate-concept.jpg) (user-supplied 2026-08-17). Treat this as the starting visual direction for the European female head/body presentation, keeping the same practical base-adventurer kit while proving the character system supports a distinct female silhouette.
- African female pirate briefing image: [african-female-pirate-concept.jpg](reference-images/african-female-pirate-concept.jpg) (user-supplied 2026-08-17). Treat this as the starting visual direction for the African female head/body presentation, keeping the shared starter-gear language while proving the kit can support braids, distinct facial structure, and a female silhouette.

European male visual notes from the reference: young base adventurer around age 22, heroic but still plain; loose off-white shirt, dark worn vest/jacket layer, brown trousers, wide belt and cross-strap, tall folded boots, curved sword and flintlock pistol. Hair is dark, medium-length, wavy, and loose. Face reads charming, quick-witted, determined, and not yet legendary. Palette is restrained and practical: linen, tan leather, mid/dark browns, near-black leather, and a muted dark red accent. The model should leave room for growth from "nobody" to decorated captain.

African male visual notes from the reference: same young base-adventurer premise and starter gear silhouette as the European version, with a darker skin-tone range, short tight curls, strong cheekbones/jaw, and a composed, determined expression. Clothing remains plain and functional: loose off-white shirt, worn dark vest/jacket layer, brown trousers, layered belts/cross-strap, tall folded boots, curved sword, and flintlock pistol. Palette stays practical and earth-toned so upgrades, rank decorations, and richer clothing can visibly carry progression later.

European female visual notes from the reference: young base adventurer around age 22, charismatic and determined, with a capable fighter/sailor silhouette rather than a decorative costume. Starter clothing mirrors the shared poor gear language: loose off-white shirt, dark worn vest/jacket layer, fitted brown trousers, wide belt, muted red sash, tall folded boots, curved sword, and flintlock pistol. Hair is dark, wavy, and pulled back into a loose practical braid/pony-tail with flyaway strands. Palette remains linen, leather browns, near-black, and muted red so later earned clothing and rank pieces can read clearly.

African female visual notes from the reference: young base adventurer around age 22 with a serious, capable fighter/sailor presence. Starter clothing follows the shared poor gear silhouette: loose off-white shirt, dark worn vest/jacket layer, fitted brown trousers, wide belt, muted red sash, tall folded boots, curved sword, and flintlock pistol. Hair is dark, tightly braided, and pulled back into long practical braids, with small bead/detail accents that should remain readable but not ornate at the starting tier. Palette stays linen, leather browns, near-black, and muted red; the face and skin-tone range should read distinctly from the African male version while staying in the same modular kit family.

Long-term system:

- Character records are data-driven and usable for both the player and NPCs.
- Heads, bodies, hair, clothing, weapons, accessories, and decorations are separate swappable parts.
- Heads and bodies are independent: any supported head can be matched with any supported body.
- MVP ancestry/appearance bases are **African-looking** and **European-looking** heads, with male and female versions for each head family.
- MVP body builds include at least a heroic/muscular build and a fat build, with male and female support.
- Clothing should fit all supported bodies. If the implementation uses body-specific meshes, they still share the same slot ids and are selected by the character system rather than by hand-authored scene branching.
- Skin tone, eye color, hair color, and clothing colors use constrained palettes rather than unconstrained color pickers, keeping the art directed and easier to validate.
- Hair is a swappable mesh, with hair color tint applied separately.
- Aging is not MVP because it needs a world clock/calendar first, but the model/material contract should allow wrinkles, grey hair, and scars later.
- Rank and progression decorations are cosmetic items in the clothing/accessory system, but because they are earned from factions and accomplishments they will naturally carry meaning in other systems. Armor is visual at first but should be able to gain battle effects later.

Initial supported slots should include:

```text
head
body
hair
shirt
jacket
pants
boots
sash_or_belt
face_accessory
sword
gun
armor
rank_decoration
```

Character creation MVP:

- Choose sex/presentation: male or female.
- Choose head family: African-looking or European-looking.
- Choose body build: heroic/muscular or fat.
- Choose one of two hairstyles available for the chosen setup.
- Choose skin tone from a constrained palette.
- Choose eye color from a constrained palette.
- Choose hair color from a constrained palette.
- Clothing is not freely chosen at creation: every player starts in poor, basic clothing. Better clothing, weapons, armor, eye patches, sashes, medals, and rank decorations are earned in play.

Pipeline MVP:

1. Build a Blender character kit with a shared rig/contract, named slots, and attachment points.
2. Export enough parts to prove interchangeability: four heads (African-looking male/female, European-looking male/female), male and female bodies in heroic/muscular and fat builds, two hairstyle meshes per supported setup, poor default clothing, and at least one alternate item for each core clothing slot.
3. Implement a Godot character assembler/preview scene that reads a character record and builds the model from modular parts.
4. Support both hand-authored NPC records and generated NPC records from the same schema.
5. Prove the system outside the duel first in a character creation or inspection scene. Replacing the current chunky procedural duel fighters comes later, after the character kit is stable.

Acceptance bar for the first playable slice: create or load a character record, swap head/body/hair, apply skin/eye/hair palette choices, equip poor default clothing, swap at least one alternate shirt/jacket/pants/boots item through a debug or preview control, and render both a player captain and at least one NPC from the same system.

#### Audio Pass

The game is currently near-silent (one placeholder cannon boom). For "share-ready" this is the largest missing pillar: ambient sea/wind/gulls, cannon fire with variation and distance falloff, impacts, splashes, sail-trim flap, UI clicks, and possibly a light shanty-style music bed. Needs a sourcing decision (procedural vs CC0 vs licensed) with the user per the asset-exception precedent (Cinzel font, ship models). Best sequenced once the full battle loop (including boarding) exists to be scored.

#### Save / Load

Unplanned until now; becomes necessary the moment ports and post-battle persistence create state worth keeping. Design it alongside the Primitive Port milestone rather than bolting it on after. Likely shape: serialize the YAML-derived session state (player ship, cargo, gold, NPC ship states, world clock) — keep it human-readable in the data-driven spirit.

#### Multi-Ship Battle Readiness

Pulled forward from the Advanced Naval Combat bucket now that four distinct classes exist: support 2-v-1 encounters (an escort joining its convoy, a patrol pair) before full fleet battles. Requires target selection/indicators for multiple hostiles, AI that doesn't collide with its ally, and encounter data that can spawn more than one ship. The fleet meshes make this the cheapest way to cash in the visual investment.

#### Improved Cannon Mechanics — Galleon Double Broadside

The galleon is the only ship in the game with two levels of guns, and its broadside should say so. Firing-pattern rule (user directive, 2026-08-16):

- A side with **more than 12 guns** treats gun 13 and up as the second gun deck: each additional cannon pairs with a first-row cannon and fires a **small delay after it**, so the volley visually reads as two rows of shot, the second row growing with gun count until the cap is reached.
- At a full loadout the pattern is **heavier in the middle** — two rows of shots landing nearly back-to-back, center-weighted — making the galleon the premier heavy gun platform.
- The **frigate stays a solid single line of shot** — its broadside identity is the clean rolling rank, not the double wall. Class contrast is the point: the pattern should identify the ship before the silhouette does.

Implementation home is `BroadsideController` (volley timing and muzzle positions are already per-side and count-aware); the rule should key off per-side carried gun count, not ship id, so any future two-decker inherits it.

#### Faction Livery Kits (added 2026-08-17; Phase 1 closed 2026-08-17)

**Built 2026-08-17.** Phase 1 is complete: fleet-wide faction palettes now live in `data/visuals/faction_liveries.yaml`, `ShipVisualBuilder.LIVERY_MATERIAL_ROLES` maps the GLB material slots to livery roles, runtime recolor covers paint / accent / hull wood / trim / streamer / sails, pirates have their own rougher palette, and `tools/_LiveryProbe.tscn` runs the flags-off recognition lineup.

**Goal (user directive):** every faction gets its own separate visual identity so you can tell *who* you're engaging from the vessel itself at combat distance — not only from the flag. Class stays readable from silhouette; faction reads from livery.

What already exists is mechanism, not the goal: `ship-asset-pipeline.md` reserves faction identity for **material-slot recolors + runtime sail tint + procedural flags** (explicitly never per-faction meshes), sketches `faction_recolor: ["HullPaint", "Trim"]` in the visual-profile format, carries a "Faction distinction" review criterion, and milestone M7 holds a slot for proving the recolor axis. None of that states the requirement above — this entry does.

**Design tension to resolve first:** today paint encodes *class*, not faction — each class brief deliberately assigned it a hull scheme (galleon burgundy+gold, frigate near-black+navy+gold, brig tarred brown+buff, sloop per its brief). A livery pass reassigns paint to faction and leaves class identity to silhouette alone; the current per-class palettes become the neutral/unaffiliated default (or one faction inherits them). Decide this with the user before building palettes.

**Likely shape (data-driven, no model work per ADR 0010):** a per-faction livery kit = hull-paint + trim/accent palette applied to the GLB material slots by `ShipVisualBuilder`, plus the existing runtime sail tint and streamer color. Palettes live in `data/visuals/` beside `flags.yaml` so factions stay moddable in the data-driven spirit. Readability bar: name the faction at gameplay camera distance *before* the flag is legible; verify per the pipeline doc's "Faction distinction" criterion, one probe screenshot per faction per class.

Pairs naturally with Multi-Ship Battle Readiness — knowing who is who matters most when several vessels share the screen.

**Accepted framework (2026-08-17):** `docs/design/faction-visual-kit-proposal.md` — the five-layer kit structure (palette / stern / bow / deck dressing / sail treatment), per-nation visual languages, the flags-off recognition test, and this repo's phasing (palettes first at runtime, geometry via generator parameters only where recognition fails).

Closed scope: the palette/sail/streamer version of faction identity is done. Remaining work is split into separate backlog items below.

#### Faction Visual Kits — Phase 2 Geometry (added 2026-08-17; closed 2026-08-18 after playtest)

**Built and playtested 2026-08-18.** Follow-up to the closed Phase 1 livery pass is complete for the pairings that needed more than palette: French frigate and Dutch brig. Geometry stays bake-time through the deterministic Blender generators, with Godot selecting faction-specific scene overrides from `ship_visual_profiles.yaml`; runtime still owns color/livery application.

What shipped:

- France gets the bespoke `frigate_france.glb` / `FrenchFrigateVisual.tscn` kit: elegant rails, refined stern treatment, lanterns, blue/ivory grace notes, and a sea-nymph figurehead designed for gameplay-distance readability rather than close-up sculpture.
- The Dutch get the bespoke `brig_dutch.glb` / `DutchBrigVisual.tscn` kit: broader practical work rails plus deck cargo and commerce dressing (barrels, crates, nets, loading beams, lashings) without changing the hull dimensions.
- Spain and England remain palette-led for now; the flags-off read held well enough that adding geometry would be extra asset complexity without a proven readability gain.
- The architecture rule held: class controls silhouette, faction controls visual language, and the Godot runtime does not assemble ships out of loose geometry pieces.

Verification/playtest: `tools/_LiveryProbe.tscn` runs the flags-hidden recognition test, focused `--pilot-pairs` comparisons for French frigate vs standard and Dutch brig vs standard, and `--figurehead` distance ladder for the carved detail. User playtest signed off Phase 2; the livery backlog now moves on to the separate Pirate Conversion Visual Kit / Upgrade Visual Overlays / Expanded Visual Variants items rather than more national geometry.

For carved detail specifically (figureheads, stern ornament), run the probe's `--figurehead` mode: it shoots the same carving at 2.5 / 5 / 12 / 24 world units — the last being the real battle-camera distance from `NavalBattle.tscn` — and saves a `_pixels` crop beside each frame, magnified with nearest-neighbour so the review sees the actual pixels the player receives rather than a smoothed upscale that invents detail. Use it to decide which sculpt work survives the distance it has to survive, and stop refining below that threshold.

#### Pirate Conversion Visual Kit (added 2026-08-17)

Pirates should eventually read as captured and improvised rather than as a normal navy with a different paint job. The Phase 1 pirate palette gives them tarred timber, oxblood bands, blackened trim, blood-red streamers, and darker canvas; this follow-up adds the full conversion layer.

Desired read:

- patched or mismatched sails
- repainted-over hulls with exposed replacement planks
- scraped-off national markings and vandalized crests
- trophies, boarding gear, and rough repairs on deck
- jury-rigged lines and mismatched cannon carriages
- enough randomness that pirate vessels look individually stolen, not factory-issued

Important rule: pirate visuals modify another faction's ship rather than replacing it. A pirate Spanish galleon should still show Spanish bones under the pirate conversion.

#### Upgrade Visual Overlays (added 2026-08-17)

Gameplay upgrades that should be visible on the hull belong near the livery system, but should remain distinct from faction identity. Examples include copper bottoms, reinforced hull work, extra armor, or other visible ship modifications.

Preferred cost tiers:

1. Material-level overlays first, such as a copper-bottom shader below the waterline.
2. Hidden-by-default geometry in the GLB toggled at runtime if the upgrade needs actual shape.
3. Avoid runtime-composed loose geometry unless there is no cheaper readable option.

Composition rule: upgrades apply after livery and stay spatially distinct from faction cues. Waterline/deck details are good upgrade territory; bands, trim, sails, and streamers remain the main faction territory.

#### Expanded Visual Variants (added 2026-08-18, user directive)

`visual_variant` already rides on every ship record (player, target, overworld), but today it is a two-word vocabulary with one effect: the only consumer is `ShipVisualBuilder._variant_adjusted()`, where `worn` darkens the sail tint by 0.16 and `patrol` lightens it by 0.06. Nothing else reads it, no value is validated (a typo silently renders pristine), and `ShipLoadoutEditor` carries the field without offering to change it. It is the right hook in the right place — per-ship character, orthogonal to class and faction — and worth growing into a real system.

**Goal:** two ships of the same class *and* faction should be able to tell different stories at a glance. A crisp patrol frigate fresh off the ways and the same frigate three months into a cruise should read differently before either fires a gun.

Composition rule (extends the Upgrade Visual Overlays rule): class controls silhouette, faction controls livery, **variant controls this individual ship's condition and character**, upgrades apply after, and transient battle-damage states apply last. A variant must never break faction recognition — the flags-off probe still has to name the faction on the most weathered ship in the fleet.

Candidate vocabulary (illustrative, not a fixed list):

- `worn` (exists) — grow beyond sails: dulled paint, faded trim, darker canvas.
- `patrol` (exists) — the crisp naval counterpart; bright canvas, clean paint.
- `storm_beaten` — bleached sails, streaked hull, salt-scoured trim.
- `fresh_from_the_yard` — the flagship read: brighter gilt, saturated paint, pale new canvas.
- `long_cruise` — weed-darkened waterline, sun-faded upper works.
- `prize` — a captured ship still wearing the scars of the battle that took her; pairs with ADR 0016's full damage persistence, which already gives the fleet ships whose history should show.

**Likely shape (data-driven, no model work per ADR 0010):** promote the hardcoded ifs into `data/visuals/ship_variants.yaml`, one record per variant with per-role adjustments mirroring the livery roles (paint / accent / hull wood / trim / streamer / sails, each with darken/lighten/desaturate factors), so `_variant_adjusted()` becomes a lookup and variants stay moddable beside `faction_liveries.yaml` and `flags.yaml`. `ContentValidator` enumerates the variant ids so a typo fails loudly instead of no-opping. Cost tiers mirror the upgrade-overlay rule: (1) per-role color adjustment, (2) material parameters such as roughness for weathering, (3) geometry only where a variant read demonstrably fails without it.

Two cheap payoffs once the vocabulary exists:

- Role-generated overworld ships roll a variant, so traffic stops looking factory-issued. Complements the Pirate Conversion Kit without overlapping it — conversion is faction-level identity, variants are per-ship condition within any faction.
- A variant picker in `ShipLoadoutEditor` (or the practice menu) makes the set visible and testable for free.

## Guiding Question for Agents

When implementing a system, ask:

> Does this create an interesting decision for the player?

Prefer decisions over arbitrary restrictions.

Bad:

> You cannot bring cannons ashore.

Better:

> You can bring cannons ashore, but they require crew and dramatically slow your army.

Bad:

> Three enemy ships spawn when the player attacks Havana.

Better:

> Three enemy ships are currently at Havana, therefore they participate in the defense.

Bad:

> The fort disappears after the naval battle.

Better:

> Damage inflicted during the naval battle determines the fort's condition during the land battle.

## Scope Discipline

Despite the longer-term ideas above, agents should avoid implementing future systems prematurely.

Unless specifically instructed otherwise, the current immediate objective remains:

> Build small, testable pieces that can become a game incrementally.

The project should favor:

- playable prototypes
- simple architecture
- data-driven content
- reusable systems
- emergent interactions
- retro presentation
- programmer-friendly experimentation

over:

- elaborate abstractions
- production pipelines
- commercial polish
- massive upfront architecture
- realism for realism's sake

## Project Spirit

This is a hobby project.

It should remain enjoyable to work on.

Campiness is welcome.

Unnecessary realism is not.

Feature ideas may be added simply because they sound fun.

The roadmap is a menu, not a deadline.

And at least one major development milestone must always be recognized by its proper technical name:

> CANNON GO BOOM
