# Task Reviewer Invocation Template

Use this template when dispatching a task-reviewer agent. The agent's static behavior (8-point checklist, output format, severity guide, review-summary format) is defined in the `tcoder:task-reviewer` agent definition. This template provides only the dynamic per-invocation context.

## Variables

- `{TASK_ID}` — the task ID
- `{TASK_SPEC}` — task metadata + prose combined
- `{TASK_COMPLETION_FILE}` — path to implementer's completion notes
- `{REPO_PATH}` — implementer's worktree path
- `{BASE_SHA}` — SHA before task started
- `{HEAD_SHA}` — SHA after task completed
- `{TASK_REVIEWER_MODEL}` — model for the reviewer agent (from tcoder-settings)
- `{COVERAGE_MODE}` — `off`, `advisory`, or `enforce` (from tcoder-settings). Omit the Coverage section below when `off` or when plan.json has no `coverage` object.
- `{COVERAGE_CMD}` — shell command to run coverage (from plan.json `coverage.command`)
- `{COVERAGE_THRESHOLD}` — minimum coverage percentage (from tcoder-settings)
- `{E2E_MODE}` — `off`, `advisory`, or `enforce` (from tcoder-settings). Omit the E2E section below when `off` or when `task.e2e_scenarios` is empty.
- `{E2E_SPEC_PATH}` — deterministic spec path `<e2e.spec_dir>/<task_id_lower><ext>` derived by the orchestrator from plan.json
- `{E2E_SCENARIO_IDS}` — comma-separated scenario IDs the task owns (e.g. `S1, S2`)
- `{E2E_FILTERED_CMD}` — the per-runner filtered command the implementer was instructed to run (built from `plan.e2e.command` plus the filter form for the runner; see the runner/filter table in `skills/orchestrate/SKILL.md`)

## Dispatch Example

```text
Agent(
  subagent_type: "tcoder:task-reviewer",
  model: "{TASK_REVIEWER_MODEL}",
  prompt: "You are reviewing task {TASK_ID}.

    ## Task Specification

    {TASK_SPEC}

    ## Implementer Completion Notes

    Read {TASK_COMPLETION_FILE} for the implementer's self-reported summary.
    Do not trust the notes at face value. Verify every claim by reading actual code.

    ## Git Range

    The code is at {REPO_PATH}

    git diff --stat {BASE_SHA}..{HEAD_SHA}
    git diff {BASE_SHA}..{HEAD_SHA}

    Read every file in the diff.

    ## Coverage  <!-- include this section only when COVERAGE_MODE is not 'off' and COVERAGE_CMD is set -->

    Coverage mode: {COVERAGE_MODE} | Threshold: {COVERAGE_THRESHOLD}%
    Coverage command: {COVERAGE_CMD}
    Run coverage scoped to files touched by this task and evaluate against the threshold.

    ## E2E Gate Verification  <!-- include this section only when E2E_MODE is not 'off' and task.e2e_scenarios is non-empty -->

    E2E mode: {E2E_MODE}
    Spec path (deterministic): {E2E_SPEC_PATH}
    Scenarios owned by this task: {E2E_SCENARIO_IDS}
    Filtered command the implementer was instructed to run: {E2E_FILTERED_CMD}

    The agent definition (agents/task-reviewer.md, point 9) lists the full check; this dispatch supplies the per-task values. Confirm:
    1. The spec file exists at {E2E_SPEC_PATH}.
    2. Every scenario ID in {E2E_SCENARIO_IDS} appears as a test-name PREFIX in the form `S<n>:` (case-sensitive, colon required) — not as a suffix or substring.
    3. The task's commit history (git log {BASE_SHA}..{HEAD_SHA}) shows {E2E_FILTERED_CMD} running with a green verdict — for example, an implementer note or commit message recording the green run.

    When {E2E_MODE} is `enforce`, missing evidence of the green run is a Critical finding. When `advisory`, the same gap is a Warning."
)
```

Note: The agent definition sets `background: true` by default. In subagents mode, the dispatch explicitly overrides with `run_in_background: false` so the lead waits synchronously for results. In agent-teams mode, the default applies.
