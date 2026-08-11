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
