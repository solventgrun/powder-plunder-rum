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
3. The main scene is `res://game/scenes/Main.tscn`.

## Automated Smoke Test

From this folder, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_smoke_test.ps1
```

The smoke test loads the main scene headlessly, checks basic sailing-model assumptions, confirms the ship moves under wind, verifies YAML ship stats/modifications and loadouts, verifies broadside side behavior, checks ammo-switch cooldown, confirms missed shots despawn with splashes, and verifies impact flashes, burning, self-ignition, magazine explosions, sinking state, and target damage. If Godot is installed somewhere else, set `GODOT_BIN` to the Godot 4 console executable before running the script.

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

The boat accelerates based on wind direction, sail trim, and heading. Sailing into the wind is weak; crosswind and downwind sailing are stronger.

Changing ammo immediately puts both broadsides into reload cooldown, representing the crew shifting shot types.

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
