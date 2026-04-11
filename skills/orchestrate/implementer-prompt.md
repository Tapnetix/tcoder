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

    ## Before You Begin

    Mark your task in-progress:
    validate-plan --update-status {PLAN_DIR}/plan.json --task {TASK_ID} --status in_progress"
)
```
