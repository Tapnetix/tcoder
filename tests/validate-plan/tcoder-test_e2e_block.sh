#!/usr/bin/env bash
# Schema-2 e2e block shape tests. Exercises the rules that govern the
# top-level `e2e` object (command, runner, spec_dir, scenarios) — not the
# per-task e2e_scenarios behaviour, which lives in tcoder-test_e2e_scenarios.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE="$REPO_ROOT/bin/validate-plan"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

assert_pass() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc (expected pass, got:"
    "$@" 2>&1 | sed 's/^/  /'
    echo ")"
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

# Seed a working schema-2 e2e plan into $1 by copying baseline-good. The
# fixture defines two tasks (A1, A2), one scenario each, runner=playwright,
# spec_dir=e2e/, and a matching design-baseline.md for the label check.
seed_baseline() {
  local dir="$1"
  rm -rf "${dir:?}/"*
  cp -r "$FIXTURES/baseline-good/"* "$dir/"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== e2e block schema tests (schema 2) ==="

echo "Test 1: Happy path — full e2e block with playwright runner"
seed_baseline "$TMPDIR"
assert_pass "valid e2e plan passes" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 2: Empty e2e.command"
seed_baseline "$TMPDIR"
jq '.e2e.command = ""' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "empty e2e.command fails" "empty_e2e_command" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 3: Invalid e2e.runner (webdriver)"
seed_baseline "$TMPDIR"
jq '.e2e.runner = "webdriver"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "unknown runner fails" "invalid_e2e_runner" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 4: Missing e2e.runner"
seed_baseline "$TMPDIR"
jq 'del(.e2e.runner)' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "missing runner fails" "invalid_e2e_runner" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 5: Missing e2e.spec_dir defaults to e2e/"
seed_baseline "$TMPDIR"
jq 'del(.e2e.spec_dir)' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
# Baseline already places spec files under e2e/, so the default should pass.
assert_pass "missing spec_dir defaults to e2e/" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 6: Empty e2e.scenarios"
seed_baseline "$TMPDIR"
jq '.e2e.scenarios = []' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "empty e2e.scenarios fails" "empty_e2e_scenarios" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 7: Scenario missing id field"
seed_baseline "$TMPDIR"
jq '.e2e.scenarios[0] = {"name": "no id here"}' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "scenario without id fails" "missing_scenario_id" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
