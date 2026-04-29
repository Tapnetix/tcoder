---
name: orchestrate
description: Use when executing implementation plans with independent tasks in the current session
---

# Orchestrate

Execute plans via the configured execution mode. Phases run sequentially; task dispatch within each phase depends on the mode.

**Core principle:** The lead coordinates — dispatched implementers touch code.

## Prompt Templates

| Template | Purpose |
|----------|---------|
| `./implementer-prompt.md` | Invocation template for `tcoder:task-implementer` |
| `./task-reviewer-prompt.md` | Invocation template for `tcoder:task-reviewer` |
| `skills/implementation-review/reviewer-prompt.md` | Invocation template for `tcoder:implementation-reviewer` |
| `./dispatch-subagents.md` | Subagents dispatch protocol |
| `./dispatch-agent-teams.md` | Agent teams dispatch protocol |

## Output Discipline

The task list is the user's progress display — your free text scrolls it off screen. Stay quiet between events; let TaskUpdate tell the story.

**Don't emit narration text for:**
- "Dispatching implementer for X" — TaskUpdate to in_progress already says this
- "Agent X completed" — TaskUpdate to completed already says this
- "Waiting on A1, A2, A3" — visible in the in_progress tasks
- "Merged X into Y" — internal plumbing, user doesn't need it
- Mid-loop status restatements ("still working on phase A...")

**Do emit a short text line for:**
- A user decision is needed (AskUserQuestion follows immediately)
- An unrecoverable failure that halts the workflow
- A non-obvious deviation from the plan that the user should know about

**Push detail into the task list, not chat.** When a review finds actionable issues, don't write "A1 review: 2 issues (1 medium + 1 low). #1 is real — reset test doesn't seed a photo first. #2 is environmental — dismiss." Instead, TaskUpdate the A1 tracking item's description with the same content. The user sees it in the list; the list stays on screen.

**Default to silence between TaskUpdates.** A turn with only tool calls (TaskUpdate, Agent, Bash) and no user-facing text is fine and often correct.

## Progress Tracking

The task list is the user's primary visibility into orchestration. A sparse list (one item per phase) hides what's running. Be granular: one tracking task per actual unit of work, with descriptive subjects that tell the user what "done" looks like.

### When to TaskCreate

At orchestrate startup, after reading plan.json, create the full tracking skeleton in a single batch. One TaskCreate per:

- **Each implementation task in plan.json** — subject: `{TASK_ID}: {name} — {done_when}` (truncate done_when to ~60 chars). activeForm: `Implementing {TASK_ID}`. One per task in `.phases[].tasks[]`.
- **Each phase's implementation review** — subject: `Review phase {LETTER} — cross-task issues, coverage`. activeForm: `Reviewing phase {LETTER}`.
- **Each phase's coverage gate** (when `COVERAGE_MODE` is `enforce` and `COVERAGE_CMD` is set) — subject: `Coverage gate — phase {LETTER} ≥{COVERAGE_THRESHOLD}%`. activeForm: `Checking coverage`.
- **Final review** (multi-phase only) — subject: `Final cross-phase review`. activeForm: `Final review`.
- **PR step** (when workflow is not `plan-only`) — subject mirrors workflow: `Create PR`, `Create PR + merge`, or `Direct merge`. activeForm: matching present-continuous form.
- **Mark plan complete** — subject: `Mark plan complete`. activeForm: `Finalizing`.

Set `addBlockedBy` to enforce ordering: phase B's tasks block on phase A's review; reviews block on all their phase's tasks; the PR step blocks on the final review.

### When to TaskUpdate

- **Dispatching an implementer** → TaskUpdate to `in_progress` for that task's tracking item. When dispatching multiple implementers in parallel, mark all of them in_progress in the same turn (one TaskUpdate per task).
- **Review passes for a task** → TaskUpdate to `completed`. If a review fix cycle runs, the task stays `in_progress` until the final review pass.
- **Implementation review starts** → TaskUpdate the review tracking item to `in_progress`. After verdict pass → `completed`.
- **Coverage gate, PR step, plan completion** — same in_progress / completed pattern.

