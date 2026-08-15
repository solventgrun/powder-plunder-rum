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

## Related Notes

- Design brief: [Pirate Game Design Principles and Expansion Brief](design/pirate-game-design-principles-and-expansion-brief.md)
- Galleon asset plan: [Galleon Sails, Rigging & Godot Integration Plan](design/galleon-sails-rigging-plan.md)
- Testing guide: [Prototype Testing Guide](testing.md)
- Playtest notes: [Playtest 0001: Milestone 0 Sailing Feel](playtests/0001-milestone-0-sailing-feel.md)
- Playtest notes: [Playtest 0002: Milestone 1 Cannon Readability](playtests/0002-milestone-1-cannon-readability.md)

## Template

Use [ADR template](decisions/template.md) for new decisions.
