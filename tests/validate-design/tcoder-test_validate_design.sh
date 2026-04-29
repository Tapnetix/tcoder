#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE="$REPO_ROOT/bin/validate-design"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

assert_pass() {
  local desc="$1"; shift
  local out
  if out=$("$@" 2>&1); then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    echo "$out" | sed 's/^/  /'
    ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"; shift
  local expected_error="$1"; shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: $desc (expected failure, got success)"
    ((FAIL++)) || true
  elif echo "$output" | grep -q "$expected_error"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc (expected '$expected_error' in output, got: $output)"
    ((FAIL++)) || true
  fi
}

echo "=== validate-design tests ==="

echo "Test 1: Valid design (UI feature) passes"
assert_pass "valid UI design passes" \
  "$VALIDATE" --check "$FIXTURES/valid-design.md"

echo "Test 2: Valid design (no UI) passes"
assert_pass "valid non-UI design passes" \
  "$VALIDATE" --check "$FIXTURES/valid-design-no-ui.md"

echo "Test 3: Missing section fails"
assert_fail "missing_section detected" "missing_section.*Goal" \
  "$VALIDATE" --check "$FIXTURES/missing-section.md"

echo "Test 4: Bad section order fails"
assert_fail "section_order detected" "section_order" \
  "$VALIDATE" --check "$FIXTURES/bad-order.md"

echo "Test 5: Empty section fails"
assert_fail "empty_section detected" "empty_section.*Key Decisions" \
  "$VALIDATE" --check "$FIXTURES/empty-section.md"

echo "Test 6: Cross-reference mismatch fails"
assert_fail "cross_ref_mismatch detected" "cross_ref_mismatch.*src/extra.ts" \
  "$VALIDATE" --check "$FIXTURES/cross-ref-mismatch.md"

echo "Test 7: Non-goal rationale too short fails"
assert_fail "non_goal_rationale detected" "non_goal_rationale" \
  "$VALIDATE" --check "$FIXTURES/no-rationale.md"

echo "Test 8: Scope Estimate missing task count fails"
assert_fail "missing task in scope" "missing_scope_estimate.*task" \
  "$VALIDATE" --check "$FIXTURES/missing-task-count.md"

echo "Test 9: Scope Estimate missing phase count fails"
assert_fail "missing phase in scope" "missing_scope_estimate.*phase" \
  "$VALIDATE" --check "$FIXTURES/missing-phase-count.md"

echo "Test 10: Wireframes present without E2E Acceptance Scenarios fails"
assert_fail "wireframes without scenarios" "missing_e2e_scenarios" \
  "$VALIDATE" --check "$FIXTURES/wireframes-no-scenarios.md"

echo "Test 11: Wireframes present without E2E Tooling fails"
assert_fail "wireframes without tooling" "missing_e2e_tooling" \
  "$VALIDATE" --check "$FIXTURES/wireframes-no-tooling.md"

echo "Test 12: Wireframe listed but not referenced by any scenario fails"
assert_fail "orphan wireframe detected" "orphan_wireframe.*wireframes/02-settings.html" \
  "$VALIDATE" --check "$FIXTURES/orphan-wireframe.md"

echo "Test 13: Scenario references a wireframe not in Wireframes section fails"
assert_fail "orphan scenario reference detected" "orphan_scenario_wireframe.*wireframes/99-ghost.html" \
  "$VALIDATE" --check "$FIXTURES/orphan-scenario.md"

echo "Test 14a: Scenario Allocation good fixture passes"
assert_pass "scenario-allocation good passes" \
  "$VALIDATE" --check "$FIXTURES/scenario-allocation/good.md"

echo "Test 14b: Scenario Allocation missing section fails"
assert_fail "missing_scenario_allocation detected" "missing_scenario_allocation" \
  "$VALIDATE" --check "$FIXTURES/scenario-allocation/missing-section.md"

echo "Test 14c: Scenario Allocation malformed scenario ID fails"
assert_fail "malformed_scenario_id detected" "malformed_scenario_id" \
  "$VALIDATE" --check "$FIXTURES/scenario-allocation/malformed-id.md"

echo "Test 14d: Scenario Allocation empty label fails"
assert_fail "empty_scenario_label detected" "empty_scenario_label" \
  "$VALIDATE" --check "$FIXTURES/scenario-allocation/empty-label.md"

echo "Test 14e: Scenario Allocation orphan label fails"
assert_fail "orphan_allocation_label detected" "orphan_allocation_label" \
  "$VALIDATE" --check "$FIXTURES/scenario-allocation/orphan-label.md"

echo "Test 14f: Scenario Allocation duplicate labels passes (info only)"
assert_pass "scenario-allocation duplicate labels passes" \
  "$VALIDATE" --check "$FIXTURES/scenario-allocation/duplicate-label.md"

echo "Test 14: No args exits with usage"
if "$VALIDATE" > /dev/null 2>&1; then
  echo "FAIL: no args should exit non-zero"
  ((FAIL++)) || true
else
  echo "PASS: no args exits non-zero"
  ((PASS++)) || true
fi

echo "Test 15: --check without path exits with usage"
assert_fail "missing path arg" "Usage" \
  "$VALIDATE" --check

echo "Test 16: --check with nonexistent file fails gracefully"
assert_fail "nonexistent file detected" "file not found" \
  "$VALIDATE" --check "/nonexistent/design.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