### Why this matters

The user can't see subagent activity without TaskUpdate. A 5-task phase running 5 parallel implementers should show 5 `in_progress` items in the task list — that's what makes the orchestrator look alive. Sparse tracking (one task per phase) collapses 5 visible work items into 1, masking what's actually happening.

## Setup

Before first phase:
- Resolve absolute path: `PLAN_JSON=$(realpath plan.json)` and `PLAN_DIR=$(dirname "$PLAN_JSON")`
  Plan artifacts live under `.claude/tcoder/` (gitignored). Phase worktrees won't have these files, so all plan.json references must use the absolute `$PLAN_JSON` path — it points to the integration worktree where the plan was created.
- Read workflow: `WORKFLOW=$(jq -r '.workflow' "$PLAN_JSON")`
- Read execution mode: `EXEC_MODE=$(jq -r '.execution_mode' "$PLAN_JSON")`
Note: `workflow` and `execution_mode` are read from plan.json (set by the design skill based on user selection and tcoder-settings defaults), not from tcoder-settings at runtime. This avoids two sources of truth — the plan is the single source once created.
- Read task implementer model: `TASK_IMPLEMENTER_MODEL=$(tcoder-settings get task_implementer_model)`
- Read task reviewer model: `TASK_REVIEWER_MODEL=$(tcoder-settings get task_reviewer_model)`
- Read implementation reviewer model: `IMPL_REVIEWER_MODEL=$(tcoder-settings get implementation_reviewer_model)`
Note: These model settings are substituted into dispatch template variables `{TASK_IMPLEMENTER_MODEL}`, `{TASK_REVIEWER_MODEL}`, and `{IMPL_REVIEWER_MODEL}` when dispatching implementers, reviewers, and fix-cycle agents.
- Read coverage config: `COVERAGE_MODE=$(tcoder-settings get coverage_mode)` and `COVERAGE_THRESHOLD=$(tcoder-settings get coverage_threshold)`. Also read from plan.json: `COVERAGE_CMD=$(jq -r '.coverage.command // empty' "$PLAN_JSON")`. If `COVERAGE_MODE` is not `off` and `COVERAGE_CMD` is non-empty, pass `{COVERAGE_MODE}`, `{COVERAGE_THRESHOLD}`, and `{COVERAGE_CMD}` to implementer and reviewer prompts.
- Read E2E config: `E2E_MODE=$(tcoder-settings get e2e_mode)`, `E2E_CMD=$(jq -r '.e2e.command // empty' "$PLAN_JSON")`, `E2E_RUNNER=$(jq -r '.e2e.runner // empty' "$PLAN_JSON")`. When `E2E_MODE=off`, all E2E branches skip (no per-task gate, no phase-end gate, no e2e-gate records). Otherwise gates run at task scope (implementer-owned) and phase scope (orchestrator-owned) — see **E2E Gates** below.
- Count phases: `PHASE_COUNT=$(jq '.phases | length' "$PLAN_JSON")`
- Validate schema: `validate-plan --schema "$PLAN_JSON"`
- Validate entry gate: `validate-plan --check-entry "$PLAN_JSON" --stage execution`
- Validate base branch: `validate-plan --check-base "$PLAN_JSON"`
- Validate consistency: `validate-plan --consistency "$PLAN_JSON"`
- `validate-plan --update-status "$PLAN_JSON" --plan --status "In Development"`
- `PLAN_BASE_SHA=$(git rev-parse HEAD)`
- `[ -f "$PLAN_DIR/reviews.json" ] || echo '[]' > "$PLAN_DIR/reviews.json"`
- Push branch: `git push -u origin HEAD`
- **Build tracking skeleton** — TaskCreate one entry per implementation task, per phase review, per phase coverage gate (when applicable), the final review (multi-phase), the PR step, and the plan-complete step. See **Progress Tracking** above for subjects, activeForms, and dependency wiring. Send all TaskCreate calls in a single batch.
- Read the dispatch protocol for `EXEC_MODE`: **See:** `./dispatch-subagents.md` (subagents) or `./dispatch-agent-teams.md` (agent-teams) — read only the file matching `EXEC_MODE`

