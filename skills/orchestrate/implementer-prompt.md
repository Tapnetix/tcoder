# Implementer Invocation Template

Use this template when dispatching a task-implementer agent. The agent's static behavior (test-driven workflow, deviation rules, self-review, completion notes) is defined in the `tcoder:task-implementer` agent definition. This template provides only the dynamic per-invocation context.

**Variables:**
- `{TASK_ID}` — the task ID (e.g., A1)
- `{TASK_ID_LOWER}` — lowercase task ID (e.g., a1)
- `{TASK_METADATA}` — JSON task object from plan.json (strip `status` before injecting — orchestrator tracking state, not implementer guidance; keep `depends_on` — implementer may need it for boundary integration tests)
- `{TASK_PROSE}` — content of the task .md file
- `{PLAN_DIR}` — absolute path to plan directory
- `{PHASE_DIR}` — absolute path to phase directory
- `{TASK_IMPLEMENTER_MODEL}` — model for the implementer agent (from tcoder-settings)
- `{WORKTREE_PATH}` — absolute path to the task's worktree (subagents mode only — orchestrator creates via `git worktree add`). In agent-teams mode, omit this variable — the teammate uses its auto-provisioned CWD.
- `{COVERAGE_MODE}` — `off`, `advisory`, or `enforce` (from tcoder-settings). Omit the Coverage section below when `off` or when plan.json has no `coverage` object.
- `{COVERAGE_CMD}` — shell command to run coverage (from plan.json `coverage.command`)
- `{COVERAGE_THRESHOLD}` — minimum coverage percentage (from tcoder-settings)
- `{E2E_SPEC_PATH}` — deterministic spec path `<e2e.spec_dir>/<task_id_lower><ext>`, derived by the orchestrator from plan.json. Include the E2E section below only when `task.e2e_scenarios` is non-empty.
- `{E2E_RUNNER}` — value of `plan.e2e.runner` (`playwright`, `vitest`, `pytest`, or `cypress`)
- `{E2E_FILTERED_CMD}` — the per-runner filtered command for this task's scenarios; the orchestrator builds it from `plan.e2e.command` plus the filter form for `{E2E_RUNNER}` (see the runner/filter table in `skills/orchestrate/SKILL.md`)

```text
Agent(
  subagent_type: "tcoder:task-implementer",
  model: "{TASK_IMPLEMENTER_MODEL}",
  prompt: "You are implementing {TASK_ID}: [task name]

    ## Task Metadata (from plan.json)

    {TASK_METADATA}

    ## Task Instructions (from task file)

    {TASK_PROSE}

    ## Paths

    Plan directory: {PLAN_DIR}
    Phase directory: {PHASE_DIR}
    Working directory: {WORKTREE_PATH}  <!-- subagents mode only — omit this line in agent-teams mode -->

    ## Coverage  <!-- include this section only when COVERAGE_MODE is not 'off' and COVERAGE_CMD is set -->

    After each TDD green phase, run coverage on your touched files:
    {COVERAGE_CMD}
    Mode: {COVERAGE_MODE} | Threshold: {COVERAGE_THRESHOLD}%
    - advisory: report coverage in your completion notes, aim for threshold but don't block
    - enforce: coverage for touched files must meet threshold; if below, add tests before moving on

    ## E2E Spec  <!-- include this section only when task.e2e_scenarios in {TASK_METADATA} is non-empty -->

    This task owns the E2E scenarios listed in `e2e_scenarios`. Author the spec as part of your TDD cycle — the spec is task-scoped, not plan-scoped.

    Spec path (deterministic): {E2E_SPEC_PATH}
    Runner: {E2E_RUNNER}
    Filtered command: {E2E_FILTERED_CMD}

    Each scenario in `e2e_scenarios` becomes exactly one test whose name STARTS WITH `S<n>:` (the colon is required and the prefix is case-sensitive). The scenario name from the plan goes after the colon. Examples:
    - playwright/vitest: `test('S1: user signs in', () => { ... })`
    - pytest: `def test_S1_user_signs_in():` — pytest's collection requires the `test_` prefix on functions, so the scenario id is embedded as `test_S<n>_<name>` (no colon). pytest's `-k` filter matches by substring, so the embedded id still hits. The `S<n>:` colon-prefix rule applies to playwright/vitest only.

    Name-based filters (`--grep`, `-t`, `-k`) match these prefixes. Cypress filters by `--spec` instead, which works because the spec path is unique per task.

    Cycle (same red/green/refactor as unit tests, with one extra red/green for the spec):
    1. Write the spec file at {E2E_SPEC_PATH} with one `S<n>:`-prefixed test per scenario.
    2. Run {E2E_FILTERED_CMD} — verify every assertion FAILS (RED). No implementation exists yet.
    3. Implement the feature.
    4. Re-run {E2E_FILTERED_CMD} — verify every assertion PASSES (GREEN).
    5. Commit. The green run must be visible in commit history; the reviewer checks for it.

    Deviation Rule 5 (in your agent definition) restricts you to this single spec file — modifying any other task's spec file requires a Rule 4 escalation. The full rule text lives in `agents/task-implementer.md`.

    ## Before You Begin

    Mark your task in-progress:
    validate-plan --update-status {PLAN_DIR}/plan.json --task {TASK_ID} --status in_progress"
)
```
