#!/usr/bin/env bash
# End-to-end exercise of validate-plan against full plan trees. Covers
# render + update-status flow (against the non-E2E valid-plan fixture) and
# multi-phase deterministic spec-path derivation for the schema-2 e2e
# pipeline. Per-rule unit cases live in the focused tcoder-test_*.sh files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE="$REPO_ROOT/bin/validate-plan"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc (expected '$expected', got '$actual')"
    ((FAIL++)) || true
  fi
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cp -r "$FIXTURES/valid-plan/"* "$TMPDIR/"

check "initial schema validation" "$VALIDATE" --schema "$TMPDIR/plan.json"

rm -f "$TMPDIR/plan.md"
check "initial render" "$VALIDATE" --render "$TMPDIR/plan.json"
check "plan.md exists after render" test -f "$TMPDIR/plan.md"

"$VALIDATE" --update-status "$TMPDIR/plan.json" --plan --status "In Development"
assert_eq "plan status" "In Development" "$(jq -r '.status' "$TMPDIR/plan.json")"

"$VALIDATE" --update-status "$TMPDIR/plan.json" --phase A --status "In Progress"

"$VALIDATE" --update-status "$TMPDIR/plan.json" --task A1 --status in_progress
printf '[{"type":"task-review","scope":"A1","verdict":"pass","remaining":0}]' > "$TMPDIR/reviews.json"
"$VALIDATE" --update-status "$TMPDIR/plan.json" --task A1 --status complete
"$VALIDATE" --update-status "$TMPDIR/plan.json" --task A2 --status in_progress
printf '[{"type":"task-review","scope":"A1","verdict":"pass","remaining":0},{"type":"task-review","scope":"A2","verdict":"pass","remaining":0}]' > "$TMPDIR/reviews.json"
"$VALIDATE" --update-status "$TMPDIR/plan.json" --task A2 --status complete

echo "# A1 Completion" > "$TMPDIR/phase-a/a1-completion.md"
echo "# A2 Completion" > "$TMPDIR/phase-a/a2-completion.md"

printf '[{"type":"task-review","scope":"A1","verdict":"pass","remaining":0},{"type":"task-review","scope":"A2","verdict":"pass","remaining":0},{"type":"impl-review","scope":"phase-a","verdict":"pass","remaining":0}]' > "$TMPDIR/reviews.json"
"$VALIDATE" --update-status "$TMPDIR/plan.json" --phase A --status "Complete (2026-03-19)"

assert_eq "A1 complete" "complete" "$(jq -r '.phases[0].tasks[0].status' "$TMPDIR/plan.json")"
assert_eq "A2 complete" "complete" "$(jq -r '.phases[0].tasks[1].status' "$TMPDIR/plan.json")"
check "plan.md has [x] A1" grep -q '\[x\] A1' "$TMPDIR/plan.md"
check "plan.md has [x] A2" grep -q '\[x\] A2' "$TMPDIR/plan.md"
check "plan.md has Complete" grep -q 'Complete (2026-03-19)' "$TMPDIR/plan.md"

check "schema validates after updates" "$VALIDATE" --schema "$TMPDIR/plan.json"

cp "$TMPDIR/plan.md" "$TMPDIR/plan-before.md"
"$VALIDATE" --render "$TMPDIR/plan.json"
check "render idempotent after updates" diff -q "$TMPDIR/plan-before.md" "$TMPDIR/plan.md"

# ---------------------------------------------------------------------------
# Multi-phase schema-2 e2e plan: scenarios distributed across two phases,
# with deterministic spec paths derived from runner + spec_dir + task id.
# These cases ensure validate-plan walks all phases (not just phase A) when
# resolving e2e_scenarios ownership and spec-path matching.
# ---------------------------------------------------------------------------

build_multiphase_plan() {
  local dir="$1" runner="$2" ext="$3"
  rm -rf "${dir:?}/"*
  mkdir -p "$dir/phase-a" "$dir/phase-b"
  : > "$dir/phase-a/completion.md"
  : > "$dir/phase-b/completion.md"
  echo "# A1: Open and render a markdown file"   > "$dir/phase-a/a1.md"
  echo "# B1: Add comment to a selection"        > "$dir/phase-b/b1.md"

  cat > "$dir/design-multiphase.md" <<'MD'
# Multiphase design

## E2E Acceptance Scenarios

- S1: open and render
- S2: add comment

## Scenario Allocation

| Scenario | Task label |
|---|---|
| S1 | Open and render a markdown file |
| S2 | Add comment to a selection |
MD

  jq -n --arg runner "$runner" --arg a1spec "e2e/a1${ext}" --arg b1spec "e2e/b1${ext}" '
    {
      schema: 2,
      status: "In Development",
      workflow: "direct-merge",
      execution_mode: "subagents",
      goal: "multiphase",
      architecture: "two-phase",
      tech_stack: "ts",
      phases: [
        {
          letter: "A",
          name: "First",
          status: "Not Started",
          depends_on: [],
          rationale: "phase A owns S1",
          tasks: [{
            id: "A1",
            name: "Open and render a markdown file",
            status: "pending",
            depends_on: [],
            files: { create: [$a1spec], modify: [], test: [] },
            verification: "v",
            done_when: "d",
            e2e_scenarios: ["S1"]
          }]
        },
        {
          letter: "B",
          name: "Second",
          status: "Not Started",
          depends_on: ["A"],
          rationale: "phase B owns S2",
          tasks: [{
            id: "B1",
            name: "Add comment to a selection",
            status: "pending",
            depends_on: ["A1"],
            files: { create: [$b1spec], modify: [], test: [] },
            verification: "v",
            done_when: "d",
            e2e_scenarios: ["S2"]
          }]
        }
      ],
      e2e: {
        command: "run-tests",
        runner: $runner,
        spec_dir: "e2e/",
        scenarios: [
          { id: "S1", name: "open and render" },
          { id: "S2", name: "add comment" }
        ]
      }
    }' > "$dir/plan.json"
}

echo ""
echo "=== Multi-phase deterministic spec-path tests ==="

echo "Test: playwright runner, scenarios across two phases"
MULTI_DIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR" "$MULTI_DIR"' EXIT
build_multiphase_plan "$MULTI_DIR" "playwright" ".spec.ts"
check "playwright multi-phase plan validates" \
  "$VALIDATE" --schema "$MULTI_DIR/plan.json"

echo "Test: pytest runner, scenarios across two phases"
build_multiphase_plan "$MULTI_DIR" "pytest" "_test.py"
check "pytest multi-phase plan validates" \
  "$VALIDATE" --schema "$MULTI_DIR/plan.json"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