## Per-Phase Execution (Sequential)

Process phases in order (A, B, C...). For each phase:

### Prepare Phase

1. Create phase worktree from integration branch (multi-phase) or use feature worktree (single-phase)
2. Re-validate base branch: `validate-plan --check-base "$PLAN_JSON"` (multi-phase only — ensures dispatch happens from integration worktree, not main)
3. `PHASE_BASE_SHA=$(git rev-parse HEAD)` in worktree
4. **Bootstrap dependencies** in the worktree. **See:** skills/design/dependency-bootstrap.md
5. Extract context: tasks JSON, plan dir, phase dir, prior completions (from depends_on closure)
6. Cross-phase handoff notes: lead writes handoff sections to task .md files for tasks consuming prior-phase output
7. Set phase to "In Progress": `validate-plan --update-status "$PLAN_JSON" --phase {LETTER} --status "In Progress"` — required before any task can be marked in_progress (transition gate rejects task advancement when parent phase is "Not Started")

### Dispatch, Complete, and Review Tasks

Follow the dispatch protocol from the mode-specific file read during setup. Both modes share these invariants:
- Only dispatch tasks whose dependencies are met (`validate-plan --check-deps "$PLAN_JSON"`)
- Each task gets reviewed after implementation (reviewer always uses `./task-reviewer-prompt.md`)
- After review passes: validate criteria (`validate-plan --criteria "$PLAN_JSON" --task {TASK_ID}`), merge task branch, check for newly unblocked tasks

The dispatch file specifies how tasks are dispatched (teammates vs subagents), how completions are detected (push vs background notification), and how review fixes are communicated (mailbox vs fresh agent).

### E2E Gates (when E2E_MODE != off and the plan has an E2E block)

Each task delivering UX owns one spec file at `<e2e.spec_dir>/<task_id_lower><ext>` (where `<ext>` is `.spec.ts` for playwright/vitest, `.cy.ts` for cypress, `_test.py` for pytest) listing its scenario IDs in `e2e_scenarios`. Test names are prefixed `S<n>:` so name-based runners filter by ID.

**Per-runner filter map:**

| Runner | Filter form |
|---|---|
| playwright | `--grep "S1\|S2"` |
| vitest | `-t "S1\|S2"` |
| pytest | `-k "S1 or S2"` |
| cypress | `--spec <path>` (file-based — each task owns one file at the deterministic path) |

**Per-task gate (implementer-owned):** the implementer runs the filtered command for its `e2e_scenarios` as part of TDD red/green within its session and commits only when green. The orchestrator does not re-run per task; the phase-end aggregate covers it.

**Phase-end gate (orchestrator-owned):** after the per-phase impl-review passes (Phase Wrap-Up step 1), run the same filter form OR-ed across every scenario introduced through this phase plus all earlier phases. The final phase's wrap-up therefore covers the full plan — no separate plan-end gate.

**E2E-gate review record** (appended to `${PLAN_DIR}/reviews.json`):

```json
{
  "type": "e2e-gate",
  "scope": "task" | "phase",
  "task_id": "A2",
  "phase": "A",
  "scenarios": ["S1", "S2"],
  "command": "npx playwright test --grep \"S1|S2\"",
  "verdict": "pass" | "fail",
  "timestamp": "2026-04-29T12:34:56Z"
}
```

`scope: "task"` records carry `task_id` (written by the implementer); `scope: "phase"` records carry `phase` and the union of in-scope scenarios (written by the orchestrator).

**Mode behavior:**
- `off` — no records, no gates run; skip every E2E branch.
- `advisory` — both gates run and write records identically to `enforce`; a `fail` surfaces as a non-blocking warning in completion notes and the orchestrator advances.
- `enforce` — a `fail` halts the phase. Dispatch an implementer to fix, re-run the gate, advance only after the record flips to `pass`.

### Phase Wrap-Up

