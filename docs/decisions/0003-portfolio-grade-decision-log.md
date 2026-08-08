# ADR 0003: Portfolio-Grade Decision Log

## Status

Accepted

## Context

The project began as a personal hobby prototype, but it may also become part of a professional portfolio. Code, README notes, and memory are not enough to explain why core project choices were made, especially once the project includes sailing, cannons, YAML content, validation, and future interconnected minigames.

The project already has ADRs, but they need to be treated as a visible decision log rather than incidental documentation.

## Decision

Maintain `docs/decision-log.md` as the public index for important project decisions. Keep individual decisions in `docs/decisions/` using short ADRs. Use playtest notes in `docs/playtests/` for subjective feel and tuning feedback that should inform later work.

Future agents should update the decision log when they make choices that affect architecture, design philosophy, data contracts, validation, controls, tooling, or milestone scope.

## Alternatives Considered

One alternative was to keep all reasoning in `README.md`. That would make the README too noisy as the project grows.

Another alternative was to rely on code comments and commit history. That would hide product and design reasoning inside implementation details.

A heavier design-document system was also possible, but the project is still a small prototype and benefits from short, focused records.

## Consequences

The project gains a clearer professional trail of reasoning. Future portfolio readers can inspect the decision log to understand tradeoffs without reverse-engineering intent from code.

The cost is that meaningful decisions require a short documentation update. This is acceptable because the project explicitly values durable precedents and future agent continuity.

## Follow-Up

When a decision becomes obsolete, create a new ADR that supersedes it rather than rewriting history. Keep old decisions available unless they contain factual errors.
