---
name: design
description: Use when creating features, building components, adding functionality, or modifying behavior - before any creative or implementation work begins
---

# Design: Ideas Into Plans

Turn ideas into validated designs through collaborative dialogue before any code is written.

<HARD-GATE>
Do NOT invoke implementation skills, write code, or scaffold projects until you have presented a design and the user has explicitly approved it. Skipping design validation is the #1 cause of wasted work in AI-assisted sessions. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Anti-Pattern: "Too Simple to Need a Design"

A todo list, a utility function, a config change — all go through this process. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be a few sentences, but you must present it and get approval.

## Checklist

Complete in order:

1. **Explore context** — files, docs, recent commits. Understand the codebase you're working in before asking the user anything.
2. **Challenge assumptions** — question the framing like a senior PM before accepting it (see below)
3. **Investigate and clarify** — ask questions one at a time to deeply understand the problem and requirements. Scale depth to scope (see below). This is the most important phase — rushing through it is the #1 cause of designs that miss the mark.
4. **Propose 2-3 approaches** — trade-offs and your recommendation
5. **Present design** — sections scaled to complexity, approval after each
5b. **Wireframes (UI features only)** — produce proper UX wireframes as HTML+CSS under `<plan-dir>/wireframes/` and hard-gate on the user's explicit approval (sentinel `<plan-dir>/.wireframes-approved`) before planning. Also capture **E2E Acceptance Scenarios** in the design doc — one Given/When/Then per wireframe behavior — these drive the plan's `e2e-red` task. **See:** wireframes.md for the detection rule, file layout, approval loop, and tooling notes.
6. **Set up worktree** — `EnterWorktree` enables session-aware cleanup via `ExitWorktree`:
   - `EnterWorktree(name: "<feature>")` — creates `.claude/worktrees/<feature>` with branch `<feature>`
   - Multi-phase: rename to integration branch: `git branch -m integrate/<feature>` — phase worktrees created by orchestrate as siblings
   - Single-phase: branch name `<feature>` is correct as-is; orchestrate works here directly, PRs to main
   1. Bootstrap dependencies per **See:** ./dependency-bootstrap.md
   2. Run tests to establish a clean baseline