After all tasks complete and branches merged:
1. TaskUpdate the phase's review tracking item to `in_progress`. Dispatch implementation-review with `PHASE_BASE_SHA..HEAD` using `model: "$IMPL_REVIEWER_MODEL"`, run Review Loop Protocol (scope: `phase-{letter_lower}`). On verdict pass, TaskUpdate the review tracking item to `completed`.
2. `validate-plan --check-review "$PLAN_JSON" --type impl-review --scope phase-{letter_lower}`
3. **Phase-end E2E gate** (when `E2E_MODE != off` and the plan has an E2E block): build the filter from every scenario introduced through this phase plus all earlier phases using the per-runner map above, run the resulting command, and append a `scope: "phase"` e2e-gate record to `${PLAN_DIR}/reviews.json`. Under `enforce`, a `fail` halts the phase until fixed; under `advisory`, log a non-blocking warning in `${PHASE_DIR}/completion.md` and advance.
4. Append review changes to `${PHASE_DIR}/completion.md`
5. **Coverage gate** (when `COVERAGE_MODE` is `enforce` and `COVERAGE_CMD` is set): TaskUpdate the coverage tracking item to `in_progress`. Run the coverage command and verify the result meets `COVERAGE_THRESHOLD`. If coverage has regressed below the threshold, dispatch an implementer to add missing tests before proceeding. Log coverage percentage in `${PHASE_DIR}/completion.md`. TaskUpdate to `completed` once threshold is met.
6. Run phase criteria: `validate-plan --criteria "$PLAN_JSON" --phase {LETTER}`
7. Update status: `validate-plan --update-status "$PLAN_JSON" --phase {LETTER} --status "Complete (YYYY-MM-DD)"`
8. (Multi-phase) Create phase PR, external review gate, merge, clean up worktree

## Review Loop Protocol

Read the re-review threshold: `RE_REVIEW_THRESHOLD=$(tcoder-settings get re_review_threshold)` (default: 5).

After each impl-review dispatch:

1. Extract last `json review-summary` fenced block from response. Missing/malformed -> verdict:fail, re-dispatch.
2. Triage issues: "fix" (dispatch implementer) or "dismiss" (with reasoning)
3. actionable == 0 -> write reviews.json record with verdict:pass, advance
4. actionable 1-$RE_REVIEW_THRESHOLD -> fix all, verify, write record verdict:pass, advance
5. actionable > $RE_REVIEW_THRESHOLD -> fix all, write record verdict:fail, re-dispatch (max 3 iterations, then escalate via AskUserQuestion)

Append record to `{PLAN_DIR}/reviews.json`:
`{"type":"impl-review","scope":"{SCOPE}","iteration":N,"issues_found":N,"severity":{...},"actionable":N,"dismissed":N,"dismissals":[...],"fixed":N,"remaining":0,"verdict":"pass|fail","timestamp":"ISO8601"}`

## Single-Phase Plans

Skip integration branch and phase worktrees. Work directly in the feature worktree:

1. Dispatch tasks, process completions, wrap up (same dispatch protocol as above)
2. Dispatch implementation-review, run Review Loop Protocol (scope: `phase-a`)
3. `validate-plan --check-review "$PLAN_JSON" --type impl-review --scope phase-a`
4. Run plan criteria: `validate-plan --criteria "$PLAN_JSON" --plan`
5. `validate-plan --update-status "$PLAN_JSON" --plan --status Complete`
6. Route on workflow (TaskUpdate the PR tracking item to `in_progress` before invoking, `completed` after):
   - `"pr-create"`: invoke pr-create (targets main), `validate-plan --check-workflow "$PLAN_JSON"`, stop
   - `"pr-merge"`: invoke pr-create, read `REVIEW_WAIT=$(tcoder-settings get review_wait_minutes)`, poll checks + pr-review --automated (skip if $REVIEW_WAIT is 0; if skipped, invoke pr-merge directly), `validate-plan --check-workflow "$PLAN_JSON"`
   - `"direct-merge"`: follow the **Direct Merge Protocol** below instead of creating a PR, then `validate-plan --check-workflow "$PLAN_JSON"`
7. TaskUpdate the "Mark plan complete" tracking item to `completed`.

