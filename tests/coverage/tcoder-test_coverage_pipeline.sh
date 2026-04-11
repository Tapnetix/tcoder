#!/usr/bin/env bash
set -euo pipefail

# Verify that coverage enforcement is wired through the entire pipeline:
# design → draft-plan → plan-review → orchestrate → task-review → implementation-review

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

assert_contains() {
  local desc="$1" file="$2" pattern="$3"
  if grep -q "$pattern" "$file"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc (pattern '$pattern' not found in $file)"
    ((FAIL++)) || true
  fi
}

assert_not_contains() {
  local desc="$1" file="$2" pattern="$3"
  if grep -q "$pattern" "$file"; then
    echo "FAIL: $desc (pattern '$pattern' unexpectedly found in $file)"
    ((FAIL++)) || true
  else
    echo "PASS: $desc"
    ((PASS++)) || true
  fi
}

echo "=== defaults.json coverage settings ==="

assert_contains "coverage_mode defined" \
  "$REPO_ROOT/defaults.json" '"coverage_mode"'
assert_contains "coverage_threshold defined" \
  "$REPO_ROOT/defaults.json" '"coverage_threshold"'
assert_contains "coverage_mode is enum" \
  "$REPO_ROOT/defaults.json" '"off", "advisory", "enforce"'
assert_contains "coverage_mode default is enforce" \
  "$REPO_ROOT/defaults.json" '"default": "enforce"'
assert_contains "coverage_threshold default is 90" \
  "$REPO_ROOT/defaults.json" '"default": 90'

echo ""
echo "=== schema-reference.md coverage object ==="

SCHEMA_REF="$REPO_ROOT/skills/draft-plan/schema-reference.md"
assert_contains "coverage object in schema example" \
  "$SCHEMA_REF" '"coverage"'
assert_contains "coverage.command field documented" \
  "$SCHEMA_REF" 'command.*string.*required'
assert_contains "coverage.threshold field documented" \
  "$SCHEMA_REF" 'threshold.*integer.*required'
assert_contains "coverage.baseline field documented" \
  "$SCHEMA_REF" 'baseline.*integer or null.*required'

echo ""
echo "=== design skill detects coverage ==="

DESIGN="$REPO_ROOT/skills/design/SKILL.md"
assert_contains "design reads coverage_mode" \
  "$DESIGN" 'coverage_mode'
assert_contains "design detects coverage tooling" \
  "$DESIGN" 'coverage tooling'
assert_contains "design doc has Test Coverage section" \
  "$DESIGN" 'Test Coverage'

echo ""
echo "=== draft-plan wires coverage into plans ==="

DRAFT="$REPO_ROOT/skills/draft-plan/SKILL.md"
assert_contains "draft-plan references coverage object" \
  "$DRAFT" 'coverage.*object in plan.json'
assert_contains "draft-plan mentions coverage-setup task" \
  "$DRAFT" 'coverage-setup task'
assert_contains "draft-plan mentions coverage verification step" \
  "$DRAFT" 'coverage verification'

echo ""
echo "=== plan-drafter agent references coverage ==="

DRAFTER="$REPO_ROOT/agents/plan-drafter.md"
assert_contains "plan-drafter checks design doc for Test Coverage" \
  "$DRAFTER" 'Test Coverage'

echo ""
echo "=== plan-reviewer checks coverage ==="

PLAN_REV="$REPO_ROOT/agents/plan-reviewer.md"
assert_contains "plan-reviewer checks coverage.command" \
  "$PLAN_REV" 'coverage.command'
assert_contains "plan-reviewer checks coverage.threshold" \
  "$PLAN_REV" 'coverage.threshold'
assert_contains "plan-reviewer checks coverage.baseline" \
  "$PLAN_REV" 'coverage.baseline'
assert_contains "plan-reviewer flags missing coverage-setup task" \
  "$PLAN_REV" 'no coverage-setup task'
assert_contains "plan-reviewer flags missing coverage verification steps" \
  "$PLAN_REV" 'tasks lack coverage verification'

PLAN_SKILL="$REPO_ROOT/skills/plan-review/SKILL.md"
assert_contains "plan-review skill mentions coverage" \
  "$PLAN_SKILL" 'coverage'

echo ""
echo "=== orchestrate reads coverage settings ==="

ORCH="$REPO_ROOT/skills/orchestrate/SKILL.md"
assert_contains "orchestrate reads coverage_mode" \
  "$ORCH" 'COVERAGE_MODE.*tcoder-settings get coverage_mode'
assert_contains "orchestrate reads coverage_threshold" \
  "$ORCH" 'COVERAGE_THRESHOLD.*tcoder-settings get coverage_threshold'
