# Design: Cross-Ref Mismatch

## Problem

Thing is broken.

## Goal

Fix the thing.

## Success Criteria

- A user can do X without error.

## Architecture

The change touches `src/foo.ts` and `src/extra.ts`.

## Key Decisions

- Chose X over Y. Alternative Z was rejected because it needs a dependency we don't have.

## Non-Goals

- No internationalization — English-only user base and translation overhead outweighs the benefit here.

## Implementation Approach

| File | Change |
|---|---|
| `src/foo.ts` | Add X |

Note: The extra module is referenced in Architecture but not documented here — this is the mismatch under test.

## Scope Estimate

Single phase, 2 tasks. Mode: subagents.
