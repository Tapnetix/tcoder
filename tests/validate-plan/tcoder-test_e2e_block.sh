#!/usr/bin/env bash
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

# Build an e2e-enabled plan as a jq transform on top of valid-plan fixture.
# - Adds e2e block
# - Marks phase-A task A1 as kind=e2e-red with spec file in files.create
# - Makes phase-B task B1 the e2e-green task with empty create/modify
seed_e2e_plan() {
  local dir="$1"
  rm -rf "${dir:?}/"*
  cp -r "$FIXTURES/valid-plan/"* "$dir/"
  jq '
    .e2e = {
      "command": "npx playwright test",
      "spec_files": ["tests/e2e/flow.spec.ts"],
      "scenarios": [{"name": "user can log in", "wireframe": "wireframes/01-login.html"}]
    }
    | .phases[0].tasks[0].kind = "e2e-red"
    | .phases[0].tasks[0].files.create = ["tests/e2e/flow.spec.ts"]
    | .phases[1].tasks[-1].kind = "e2e-green"
    | .phases[1].tasks[-1].files.create = []
    | .phases[1].tasks[-1].files.modify = []
  ' "$FIXTURES/valid-plan/plan.json" > "$dir/plan.json"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== e2e block schema tests ==="

echo "Test 1: Valid e2e plan passes"
seed_e2e_plan "$TMPDIR"
assert_pass "valid e2e plan passes" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 2: Missing e2e.command"
seed_e2e_plan "$TMPDIR"
jq '.e2e.command = ""' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "empty e2e.command fails" "empty_e2e_command" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 3: Empty e2e.spec_files"
seed_e2e_plan "$TMPDIR"
jq '.e2e.spec_files = []' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "empty e2e.spec_files fails" "empty_e2e_spec_files" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 4: Empty e2e.scenarios"
seed_e2e_plan "$TMPDIR"
jq '.e2e.scenarios = []' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "empty e2e.scenarios fails" "empty_e2e_scenarios" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 5: Missing e2e-red task kind"
seed_e2e_plan "$TMPDIR"
jq 'del(.phases[0].tasks[0].kind)' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "missing e2e-red task fails" "missing_e2e_red_task" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 6: Missing e2e-green task kind"
seed_e2e_plan "$TMPDIR"
jq 'del(.phases[1].tasks[-1].kind)' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "missing e2e-green task fails" "missing_e2e_green_task" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 7: e2e-red not first task of first phase"
seed_e2e_plan "$TMPDIR"
jq '
  .phases[0].tasks[0].kind = null
  | del(.phases[0].tasks[0].kind)
  | .phases[0].tasks[1].kind = "e2e-red"
  | .phases[0].tasks[1].files.create += ["tests/e2e/flow.spec.ts"]
  | .phases[0].tasks[0].files.create -= ["tests/e2e/flow.spec.ts"]
' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "e2e-red misplaced fails" "e2e_red_position" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 8: e2e-green not last task of last phase"
seed_e2e_plan "$TMPDIR"
# Add a task AFTER the e2e-green task so green is not last
jq '
  .phases[1].tasks += [{
    "id": "B2",
    "name": "Extra after green",
    "status": "pending",
    "depends_on": [],
    "files": {"create": ["src/extra.ts"], "modify": [], "test": ["tests/extra.test.ts"]},
    "verification": "echo ok",
    "done_when": "done"
  }]
' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
# Create the b2 task stub so orphan checks pass
printf '# B2: Extra after green\n\n## Steps\nnone\n' > "$TMPDIR/phase-b/b2.md"
assert_fail "e2e-green misplaced fails" "e2e_green_position" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 9: e2e-green task has non-empty files.create"
seed_e2e_plan "$TMPDIR"
jq '.phases[1].tasks[-1].files.create = ["src/extra.ts"]' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "e2e-green with create fails" "e2e_green_files_not_empty" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 10: e2e-green task has non-empty files.modify"
seed_e2e_plan "$TMPDIR"
jq '.phases[1].tasks[-1].files.modify = ["src/extra.ts"]' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "e2e-green with modify fails" "e2e_green_files_not_empty" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 11: e2e spec file not in e2e-red.files.create"
seed_e2e_plan "$TMPDIR"
jq '.phases[0].tasks[0].files.create = []' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "spec file missing from e2e-red creates fails" "e2e_spec_not_created" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 12: Another task modifies the e2e spec file"
seed_e2e_plan "$TMPDIR"
jq '.phases[1].tasks[0].files.modify = ["tests/e2e/flow.spec.ts"]' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "non-red task touching spec file fails" "e2e_spec_contamination" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 13: Duplicate e2e-red tasks"
seed_e2e_plan "$TMPDIR"
jq '.phases[0].tasks[1].kind = "e2e-red"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "duplicate e2e-red fails" "duplicate_e2e_red_task" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 14: Duplicate e2e-green tasks"
seed_e2e_plan "$TMPDIR"
jq '
  .phases[1].tasks += [{
    "id": "B2",
    "name": "Second green",
    "status": "pending",
    "depends_on": [],
    "kind": "e2e-green",
    "files": {"create": [], "modify": [], "test": []},
    "verification": "echo ok",
    "done_when": "done"
  }]
' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
printf '# B2: Second green\n\n## Steps\nnone\n' > "$TMPDIR/phase-b/b2.md"
assert_fail "duplicate e2e-green fails" "duplicate_e2e_green_task" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 15: No e2e block, no kind fields — existing valid plan still passes"
rm -rf "${TMPDIR:?}/"*
cp -r "$FIXTURES/valid-plan/"* "$TMPDIR/"
cp "$FIXTURES/valid-plan/plan.json" "$TMPDIR/plan.json"
assert_pass "plan without e2e block passes (backward compat)" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 16: kind field is invalid value"
seed_e2e_plan "$TMPDIR"
jq '.phases[0].tasks[0].kind = "bogus"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "invalid task kind fails" "invalid_task_kind" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