assert_contains "orchestrate reads coverage command from plan.json" \
  "$ORCH" 'COVERAGE_CMD.*coverage.command'
assert_contains "orchestrate has coverage gate in phase wrap-up" \
  "$ORCH" 'Coverage gate'

echo ""
echo "=== implementer prompt includes coverage ==="

IMPL_PROMPT="$REPO_ROOT/skills/orchestrate/implementer-prompt.md"
assert_contains "implementer prompt has COVERAGE_MODE variable" \
  "$IMPL_PROMPT" '{COVERAGE_MODE}'
assert_contains "implementer prompt has COVERAGE_CMD variable" \
  "$IMPL_PROMPT" '{COVERAGE_CMD}'
assert_contains "implementer prompt has COVERAGE_THRESHOLD variable" \
  "$IMPL_PROMPT" '{COVERAGE_THRESHOLD}'
assert_contains "implementer prompt has Coverage section" \
  "$IMPL_PROMPT" '## Coverage'
assert_contains "implementer prompt explains enforce mode" \
  "$IMPL_PROMPT" 'enforce'
assert_contains "implementer prompt explains advisory mode" \
  "$IMPL_PROMPT" 'advisory'

echo ""
echo "=== task-reviewer checks coverage ==="

TASK_REV="$REPO_ROOT/agents/task-reviewer.md"
assert_contains "task-reviewer has 8-point checklist" \
  "$TASK_REV" '8-Point Checklist'
assert_contains "task-reviewer has Coverage Gate check" \
  "$TASK_REV" 'Coverage Gate'
assert_contains "task-reviewer enforce mode produces Critical" \
  "$TASK_REV" 'enforce.*Critical'
assert_contains "task-reviewer advisory mode produces Moderate" \
  "$TASK_REV" 'advisory.*Moderate'
assert_contains "task-reviewer assessment table has coverage row" \
  "$TASK_REV" 'Coverage gate'

TASK_PROMPT="$REPO_ROOT/skills/orchestrate/task-reviewer-prompt.md"
assert_contains "task-reviewer prompt has 8-point reference" \
  "$TASK_PROMPT" '8-point checklist'
assert_contains "task-reviewer prompt has Coverage section" \
  "$TASK_PROMPT" '## Coverage'
assert_contains "task-reviewer prompt passes COVERAGE_MODE" \
  "$TASK_PROMPT" '{COVERAGE_MODE}'

echo ""
echo "=== implementation-reviewer checks coverage ==="

IMPL_REV="$REPO_ROOT/agents/implementation-reviewer.md"
assert_contains "impl-reviewer mentions coverage threshold" \
  "$IMPL_REV" 'coverage.*threshold'
assert_contains "impl-reviewer mentions baseline comparison" \
  "$IMPL_REV" 'baseline'
assert_contains "impl-reviewer enforce mode regression is Critical" \
  "$IMPL_REV" 'enforce.*Critical'
assert_contains "impl-reviewer advisory mode is Moderate" \
  "$IMPL_REV" 'advisory.*Moderate'
assert_contains "impl-reviewer includes coverage summary instruction" \
  "$IMPL_REV" 'Coverage.*threshold.*baseline'

IMPL_REV_PROMPT="$REPO_ROOT/skills/implementation-review/reviewer-prompt.md"
assert_contains "impl-reviewer prompt has COVERAGE_BASELINE" \
  "$IMPL_REV_PROMPT" '{COVERAGE_BASELINE}'
assert_contains "impl-reviewer prompt has Coverage section" \
  "$IMPL_REV_PROMPT" '## Coverage'
assert_contains "impl-reviewer prompt mentions regression detection" \
  "$IMPL_REV_PROMPT" 'regression'

echo ""
echo "=== tcoder-settings skill documents coverage ==="

SETTINGS_SKILL="$REPO_ROOT/skills/tcoder-settings/SKILL.md"
assert_contains "settings skill lists coverage_mode" \
  "$SETTINGS_SKILL" 'coverage_mode'
assert_contains "settings skill lists coverage_threshold" \
  "$SETTINGS_SKILL" 'coverage_threshold'

echo ""
echo "=== no stale caliper references in coverage-related content ==="

for f in "$DESIGN" "$DRAFT" "$DRAFTER" "$PLAN_REV" "$PLAN_SKILL" "$ORCH" \
         "$IMPL_PROMPT" "$TASK_REV" "$TASK_PROMPT" "$IMPL_REV" "$IMPL_REV_PROMPT" \
         "$SETTINGS_SKILL" "$SCHEMA_REF"; do
  assert_not_contains "no caliper in $(basename "$f")" "$f" "caliper"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
