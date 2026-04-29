# TDD Reference

## Test Discovery

If the task doesn't specify test patterns, find them:

```bash
ls -la tests/ || ls -la test/ || ls -la *_test.* || ls -la *.test.*
cat pytest.ini 2>/dev/null || cat pyproject.toml 2>/dev/null | grep -A10 tool.pytest
cat package.json 2>/dev/null | grep -A5 '"test"'
pytest --collect-only 2>/dev/null | head -20
```

Match existing patterns (runner, file structure, class vs function style).

## When Tests Fail Unexpectedly

**Test fails when you expected it to pass:**
1. Read the error message completely
2. Check path, function name, import
3. Check dependencies exist (prior task outputs, config files)
4. Fix the root cause, don't patch the test to pass

**Test passes when you expected it to fail:**
1. Assertion is wrong — doesn't test what you think
2. Implementation already exists (check git status)
3. Test is testing a mock, not real behavior

## Boundary Tests

Use real components at cross-task seams, not mocks:

```python
def test_auth_service_fetches_user_from_repository():
    repo = UserRepository(db_connection)  # Real component from Task 1
    auth = AuthService(repo)              # Component from Task 2
    result = auth.authenticate("valid_user", "valid_pass")
    assert result.user_id == expected_id
```

## E2E TDD

When a task carries `e2e_scenarios`, the spec file is part of the TDD cycle — the same red-green-refactor loop applies, with the spec as the failing test. Each task owns exactly one spec file at the deterministic path `<e2e.spec_dir>/<task_id_lower><ext>` (the orchestrator supplies the resolved path in dispatch metadata; do not derive it yourself).

Cycle:

1. **Red.** Write the spec asserting every scenario in `e2e_scenarios`. Each test name starts with `S<n>:` exactly — for example `test('S1: user signs in', ...)` (playwright/vitest) or `def test_S1_user_signs_in():` (pytest). Run the per-runner filtered command supplied in dispatch and verify every assertion fails. No implementation yet.
2. **Green.** Implement the feature. Re-run the same filtered command and verify every assertion passes.
3. **Refactor.** Optional, same as for unit tests. Commit only when green — the green run must be visible in commit history because the reviewer checks for it.

The filter form is runner-specific (`--grep`/`-t`/`-k`/`--spec`); see the runner/filter table in `skills/orchestrate/SKILL.md`. Each task's spec is independent — never edit another task's spec to make your tests pass; that's a Rule 4 escalation.

## Common Failure Modes

| Failure | Fix |
|---------|-----|
| Test passes before implementation | Assertion tests a mock — verify it tests real behavior |
| Test fails after "correct" implementation | Wrong import, path, or assumption — read error completely |
| Refactor breaks tests | Changed behavior, not structure — revert, make smaller changes |
| Tests pass but feature doesn't work | Using mocks at boundaries — use real components |
| Skipped "verify fail" step | Do it every time |
