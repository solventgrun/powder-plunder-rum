# Powder, Plunder & Rum

Fortune favors the reckless.

A retro-inspired pirate adventure built around sailing, naval combat, plunder, dynamic world simulation, and the questionable decision-making of heavily intoxicated sailors.

This is a tiny Godot prototype for a future retro-style pirate adventure game. The long-term direction is colorful, campy, mechanically readable pirate adventuring with an early-3D feel.

Placeholder geometry is intentional. The ship is primitive, the ocean is simple, and polish is out of scope until the game play feels worthy of it.

## Requirements

- Godot standard edition 4.x
- GDScript
- Git

No .NET runtime, C#, GDExtension, database, service, or external dependency is required.

## Running

1. Open this `pirates` folder in Godot.
2. Run the project.
3. The main scene is `res://game/scenes/Overworld.tscn`.

## Automated Smoke Test

From this folder, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_smoke_test.ps1
```

The smoke test loads the naval battle scene headlessly, checks basic sailing-model assumptions, confirms the ship moves under wind, verifies YAML ship stats/modifications and loadouts, verifies broadside side behavior, checks ammo-switch cooldown, confirms missed shots despawn with splashes, and verifies impact flashes, burning, self-ignition, magazine explosions, sinking state, and target damage. It also covers the boarding duel: the attack/evasion table, wrong-guess penalties, weapon speed, the one-shot pistol and how it is spoiled, the duel result contract, the overlay taking and returning the caller's paused world, when boarding is offered, and what winning or losing a boarding does to both ships. If Godot is installed somewhere else, set `GODOT_BIN` to the Godot 4 console executable before running the script.

To validate YAML content data without running the full smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_content_validation.ps1
```

Content validation fails on missing or invalid required fields. Unknown fields produce warnings so future-facing YAML can be added deliberately without crashing the prototype.

## Controls

- `A` / Left Arrow: steer port
- `D` / Right Arrow: steer starboard
- `W` / Up Arrow: trim sails in
- `S` / Down Arrow: ease sails out
- `Q`: fire port broadside
- `E`: fire starboard broadside
- `1`: select Round Shot
- `2`: select Chain Shot
- `3`: select Grape Shot
- `4`: select Fire Shot
- `Enter`: intercept a nearby overworld ship
- `F`: board the enemy when alongside
- `[` / `]`: decrease / increase wind strength
- `,` / `.`: rotate wind direction

Boarding crosses swords with the enemy captain in a sword duel, fought on the numpad (top-row number keys work too):

```text
7 CHOP     8 JUMP     9 PISTOL
4 THRUST   5 PARRY    6 TAUNT
1 SLASH    2 DUCK     3  --
```

Each attack has exactly one answer — a chop at the head is ducked, a thrust is parried, a slash at the legs is jumped. Evasions sit where your body goes: jump up top, duck at the bottom. Read the wind-up, pick the right one.

Your crews fight too. Their numbers run down live beside the captains' bars, and either side being wiped out ends the boarding on its own — so you can win by weight of numbers, or lose a duel you were winning because your boarders were overrun. Landing a blow costs their side men on the spot. Choose a cutlass, longsword, or broadsword at the start of the fight to trade speed against weight, and spend your single pistol shot whenever you judge best. Win and the ship strikes her colours; lose and you are cut down with her.

Boarding is always offered when you are alongside at matching speed. Softening the enemy crew first (grape shot) does not unlock it — it means you meet a weaker captain, and fewer men to cut through.

Ships also damage each other when they collide. Coming alongside gently is free, which is what boarding needs; driving into a hull at speed splinters timber on both ships, and the smaller vessel always comes off worse.

Enemies board too. A ship that means to take you stops keeping its distance and bears down — that is your warning, and you can still get your grapples over first. Once they are away, nobody breaks off.

The boat accelerates based on wind direction, sail trim, and heading. Sailing into the wind is weak; crosswind and downwind sailing are stronger.

The overworld currently starts near Jamaica with Port Royal marked as a simple town marker. NPC ships follow looping routes from `data/encounters/overworld_ships.yaml`; intercepting one loads `res://game/scenes/NavalBattle.tscn` with that NPC's ship record.

Changing ammo immediately puts both broadsides into reload cooldown, representing the crew shifting shot types.

Default battle wind is loaded from `data/environment/environment_conditions.yaml`. The wind keys are debug playtest overrides for quick tuning.

## Structure

- `game/scenes/`: playable scenes
- `game/scripts/`: ship, sailing, wind, camera, and UI scripts
- `game/systems/`: future reusable game systems
- `game/ui/`: future UI scenes and controls
- `data/`: future data-driven game content
- `assets/`: art, audio, models, textures, and temporary assets
- `tools/`: future development tooling
- `docs/`: design notes, decisions, and implementation records

## Project Reasoning

Important design and technical choices are tracked in [docs/decision-log.md](docs/decision-log.md). This is part of the project artifact: it explains why major choices were made, not just what the code currently does.

Prototype testing scenarios and commands are tracked in [docs/testing.md](docs/testing.md).

## Data-Driven Direction

Future content should live mostly in data files while reusable behavior stays in code. Ships, ports, factions, weapons, quests, and similar content are expected to move toward YAML-style definitions under `data/`.

Godot does not include first-class YAML support, so this prototype does not add a YAML dependency. A later milestone should choose between a small import/conversion tool that turns YAML into Godot resources or a minimal runtime parser if the benefits outweigh the dependency cost.
