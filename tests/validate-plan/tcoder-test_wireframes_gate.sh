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
    echo "FAIL: $desc (expected pass)"
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

seed_plan_dir() {
  local dir="$1"
  rm -rf "${dir:?}/"* "${dir:?}"/.wireframes-approved "${dir:?}"/.design-approved
  cp -r "$FIXTURES/valid-plan/"* "$dir/"
  cp "$FIXTURES/valid-plan/plan.json" "$dir/plan.json"
  echo '[{"type":"design-review","scope":"design","verdict":"pass","remaining":0}]' > "$dir/reviews.json"
}

write_design_doc_no_wireframes() {
  cat > "$1/design-feature.md" <<'EOF'
# Design: Feature

## Problem
Something is missing.

## Success Criteria
- Users can do X.

## Architecture
Stuff.
EOF
}

write_design_doc_with_wireframes() {
  cat > "$1/design-feature.md" <<'EOF'
# Design: Feature

## Problem
Something is missing.

## Success Criteria
- Users can do X.

## Wireframes
- wireframes/01-login.html — login screen
- wireframes/02-dashboard.html — dashboard

## Architecture
Stuff.
EOF
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== wireframe entry-gate tests ==="

echo "Test 1: design doc without Wireframes section — no sentinel needed"
seed_plan_dir "$TMPDIR"
write_design_doc_no_wireframes "$TMPDIR"
assert_pass "draft-plan passes without wireframes section" \
  "$VALIDATE" --check-entry "$TMPDIR/plan.json" --stage draft-plan

echo "Test 2: design doc WITH Wireframes section, no sentinel — gate fails"
seed_plan_dir "$TMPDIR"
write_design_doc_with_wireframes "$TMPDIR"
assert_fail "draft-plan fails when wireframes present but not approved" "wireframes_not_approved" \
  "$VALIDATE" --check-entry "$TMPDIR/plan.json" --stage draft-plan

echo "Test 3: design doc WITH Wireframes section + sentinel — gate passes"
seed_plan_dir "$TMPDIR"
write_design_doc_with_wireframes "$TMPDIR"
touch "$TMPDIR/.wireframes-approved"
assert_pass "draft-plan passes when wireframes approved" \
  "$VALIDATE" --check-entry "$TMPDIR/plan.json" --stage draft-plan

echo "Test 4: design doc with Wireframes section but no design-review — generic review gate fails first"
seed_plan_dir "$TMPDIR"
rm -f "$TMPDIR/reviews.json"
write_design_doc_with_wireframes "$TMPDIR"
assert_fail "missing design-review blocks even if wireframes present" "design-review not passed" \
  "$VALIDATE" --check-entry "$TMPDIR/plan.json" --stage draft-plan

echo "Test 5: wireframe section with alternate spelling (## wireframes lowercase) still detected"
seed_plan_dir "$TMPDIR"
cat > "$TMPDIR/design-feature.md" <<'EOF'
# Design

## Problem
x

## wireframes
- a.html
EOF
assert_fail "lowercase wireframes header triggers gate" "wireframes_not_approved" \
  "$VALIDATE" --check-entry "$TMPDIR/plan.json" --stage draft-plan

echo "Test 6: no design-*.md file — gate behaves like before (no wireframe check)"
seed_plan_dir "$TMPDIR"
rm -f "$TMPDIR"/design-*.md
assert_pass "gate passes when no design doc file (backward compatible)" \
  "$VALIDATE" --check-entry "$TMPDIR/plan.json" --stage draft-plan

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
