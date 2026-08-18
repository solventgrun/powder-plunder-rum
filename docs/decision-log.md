# Decision Log

This project uses lightweight Architecture Decision Records (ADRs) to preserve important design, technical, and project-shaping choices.

The goal is not bureaucracy. The goal is to make the project understandable later, especially as it grows into portfolio material. Future readers should be able to see not only what was built, but why it was built that way.

## When to Add a Decision

Add or update an ADR when a choice:

- sets a precedent future work should follow
- chooses one implementation path over plausible alternatives
- affects project scope, architecture, tooling, data format, controls, or workflow
- captures reasoning that would otherwise live only in memory
- explains why something intentionally remains simple or deferred

Small code-level details do not need ADRs. Put those in code comments only when they clarify non-obvious behavior.

## Index

| ADR | Title | Status | Summary |
| --- | --- | --- | --- |
| [0001](decisions/0001-lightweight-godot-adr-workflow.md) | Lightweight Godot ADR Workflow | Accepted | Use Godot-native conventions plus short ADRs instead of a larger framework. |
| [0002](decisions/0002-yaml-cannon-content-validation.md) | YAML Cannon Content Validation | Accepted | Use narrow YAML content files with validation warnings/errors for cannon and ammo data. |
| [0003](decisions/0003-portfolio-grade-decision-log.md) | Portfolio-Grade Decision Log | Accepted | Treat ADRs and playtest notes as part of the project artifact, not just internal scratch notes. |
| [0004](decisions/0004-project-name-and-repository-slug.md) | Project Name and Repository Slug | Accepted | Use Powder, Plunder & Rum as the title and `powder-plunder-rum` as the GitHub repository slug. |
| [0005](decisions/0005-yaml-ship-broadside-loadouts.md) | YAML Ship Broadside Loadouts | Accepted | Define mixed port/starboard cannon loadouts in YAML with slowest-cannon side reload. |
| [0006](decisions/0006-ship-types-and-modifications.md) | Ship Types and Modifications | Accepted | Add YAML ship profiles and simple ship modifications for handling, hull, size, and risk tuning. |
| [0007](decisions/0007-fire-severity-and-magazine-explosions.md) | Fire Severity and Magazine Explosions | Accepted | Model fire as severity levels and add rare magazine explosions for hits and burning ships. |
| [0008](decisions/0008-sail-crew-and-morale-damage-foundations.md) | Sail, Crew, and Morale Damage Foundations | Accepted | Track non-hull damage pools now so Milestone 2 can attach movement, reload, and surrender consequences later. |
| [0009](decisions/0009-shared-ship-combat-component.md) | Shared Ship Combat Component | Accepted | Move ship damage/status state into a shared component so player and enemy ships use the same combat consequences. |
| [0010](decisions/0010-galleon-model-carried-sails-and-mesh-visuals.md) | Galleon Model-Carried Sails and Mesh-Mode Ship Visuals | Accepted | Model sails into the galleon GLB (superseding the pipeline's procedural-sail hybrid rule), keep flags procedural via anchor empties, and integrate through a `mode: mesh` ShipVisualBuilder profile. |
| [0011](decisions/0011-context-free-duel-system.md) | Context-Free Duel System and Boarding Handoff | Accepted | Split the sword duel into a context-free minigame (context in, result out, overlay not scene change) and a naval-only boarding layer, so tavern and land duels reuse it unchanged. |
| [0012](decisions/0012-game-wide-difficulty-levels.md) | Game-Wide Difficulty Levels | Accepted | One difficulty level chosen at new-game creation, with a data section per consuming system (duel today; naval, land, and overworld later) read through `GameDifficulty`. |
| [0013](decisions/0013-crew-melee-during-boarding.md) | Crew Melee During Boarding | Accepted | Crews fight alongside their captains as a context-free "supporting force" in the duel; either crew being wiped out decides the action, and casualties are what the melee actually cost. |
| [0014](decisions/0014-hull-collisions-and-ramming.md) | Hull Collisions and Ramming | Accepted | Ships damage each other on impact, scaled by closing speed and size; one shared hull-gap measure replaces the centre-distance guess that also let boarding trigger from four ship-lengths away. |
| [0015](decisions/0015-front-end-menu-and-practice-battles.md) | Front-End Menu and Practice Battles | Accepted | Boot to a menu offering the campaign or a practice battle where both ships are built on screen, validated by the same content gate that checks the YAML files. |
| [0016](decisions/0016-post-battle-consequences-cargo-and-the-player-fleet.md) | Post-Battle Consequences, Cargo, and the Player Fleet | Accepted | The player owns a fleet rather than a ship; damage persists with no free repair; twelve cargo types in three roles weigh against the same hull allowance as guns; morale finally bites; an after-action screen decides what comes home. |
| [0017](decisions/0017-primitive-port-and-fleet-management.md) | Primitive Port and Fleet Management Screens | Accepted | Add Port Royal as the first port menu with separate sell, repair, hire, and fleet screens; fleet management is also reachable from the overworld. |

## Related Notes

- Design brief: [Pirate Game Design Principles and Expansion Brief](design/pirate-game-design-principles-and-expansion-brief.md)
- Galleon asset plan: [Galleon Sails, Rigging & Godot Integration Plan](design/galleon-sails-rigging-plan.md)
- Frigate asset brief: [Frigate Visual Asset Brief](design/frigate-visual-brief.md)
- Boarding and duel design: [Boarding & Sword Duel Brief](design/boarding-duel-brief.md)
- Testing guide: [Prototype Testing Guide](testing.md)
- Playtest notes: [Playtest 0001: Milestone 0 Sailing Feel](playtests/0001-milestone-0-sailing-feel.md)
- Playtest notes: [Playtest 0002: Milestone 1 Cannon Readability](playtests/0002-milestone-1-cannon-readability.md)

## Template

Use [ADR template](decisions/template.md) for new decisions.
