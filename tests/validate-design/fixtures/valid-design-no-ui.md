# Design: Non-UI Example

## Problem

The log shipper retries every failed upload forever, creating a queue that
grows without bound when the receiver is down. On our last incident the
queue reached 40 GB before the node ran out of disk.

## Goal

Bound the log shipper retry queue so it drops rather than fills disk.

## Success Criteria

- A user can observe that disk usage from the shipper stays under 2 GB during an extended receiver outage.
- A user can see dropped-message counts surfaced as a metric.
- A user can restore normal shipping behavior by restarting the receiver — no manual queue cleanup required.

## Architecture

The shipper in `src/shipper/queue.go` gains a bounded ring buffer of 100k
entries. When full, new entries push old ones out and a counter in
`src/shipper/metrics.go` increments. The existing retry loop is unchanged.

## Key Decisions

- **Ring buffer over disk spooling.** Chosen because unbounded disk was the original symptom. Alternative (bounded spool file) rejected — adds file rotation complexity for a case where dropping old entries is the desired behavior.
- **Drop oldest over drop newest.** Chosen because recent entries are usually more actionable for on-call. Alternative (drop newest) rejected — hides problems that have just started.

## Non-Goals

- No per-type retention — the ring buffer is shared across all event types because differentiating them would need a priority-queue design that is out of scope here.
- No operator UI for queue inspection — metrics surface via the existing Grafana dashboard which is sufficient for now.

## Implementation Approach

| File | Change |
|---|---|
| `src/shipper/queue.go` | Replace unbounded slice with ring-buffer implementation |
| `src/shipper/metrics.go` | Add `DroppedEntries` counter, register with Prometheus |

Test impact: unit tests for ring buffer wrap-around and metric increment.
Operational impact: metric cardinality unchanged.

## Test Coverage

Coverage tool: `go test -cover` (built-in). Baseline 82%. Threshold: 85%. Coverage command: `go test -cover ./...`.

## Scope Estimate

Single phase, 3 tasks. Recommended execution mode: `subagents`.