7. **Configure and approve** — single AskUserQuestion with 3 questions:

    **Q1 — Workflow** (header: "Workflow"):
    Run `tcoder-settings get workflow`.
    - If a value is returned (e.g. `pr-create`): skip this question. Message: "Using your configured workflow: <value>".
    - If `PROMPT_REQUIRED`: include in AskUserQuestion with recommended option marked "(Recommended)":
      - **Create PR** — Orchestrate → pr-create (Recommended)
      - **Merge PR** — Orchestrate → pr-create → pr-review → pr-merge
      - **Direct merge** — Orchestrate → fast-forward merge into main locally → ask before pushing (skip PR). Use when the repo doesn't enforce PRs via branch protection and you don't need external review.
      - **Plan only** — Stop after plan is reviewed

    **Q2 — Execution mode** (header: "Exec mode"):
    Run `tcoder-settings get execution_mode`.
    - If a value is returned (e.g. `subagents`): skip this question. Message: "Using your configured execution mode: <value>".
    - If `PROMPT_REQUIRED`: include in AskUserQuestion. Recommend based on design complexity:
      - ≤10 tasks AND single phase → recommend `Subagents`
      - >10 tasks OR multi-phase → recommend `Agent teams`

      Mark the recommended option with "(Recommended)". Options:
      - **Subagents** — Parallel Agent tool dispatches with worktree isolation. No special env var needed.
      - **Agent teams** — Parallel teammates with push notifications and mailbox messaging. Requires env var.

    **Q3 — Approval** (header: "Approval"):
    - **Approve design (auto turn on acceptEdits)**
    - **Needs changes**

    If "Needs changes" on Q3, return to step 5.

    **Agent teams fallback:** If user picks "Agent teams", check `$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. If not `1`, use AskUserQuestion to explain: "Agent teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. To enable: run `echo 'export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1' >> ~/.zshrc && source ~/.zshrc`, then restart Claude Code." Offer: "Continue with subagents" or "Stop (I'll restart with agent teams)". If they choose subagents, override the Q2 answer to `Subagents` before step 11 writes plan.json. If they stop, tell them the exact command to resume: `claude --continue` in the worktree directory.

    On approval, create sentinel: `mkdir -p <plan-dir> && touch <plan-dir>/.design-approved`
8. **Write design doc** — `.claude/tcoder/YYYY-MM-DD-<topic>/design-<topic>.md` (no commit — gitignored transient state). Follow **See:** `design-spec.md` for the authoritative section structure (8 always-required + 4 conditional sections, canonical order, cross-reference rules).

   **Tooling detection (run now, not earlier — don't let this disrupt the conversation):**
   Run `COVERAGE_MODE=$(tcoder-settings get coverage_mode)`. If not `off`: detect whether the project has test coverage tooling configured (jest coverage config, pytest-cov/coverage.py, go test -cover, nyc/c8, etc.). Note findings for the Test Coverage section. Run the equivalent probe for E2E: `E2E_MODE=$(tcoder-settings get e2e_mode)`; when not `off`, detect any existing E2E runner (Playwright, Cypress, Selenium, Vitest+jsdom).

   Before dispatching design-review, verify the doc satisfies this quality checklist (catches the most common reviewer findings on first pass):
   - Success criteria are behavioral outcomes, not implementation details ("users can log in" not "tests pass" or "middleware installed")
   - Non-goals each include a brief rationale for why they're excluded
   - Every file mentioned in the implementation approach is covered in the architecture section (and vice versa)
   - Test impact is noted for every behavior change
   - Migration/operational steps are captured if the change touches data or config
9. **Structural validation** — run `validate-design --check <path>` against the design doc. This catches mechanical issues (missing sections, bad ordering, empty headings, cross-reference mismatches, non-goal rationale length, orphan wireframes/scenarios) before the LLM reviewer burns context on them. Fix all errors before proceeding to self-review. Hard gate — planning will not proceed without it.
10. **Self-review pass** — before dispatching the external reviewer, read through the design doc yourself against the checklist in `agents/design-reviewer.md`. Fix any issues you find. Goal: catch obvious gaps so the external reviewer surfaces only non-obvious ones. This is an inline check, not a subagent dispatch — no output format required, just fix what you find.
11. **Dispatch design-review subagent** — fresh reviewer agent validates design before planning (hard gate)
12. **Dispatch draft-plan subagent** — fresh implementer agent with design doc path and worktree path (zero design context)
13. **Route workflow** — Map step 7 choices to schema values:
    - Workflow: `Create PR` → `pr-create`, `Merge PR` → `pr-merge`, `Direct merge` → `direct-merge`, `Plan only` → `plan-only`
    - Exec mode: `Subagents` → `subagents`, `Agent teams` → `agent-teams`

    Write both: `jq --arg w "<workflow>" --arg e "<exec-mode>" '.workflow = $w | .execution_mode = $e' plan.json > tmp && mv tmp plan.json`

    For multi-phase plans, also write the integration branch name:
    `jq --arg ib "integrate/<feature>" '.integration_branch = $ib' plan.json > tmp && mv tmp plan.json`

    For **Create PR**, **Merge PR**, or **Direct merge**: invoke orchestrate.
    For **Plan only**: run `validate-plan --check-workflow plan.json` to verify design-review and plan-review passed. Report the plan file path and stop.

Read the design reviewer model: `DESIGN_REVIEWER_MODEL=$(tcoder-settings get design_reviewer_model)`

```text
Agent(
  subagent_type: "tcoder:design-reviewer",
  model: "$DESIGN_REVIEWER_MODEL",
  prompt: "Review the design doc at .claude/tcoder/<folder>/design-<topic>.md

    Codebase root: .claude/worktrees/<feature>"
)
```

**Iteration tracking:** Initialize `ITER=1` at first dispatch (step 10). Increment `ITER` by 1 on each re-dispatch (step 6 of "If reviewer finds issues" below). Use `ITER` as `N` in all reviews.json writes and in the `iter ≥2` / `after iteration 3` conditions below.

After each reviewer dispatch, extract the `json review-summary` block from the response.

**Per-iteration reviews.json write:** Write a record after EVERY iteration (not just the final pass). Initialize `reviews.json` with `[]` if it doesn't exist. `actionable` = issues_found minus dismissed. Each record:

`jq --argjson entry '{"type":"design-review","scope":"design","iteration":N,"issues_found":N,"severity":{"critical":C,"high":H,"medium":M,"low":L},"actionable":N,"dismissed":D,"dismissals":[{"id":ID,"reasoning":"..."}],"fixed":F,"remaining":0,"verdict":"pass|fail","timestamp":"<ISO8601>"}' '. += [$entry]' reviews.json > tmp && mv tmp reviews.json`

**If reviewer finds issues:**

1. **Extract ALL issues** from the `json review-summary` `issues[]` array
2. **Present all issues to the user** for triage — the user decides fix vs dismiss for each, with a reason for dismissals
3. **Apply all fixes and dismissals in a single editing pass** — do not dispatch a reviewer between individual fixes
4. **Apply severity-gated termination:**
   - **Iterations 1–3, only `medium`/`low` remain:** if all remaining issues are `medium` or `low` (no `critical` or `high`), you may fix all issues, write verdict `"pass"`, and proceed directly to step 11 — or fix all issues and re-dispatch for another pass if there are many issues or you want more confidence.
   - **After iteration 3 (`ITER > 3`), only `medium`/`low` remain:** fix all remaining issues, write the reviews.json record with verdict `"pass"` (skip step 5's `fail` path), and skip step 6 (no re-dispatch). Proceed to step 11.
5. **Write the iteration record** to reviews.json — verdict is `fail`; `remaining` is always 0 (all issues are fixed or dismissed after steps 3–4).
6. **Construct delta context and re-dispatch** (`ITER` += 1): enrich the reviewer's `issues[]` array from the prior iteration with two fields based on triage decisions:
   - `resolution`: `"fixed"` or `"dismissed"`
   - `dismissal_reason`: present only when dismissed

   Dispatch with `## Prior Issues` appended after the "Codebase root" line:

   ```text
   Agent(
     subagent_type: "tcoder:design-reviewer",
     model: "$DESIGN_REVIEWER_MODEL",
     prompt: "Review the design doc at .claude/tcoder/<folder>/design-<topic>.md

       Codebase root: .claude/worktrees/<feature>

       ## Prior Issues
       <json array: id, severity, category, problem, fix, resolution, dismissal_reason?>"
   )
   ```

