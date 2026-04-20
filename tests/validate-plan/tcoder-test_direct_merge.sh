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

seed_plan() {
  local dir="$1"
  rm -rf "${dir:?}/"*
  cp -r "$FIXTURES/valid-plan/"* "$dir/"
  cp "$FIXTURES/valid-plan/plan.json" "$dir/plan.json"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== direct-merge workflow tests ==="

echo "Test 1: direct-merge is a valid workflow value (schema accepts it)"
seed_plan "$TMPDIR"
jq '.workflow = "direct-merge"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_pass "schema accepts direct-merge workflow" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 2: bogus workflow value still rejected"
seed_plan "$TMPDIR"
jq '.workflow = "magic-merge"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
assert_fail "schema rejects unknown workflow" "invalid_workflow" \
  "$VALIDATE" --schema "$TMPDIR/plan.json"

echo "Test 3: check-workflow for direct-merge — missing design-review fails"
seed_plan "$TMPDIR"
jq '.workflow = "direct-merge" | .status = "Complete"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
# Write a reviews.json with impl-review only, no design-review
cat > "$TMPDIR/reviews.json" <<'EOF'
[
  {"type":"plan-review","scope":"plan","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-a","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-b","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"final","verdict":"pass","remaining":0}
]
EOF
assert_fail "direct-merge requires design-review" "design-review not passed" \
  "$VALIDATE" --check-workflow "$TMPDIR/plan.json"

echo "Test 4: check-workflow for direct-merge — missing plan-review fails"
seed_plan "$TMPDIR"
jq '.workflow = "direct-merge" | .status = "Complete"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
cat > "$TMPDIR/reviews.json" <<'EOF'
[
  {"type":"design-review","scope":"design","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-a","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-b","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"final","verdict":"pass","remaining":0}
]
EOF
assert_fail "direct-merge requires plan-review" "plan-review not passed" \
  "$VALIDATE" --check-workflow "$TMPDIR/plan.json"

echo "Test 5: check-workflow for direct-merge — missing impl-review fails"
seed_plan "$TMPDIR"
jq '.workflow = "direct-merge" | .status = "Complete"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
cat > "$TMPDIR/reviews.json" <<'EOF'
[
  {"type":"design-review","scope":"design","verdict":"pass","remaining":0},
  {"type":"plan-review","scope":"plan","verdict":"pass","remaining":0}
]
EOF
assert_fail "direct-merge requires impl-review per phase" "impl-review phase-a" \
  "$VALIDATE" --check-workflow "$TMPDIR/plan.json"

echo "Test 6: check-workflow for direct-merge — plan status not Complete fails"
seed_plan "$TMPDIR"
jq '.workflow = "direct-merge" | .status = "In Development"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
cat > "$TMPDIR/reviews.json" <<'EOF'
[
  {"type":"design-review","scope":"design","verdict":"pass","remaining":0},
  {"type":"plan-review","scope":"plan","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-a","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-b","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"final","verdict":"pass","remaining":0}
]
EOF
assert_fail "direct-merge requires plan status Complete" "plan status is 'In Development'" \
  "$VALIDATE" --check-workflow "$TMPDIR/plan.json"

echo "Test 7: check-workflow for direct-merge — passes with all reviews + Complete status (no PR required)"
seed_plan "$TMPDIR"
jq '.workflow = "direct-merge" | .status = "Complete"' "$TMPDIR/plan.json" > "$TMPDIR/p.json" && mv "$TMPDIR/p.json" "$TMPDIR/plan.json"
cat > "$TMPDIR/reviews.json" <<'EOF'
[
  {"type":"design-review","scope":"design","verdict":"pass","remaining":0},
  {"type":"plan-review","scope":"plan","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-a","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"phase-b","verdict":"pass","remaining":0},
  {"type":"impl-review","scope":"final","verdict":"pass","remaining":0}
]
EOF
assert_pass "direct-merge passes without any PR existence check" \
  "$VALIDATE" --check-workflow "$TMPDIR/plan.json"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
