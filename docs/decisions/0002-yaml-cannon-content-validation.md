# ADR 0002: YAML Cannon Content Validation

## Status

Accepted

## Context

The project intends to become data-driven, but Godot does not provide native YAML support. Milestone 1 needs cannon and ammo data now, while the full content engine is still premature.

## Decision

Use narrow YAML files for cannon and ammo definitions under `data/cannons/`. Runtime loading supports the fields needed by the current prototype and tolerates unknown fields so future sea, land, fort, or morale data can be added without crashing.

Add per-content-type validation immediately. Validation fails on required-field, duplicate-ID, invalid-ID, and numeric-value errors. Unknown fields produce warnings so schema drift is visible while experimentation remains easy.

## Consequences

The project has an early data-driven precedent without committing to a full universal content engine. Future content types should follow the same pattern: narrow runtime loader first, explicit validation rules, and warnings for unknown fields until the schema stabilizes.