**If reviewer passes (zero issues):** Write the passing record to reviews.json (`ITER`, `remaining`:0, verdict: pass) and proceed to step 11.

Read the planner model: `PLANNER_MODEL=$(tcoder-settings get planner_model)`

```text
Agent(
  subagent_type: "tcoder:plan-drafter",
  model: "$PLANNER_MODEL",
  prompt: "Read the design doc at .claude/tcoder/<folder>/design-<topic>.md and write
    an implementation plan.

    Working directory: .claude/worktrees/<feature>
    Plan directory: .claude/tcoder/<folder>/"
)
```

After draft-plan returns, dispatch plan-review with the same review loop protocol:

Read the plan reviewer model: `PLAN_REVIEWER_MODEL=$(tcoder-settings get plan_reviewer_model)`

```text
Agent(
  subagent_type: "tcoder:plan-reviewer",
  model: "$PLAN_REVIEWER_MODEL",
  prompt: "Review the implementation plan at .claude/tcoder/<folder>/plan.json

    Design doc: .claude/tcoder/<folder>/design-<topic>.md
    Codebase root: .claude/worktrees/<feature>"
)
```

Extract the `json review-summary` block from the response. Triage issues (fix plan files or dismiss with reasoning). Read the threshold: `tcoder-settings get re_review_threshold`. If actionable issues exceed this threshold, fix and re-dispatch reviewer (max 3 iterations, then escalate to user). Write review record to `{PLAN_DIR}/reviews.json`: `{"type":"plan-review","scope":"plan","iteration":N,"issues_found":N,"severity":{...},"actionable":N,"dismissed":N,"dismissals":[...],"fixed":N,"remaining":0,"verdict":"pass","timestamp":"ISO8601"}` (Note: plan-review intentionally uses the `re_review_threshold`-based gate, not severity-gated termination — the two loops use different termination models by design.)


