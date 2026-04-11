#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/tcoder-settings"
DEFAULTS_FILE="$REPO_ROOT/defaults.json"
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

check_fail() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "FAIL: $desc (expected failure but succeeded)"
    ((FAIL++)) || true
  else
    echo "PASS: $desc"
    ((PASS++)) || true
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

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc (output did not contain '$needle')"
    ((FAIL++)) || true
  fi
}

setup() {
  TEST_DIR=$(mktemp -d)
  export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"
  export CLAUDE_PLUGIN_DATA="$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

echo "=== coverage_mode setting ==="

echo "Test 1: coverage_mode exists in defaults.json"
setup
mode_type=$(jq -r '.coverage_mode.type' "$DEFAULTS_FILE")
assert_eq "coverage_mode type is enum" "enum" "$mode_type"
teardown

echo "Test 2: coverage_mode default is enforce"
setup
assert_eq "coverage_mode default" "enforce" "$(bash "$SCRIPT" get coverage_mode)"
teardown

echo "Test 3: coverage_mode accepts all valid values"
for val in off advisory enforce; do
  setup
  check "set coverage_mode to $val" bash "$SCRIPT" set coverage_mode "$val"
  assert_eq "get coverage_mode returns $val" "$val" "$(bash "$SCRIPT" get coverage_mode)"
  teardown
done

echo "Test 4: coverage_mode rejects invalid values"
setup
check_fail "coverage_mode rejects 'strict'" bash "$SCRIPT" set coverage_mode strict
check_fail "coverage_mode rejects 'true'" bash "$SCRIPT" set coverage_mode true
check_fail "coverage_mode rejects empty" bash "$SCRIPT" set coverage_mode ""
teardown

echo "Test 5: coverage_mode reset returns to default"
setup
bash "$SCRIPT" set coverage_mode off > /dev/null
assert_eq "after set" "off" "$(bash "$SCRIPT" get coverage_mode)"
bash "$SCRIPT" reset coverage_mode
assert_eq "after reset" "enforce" "$(bash "$SCRIPT" get coverage_mode)"
teardown

echo ""
echo "=== coverage_threshold setting ==="

echo "Test 6: coverage_threshold exists in defaults.json"
setup
threshold_type=$(jq -r '.coverage_threshold.type' "$DEFAULTS_FILE")
assert_eq "coverage_threshold type is int" "int" "$threshold_type"
teardown

echo "Test 7: coverage_threshold default is 90"
setup
assert_eq "coverage_threshold default" "90" "$(bash "$SCRIPT" get coverage_threshold)"
teardown

echo "Test 8: coverage_threshold accepts valid integers"
for val in 0 50 80 95 100; do
  setup
  check "set coverage_threshold to $val" bash "$SCRIPT" set coverage_threshold "$val"
  assert_eq "get coverage_threshold returns $val" "$val" "$(bash "$SCRIPT" get coverage_threshold)"
  teardown
done

echo "Test 9: coverage_threshold rejects non-integers"
setup
check_fail "coverage_threshold rejects 'high'" bash "$SCRIPT" set coverage_threshold high
check_fail "coverage_threshold rejects '90.5'" bash "$SCRIPT" set coverage_threshold 90.5
check_fail "coverage_threshold rejects negative" bash "$SCRIPT" set coverage_threshold -1
teardown

echo "Test 10: coverage_threshold stored as JSON number"
setup
bash "$SCRIPT" set coverage_threshold 95 > /dev/null
stored=$(jq '.coverage_threshold' "$TEST_DIR/settings.json")
assert_eq "threshold stored as number" "95" "$stored"
teardown

echo "Test 11: coverage_threshold reset returns to default"
setup
bash "$SCRIPT" set coverage_threshold 75 > /dev/null
assert_eq "after set" "75" "$(bash "$SCRIPT" get coverage_threshold)"
bash "$SCRIPT" reset coverage_threshold
assert_eq "after reset" "90" "$(bash "$SCRIPT" get coverage_threshold)"
teardown

echo ""
echo "=== coverage settings in list output ==="

echo "Test 12: list shows both coverage settings"
setup
output=$(bash "$SCRIPT" list)
assert_contains "list shows coverage_mode" "$output" "coverage_mode"
assert_contains "list shows coverage_threshold" "$output" "coverage_threshold"
teardown

echo "Test 13: list shows overridden coverage values"
setup
bash "$SCRIPT" set coverage_mode advisory > /dev/null
bash "$SCRIPT" set coverage_threshold 80 > /dev/null
output=$(bash "$SCRIPT" list)
assert_contains "list shows advisory" "$output" "advisory"
assert_contains "list shows 80" "$output" "80"
teardown

echo ""
echo "=== coverage settings source tracking ==="

echo "Test 14: source shows default vs user"
setup
assert_eq "coverage_mode source is default" "default" "$(bash "$SCRIPT" source coverage_mode)"
bash "$SCRIPT" set coverage_mode off > /dev/null
assert_eq "coverage_mode source is user after set" "user" "$(bash "$SCRIPT" source coverage_mode)"
bash "$SCRIPT" reset coverage_mode
assert_eq "coverage_mode source is default after reset" "default" "$(bash "$SCRIPT" source coverage_mode)"
teardown

echo ""
echo "=== coverage settings metadata in defaults.json ==="

echo "Test 15: coverage_mode has correct enum values"
setup
values=$(jq -r '.coverage_mode.values | join(",")' "$DEFAULTS_FILE")
assert_eq "coverage_mode values" "off,advisory,enforce" "$values"
teardown

echo "Test 16: coverage settings have used_by arrays"
setup
mode_used_by=$(jq -r '.coverage_mode.used_by | length' "$DEFAULTS_FILE")
threshold_used_by=$(jq -r '.coverage_threshold.used_by | length' "$DEFAULTS_FILE")
check "coverage_mode used_by is non-empty" test "$mode_used_by" -gt 0
check "coverage_threshold used_by is non-empty" test "$threshold_used_by" -gt 0
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
