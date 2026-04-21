# Design: Orphan Scenario

## Problem

UI is broken.

## Goal

Fix the UI.

## Success Criteria

- A user can do X.

## Wireframes

- `wireframes/01-main.html` — main screen

## E2E Acceptance Scenarios

- **User sees main:** Given the app, when the user visits `wireframes/01-main.html`, then the main screen renders.
- **User sees ghost:** Given the app, when the user visits `wireframes/99-ghost.html`, then a ghost screen renders (this references a wireframe not declared above — this is the orphan scenario).

## Architecture

Touches `src/main.tsx`.

## Key Decisions

- Chose X over Y. Alternative Z was rejected because it needs a dependency we don't have.

## Non-Goals

- No internationalization — English-only user base and translation overhead outweighs the benefit here.

## Implementation Approach

| File | Change |
|---|---|
| `src/main.tsx` | Build the main screen |

## E2E Tooling

Runner: Playwright. Command: `npx playwright test`.

## Scope Estimate

Single phase, 3 tasks. Mode: subagents.
