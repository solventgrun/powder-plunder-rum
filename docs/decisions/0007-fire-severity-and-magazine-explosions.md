# ADR 0007: Fire Severity and Magazine Explosions

## Status

Accepted

## Context

Fire shot should feel different from ordinary hull damage. The game benefits from reckless, readable combat risks: burning ships should be dangerous over time, and powder magazine explosions should create rare dramatic outcomes.

## Decision

Define fire severity levels in `data/combat/status_effects.yaml`:

- small fire
- medium fire
- large fire

Fire severity controls hull damage over time, duration, visual scale, and per-second magazine explosion chance. Repeated fire applications escalate severity.

Round shot has a low direct `magazine_explosion` chance. Burning ships also roll magazine explosion chance over time, modified by the ship's `magazine_explosion_multiplier`.

Explosions currently disable/sink the ship immediately and spawn a primitive explosion visual.

## Alternatives Considered

Flat fire damage was simpler, but it made fire shot feel like just another damage number.

Multiple independent fires per ship were considered too complex for this prototype stage.

## Consequences

Fire becomes a tactical pressure system: close-range fire shot can escalate danger, but it can also ignite the firing ship. Magazine explosions give combat a rare dramatic failure state that ship types can modify.

The model remains intentionally arcade-like. There is no extinguishing, crew firefighting, spread simulation, or per-compartment damage yet.

## Follow-Up

Consider an extinguish/repair action only after enemy boat combat exists. Revisit explosion probabilities after human playtesting.
