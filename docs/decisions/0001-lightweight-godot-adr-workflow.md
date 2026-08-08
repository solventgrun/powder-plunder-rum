# ADR 0001: Lightweight Godot ADR Workflow

## Status

Accepted

## Context

The project is starting as a small playable prototype, but future agents will build on precedents created here. A pure greenfield workflow risks undocumented assumptions, while a heavy framework would fight the brief's small, disposable first milestone.

## Decision

Use Godot-native project conventions plus short Architecture Decision Records in `docs/decisions/`. Avoid adding a framework on top of Godot for the first prototype.

## Consequences

Future contributors get a clear place to document durable choices without turning the prototype into enterprise scaffolding. The project remains easy to open in standard Godot and does not require dependency management beyond the engine itself.
