# Design: Example Feature

## Problem

Users cannot filter the activity feed by event type. The feed mixes deploys,
comments, and alerts into one stream, and during incidents operators waste
time scrolling past irrelevant entries. Response times grow with feed length.

## Goal

Let operators filter the activity feed by event type in one click.

## Success Criteria

- A user can pick one or more event types from a filter control and see only matching entries.
- A user can clear the filter and see the full feed again.
- The filter choice persists across page reloads for the current user.

## Wireframes

- `wireframes/01-feed.html` — default feed with filter pill row at top
- `wireframes/02-feed-filtered.html` — feed after selecting deploys + alerts

## E2E Acceptance Scenarios

- **S1 Filter narrows feed:** Given the feed has 20 mixed entries, when the user clicks the "Deploys" pill in `wireframes/01-feed.html`, then only deploy entries appear.
- **S2 Clear filter restores feed:** Given a filter is active in `wireframes/02-feed-filtered.html`, when the user clicks "Clear", then all 20 entries reappear.

## Scenario Allocation

| Scenario | Task label |
|---|---|
| S1 | Filter feed by event type |
| S2 | Clear the active filter |
| S3 | Persist the filter selection |

## Architecture

The filter control lives in `src/feed/FilterBar.tsx` and dispatches selection
state to `src/feed/feedStore.ts`. The feed list in `src/feed/FeedList.tsx`
reads filtered entries from the store. Persistence uses `localStorage` via a
thin wrapper in `src/feed/filterPersistence.ts`.

## Key Decisions

- **Client-side filtering over server round-trip.** Chosen because feed size is bounded at 200 entries per page. Alternative (server-side filter query) rejected — adds latency and requires a new API parameter for what is effectively a display concern.
- **localStorage persistence over URL state.** Chosen because the filter is user-scoped, not share-scoped. Alternative (URL query param) rejected — links shared between operators would carry the sharer's filter choice, which is confusing.

## Non-Goals

- No server-side filtering — client-side handles the bounded feed size adequately and server changes would add unnecessary API surface for this bounded case.
- No per-team default filters — team presets are a separate feature request and would require a stored preference model we do not have yet.

## Implementation Approach

| File | Change |
|---|---|
| `src/feed/FilterBar.tsx` | New component with pill buttons per event type |
| `src/feed/feedStore.ts` | Add `filter` slice and selector for filtered entries |
| `src/feed/FeedList.tsx` | Consume filtered selector instead of raw feed |
| `src/feed/filterPersistence.ts` | New — localStorage read/write for filter state |

Test impact: add unit tests for the store slice and component; update FeedList tests to assert filtered rendering. Operational impact: none — no schema or config changes.

## Test Coverage

Coverage tool: `jest` already configured. Baseline 87%. Threshold: 90%. Coverage command: `npx jest --coverage --coverageReporters=text`.

## E2E Tooling

Runner: Playwright (already installed). Command: `npx playwright test`.

## Scope Estimate

Single phase, 5 tasks. Recommended execution mode: `subagents` (under the 10-task multi-phase threshold).