## Challenging Assumptions

Before clarifying questions, challenge the framing like a senior PM. Don't accept the first framing — push on it:

- "What problem does this solve, and for whom?"
- "What would users actually do with this?"
- "Is there a simpler alternative that gets 80% of the value?"
- "What happens if we don't build this?"

**Example:** User: "All users should have public pages." Challenge: "A public page needs content to show. What would a non-creator put there?" — may surface that the feature isn't needed yet.

## Asking Questions

This is a conversation, not a form. The goal is to understand deeply before proposing anything.

- **One question at a time** — don't overwhelm. If a topic needs more exploration, break it into follow-up questions across multiple turns. Each question gets its own AskUserQuestion.
- **Multiple choice preferred** — offer 2-4 discrete options when possible. Easier to answer than open-ended, and forces you to think through the option space. Include an "Other" escape hatch.
- **Follow the thread** — when the user's answer reveals something interesting or unexpected, follow up on that before moving to the next topic. The best design insights come from the second or third follow-up, not the first question.
- **Visual questions** (layout, flow, UI behavior): one at a time. For simple cases, inline markdown diagrams suffice. For UX-heavy features, produce proper HTML+CSS wireframes (step 5b) — text-based mockups can't capture interaction flow, spacing, or responsive behavior.
- **Ambiguous concepts**: explain the difference between interpretations, offer them as options

## Depth Scaling

Match investigation depth to feature scope. Don't spend 10 questions on a config change, but don't rush a multi-service architecture change in 3.

**Small scope** (config change, utility function, single-file fix): 2-4 questions. Focus on: what exactly, any edge cases, how to test.

**Medium scope** (new feature, new component, API endpoint): 5-8 questions. Also explore: who uses it and how, error handling strategy, interaction with existing code, performance constraints.

**Large scope** (multi-service change, new subsystem, architectural shift): 8-15+ questions. Also investigate:
- Read relevant existing code in depth before asking — understand current patterns, abstractions, and pain points
- Failure modes and recovery strategies
- Migration path from current state
- Impact on existing consumers/APIs
- Data model implications
- Operational concerns (monitoring, rollback, deployment)
- Security boundaries affected

For large scope: don't just ask the user — also investigate the codebase yourself between questions. Read the modules you'll be touching, trace call paths, check test coverage. Bring what you learn back to the user: "I looked at the auth module and noticed it uses middleware chaining — should we follow that pattern or is this a chance to improve it?"

## Presenting the Design

- Scale sections to complexity (few sentences to 200-300 words)
- Ask after each section: "Does this look right?"
- Cover: architecture, components, data flow, error handling, testing
- Note shared foundations as **phasing candidates**

**Phasing** (after all sections):
- Simple: "Single phase, no dependency layers. Sound right?"
- Complex: "N dependency layers. Phase 1 — [name], Phase 2 — ... Adjust?"

Use AskUserQuestion with "Looks good" / "Adjust phases" options.

## Design Doc Contents

Authoritative section list, canonical order, conditional-section triggers, and cross-reference rules live in **See:** `design-spec.md`. Run `validate-design --check <path>` (step 9) to enforce structure mechanically. Conditional sections to include based on context: **Wireframes** + **E2E Acceptance Scenarios** + **E2E Tooling** for UI features (per step 5b); **Test Coverage** when `coverage_mode != off`. For multi-phase features, Implementation Approach includes phase rationale.