## After All Phases (Multi-Phase Only)

1. Run plan criteria: `validate-plan --criteria "$PLAN_JSON" --plan`. If exit 1, do not mark complete.
2. TaskUpdate the "Final cross-phase review" tracking item to `in_progress`. Dispatch implementation-review with `PLAN_BASE_SHA..HEAD`, run Review Loop Protocol (scope: `final`). On verdict pass, TaskUpdate to `completed`.
3. `validate-plan --check-review "$PLAN_JSON" --type impl-review --scope final`
4. `validate-plan --update-status "$PLAN_JSON" --plan --status Complete`
5. Route on workflow (TaskUpdate the PR tracking item to `in_progress` before invoking, `completed` after):
   - `"pr-merge"`: create final PR, poll checks, pr-review --automated, `validate-plan --check-workflow "$PLAN_JSON"`, clean up
   - `"pr-create"`: create final PR, `validate-plan --check-workflow "$PLAN_JSON"`, stop
   - `"direct-merge"`: follow the **Direct Merge Protocol** below (operate on the integration branch), `validate-plan --check-workflow "$PLAN_JSON"`, clean up
6. TaskUpdate the "Mark plan complete" tracking item to `completed`.

**Continuity:** Run continuously. Pause only for Rule 4 violations.

## Direct Merge Protocol

Use when `workflow == "direct-merge"`. Skips PR creation entirely — fast-forward merges the feature (or integration) branch into `main` locally, then asks the user whether to push. This is the right path when the repo doesn't enforce PR-only merges via branch protection and no external review is needed.

1. Determine the source branch:
   - Single-phase plan: the feature worktree's current branch
   - Multi-phase plan: the integration branch (`jq -r '.integration_branch' "$PLAN_JSON"`)
2. From the repository root (not a worktree), run:
   ```bash
   git checkout main
   git fetch origin main
   git merge --ff-only origin/main  # ensure local main is current
   git merge --ff-only <source-branch>
   ```
   If `--ff-only` fails (main advanced after this work started), STOP and AskUserQuestion: `Rebase the feature onto main, fall back to pr-create, or abort?` Do not use `--no-ff` silently — it changes history shape.
3. AskUserQuestion — single question, header "Push":
   - **Push to origin** — `git push origin main` (use the same SSH/HTTPS creds the user established earlier in the session)
   - **Not now** — stop; tell the user they can push later with `git push origin main`
4. After a successful push, offer branch cleanup:
   - `git branch -d <source-branch>` locally
   - `git push origin --delete <source-branch>` remotely (only if the branch was pushed earlier)
   - For multi-phase: also prompt about deleting the worktrees with `git worktree remove`
5. If `.claude-plugin/marketplace.json` version was bumped in this branch, remind the user to `gh release create vX.Y.Z --generate-notes`. Do not run it yourself — release creation is visible to the wider audience and needs the user's explicit call.

If the push is rejected by branch protection, tell the user: "Direct push rejected. Your branch protection requires a PR — re-run with workflow=pr-merge or open a PR manually." Do not retry with `--force`.

## Key Constraints

| Constraint | Why |
|------------|-----|
| Resolve `PLAN_JSON` as absolute path at setup | Plan artifacts are gitignored — phase worktrees won't have them. Absolute path ensures all agents access the same file. |
| Read `execution_mode` from plan.json at setup | Determines which dispatch protocol to follow |
| Validate schema before execution | Catches file-set overlap and structural issues early |
| Record PLAN_BASE_SHA before first phase | Final cross-phase review needs total diff |
| Record PHASE_BASE_SHA per phase | Per-phase review needs exact phase start |
| Use validate-plan for all status updates | Keeps plan.json and plan.md in sync |
| All tasks complete before advancing phase | Phase completion gate prevents unresolved work |
| Run gate checks at startup and after status changes | Entry gates prevent wasted work, base-branch checks prevent wrong-worktree dispatch, consistency checks catch state drift |

## Integration

**Workflow:** design → draft-plan → **this skill** → pr-create → pr-review → pr-merge
**See:** `tdd.md`
