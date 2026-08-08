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

## Related Notes

- Design brief: [Pirate Game Design Principles and Expansion Brief](design/pirate-game-design-principles-and-expansion-brief.md)
- Testing guide: [Prototype Testing Guide](testing.md)
- Playtest notes: [Playtest 0001: Milestone 0 Sailing Feel](playtests/0001-milestone-0-sailing-feel.md)
- Playtest notes: [Playtest 0002: Milestone 1 Cannon Readability](playtests/0002-milestone-1-cannon-readability.md)

## Template

Use [ADR template](decisions/template.md) for new decisions.
