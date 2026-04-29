#!/usr/bin/env bash
# Per-task e2e_scenarios validator coverage. Each fixture is a self-contained
# plan tree under fixtures/e2e-scenarios-*; we feed plan.json to validate-plan
# --schema and assert pass / specific error name as appropriate.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VP="$ROOT/bin/validate-plan"
FIX="$HERE/fixtures"

pass=0
fail=0

assert_pass() {
  local plan="$1" desc="$2"
  if "$VP" --schema "$plan" > /dev/null 2>&1; then
    echo "PASS: $desc"
    ((pass++)) || true
  else
    echo "FAIL: $desc (expected pass, got:"
    "$VP" --schema "$plan" 2>&1 | sed 's/^/  /'
    echo ")"
    ((fail++)) || true
  fi
}

assert_fail() {
  local plan="$1" expected_error="$2" desc="$3"
  local output
  if output=$("$VP" --schema "$plan" 2>&1); then
    echo "FAIL: $desc (expected failure, got success)"
    ((fail++)) || true
  elif echo "$output" | grep -q "$expected_error"; then
    echo "PASS: $desc"
    ((pass++)) || true
  else
    echo "FAIL: $desc (expected '$expected_error' in output, got:"
    echo "$output" | sed 's/^/  /'
    echo ")"
    ((fail++)) || true
  fi
}

assert_pass "$FIX/e2e-scenarios-good/plan.json" \
  "happy path"

assert_fail "$FIX/e2e-scenarios-path-mismatch/plan.json" \
  "missing_e2e_spec_path" \
  "deterministic path mismatch"

assert_fail "$FIX/e2e-scenarios-duplicate-owner/plan.json" \
  "duplicate_scenario_owner" \
  "duplicate scenario ownership"

assert_fail "$FIX/e2e-scenarios-unowned/plan.json" \
  "unowned_scenario" \
  "unowned scenario"

assert_fail "$FIX/e2e-scenarios-no-block/plan.json" \
  "e2e_scenarios_without_block" \
  "scenarios without block"

assert_fail "$FIX/e2e-scenarios-label-mismatch/plan.json" \
  "missing_label_task" \
  "label-to-task-name mismatch"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
