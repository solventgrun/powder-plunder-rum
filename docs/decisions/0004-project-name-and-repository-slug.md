# ADR 0004: Project Name and Repository Slug

## Status

Accepted

## Context

The project may become part of a professional portfolio, so it needs a memorable public-facing name and a clean GitHub repository slug.

The title should preserve the playful pirate tone while the repository name should be easy to type, URL-friendly, and readable.

## Decision

Use `Powder, Plunder & Rum` as the public project title.

Use `powder-plunder-rum` as the GitHub repository slug:

```text
github.com/solventgrun/powder-plunder-rum
```

## Alternatives Considered

`powder-plunder-and-rum` is more literal but longer.

`ppr-game` is shorter but less descriptive and weaker as a portfolio URL.

`powder-plunder-rum-godot` is explicit about the engine but makes the project identity feel more technical than game-like.

## Consequences

The project has a concise, portfolio-friendly title and URL. The repository slug omits punctuation and the ampersand because those are awkward in URLs and command-line workflows.

Future branding, README copy, and project exports should use `Powder, Plunder & Rum` unless a deliberate rename supersedes this decision.
