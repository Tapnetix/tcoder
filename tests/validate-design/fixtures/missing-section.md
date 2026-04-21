# Design: Missing Goal

## Problem

Thing is broken and users cannot do X.

## Success Criteria

- A user can do X without error.

## Architecture

Touches `src/foo.ts`.

## Key Decisions

- Chose X over Y. Alternative Z was rejected because it needs a dependency we don't have.

## Non-Goals

- No internationalization — English-only user base and translation overhead outweighs the benefit here.

## Implementation Approach

| File | Change |
|---|---|
| `src/foo.ts` | Add X |

## Scope Estimate

Single phase, 2 tasks. Mode: subagents.
