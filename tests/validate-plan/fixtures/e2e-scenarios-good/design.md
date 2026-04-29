# E2E Scenarios — happy path

## Problem

Reviewers cannot read or annotate markdown files in the current shell, so review
sessions stall while reviewers context-switch to external tools and lose the
inline thread of comments alongside the rendered prose.

## Goal

Render markdown files inline and let reviewers attach comments to selections
without leaving the shell.

## Success Criteria

- A reviewer can open a markdown file and see formatted output, not raw source.
- A reviewer can highlight text and attach a comment that persists across reloads.

## Wireframes

- `wireframes/01-render.html` — rendered markdown view
- `wireframes/02-comment.html` — comment thread on a selection

## E2E Acceptance Scenarios

- S1: render a markdown file — see `wireframes/01-render.html`
- S2: add a comment to a selection — see `wireframes/02-comment.html`

## Scenario Allocation

| Scenario | Task label |
|---|---|
| S1 | Render markdown |
| S2 | Add comment |

## Architecture

Two phases. Phase A renders markdown via `e2e/a1.spec.ts` driving `src/shell.ts`.
Phase B layers comments on the rendered view via `e2e/b1.spec.ts`.

## Key Decisions

- Chose Playwright over Cypress for E2E. Playwright gains multi-tab support and
  better trace viewers; Cypress was rejected because its single-tab model blocks
  comment-thread workflows.
- Chose inline rendering over an iframe. Inline gains direct DOM access for
  selection APIs; iframe was rejected because cross-frame selection is brittle.

## Non-Goals

- No collaborative real-time editing because that requires a sync server, CRDTs,
  and presence indicators well beyond the scope of this rendering and comment
  feature, and would block shipping the simpler reviewer workflow.
- No support for non-markdown formats because adding parsers and renderers for
  rst, asciidoc, and org-mode would multiply the test surface and delay the
  primary reviewer benefit without clear demand from current users.

## Implementation Approach

- Add `e2e/a1.spec.ts` covering S1 against `src/shell.ts`.
- Add `e2e/b1.spec.ts` covering S2 against `src/shell.ts`.
- Wire the shell entry through `src/shell.ts` so both specs share the same mount.
- Wireframes live under `wireframes/01-render.html` and `wireframes/02-comment.html`.

## E2E Tooling

Playwright. Specs live under `e2e/` and run via `npx playwright test`.

## Scope Estimate

Two phases, three tasks total. Phase A has two tasks; Phase B has one task.
