# Design: Bad Order

## Problem

Thing is broken.

## Goal

Fix the thing.

## Architecture

Touches `src/foo.ts`.

## Success Criteria

- A user can do X without error.

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
