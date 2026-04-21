# Design: Orphan Wireframe

## Problem

UI is broken.

## Goal

Fix the UI.

## Success Criteria

- A user can do X.

## Wireframes

- `wireframes/01-main.html` — main screen
- `wireframes/02-settings.html` — settings screen (referenced below by NO scenario — this is the orphan)

## E2E Acceptance Scenarios

- **User sees main:** Given the app, when the user visits `wireframes/01-main.html`, then the main screen renders.

## Architecture

Touches `src/main.tsx` and `src/settings.tsx`.

## Key Decisions

- Chose X over Y. Alternative Z was rejected because it needs a dependency we don't have.

## Non-Goals

- No internationalization — English-only user base and translation overhead outweighs the benefit here.

## Implementation Approach

| File | Change |
|---|---|
| `src/main.tsx` | Build the main screen |
| `src/settings.tsx` | Build the settings screen |

## E2E Tooling

Runner: Playwright. Command: `npx playwright test`.

## Scope Estimate

Single phase, 3 tasks. Mode: subagents.
