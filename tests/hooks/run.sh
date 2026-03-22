#!/bin/bash
# Test runner for hook guard scripts.
# Usage: ./tests/hooks/run.sh
set +H

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/plugins/zuggie/hooks"
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

PASS=0
FAIL=0
TOTAL=0

assert_blocked() {
  local test_name="$1"
  local output="$2"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -q '"decision":"block"'; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: block"
    echo "    got:      '${output:-<empty>}'"
    FAIL=$((FAIL + 1))
  fi
}

assert_allowed() {
  local test_name="$1"
  local output="$2"
  TOTAL=$((TOTAL + 1))
  if [ -z "$output" ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: allow (no output)"
    echo "    got:      '$output'"
    FAIL=$((FAIL + 1))
  fi
}

run_suite() {
  local suite="$1"
  echo "--- $suite ---"
  source "$TESTS_DIR/$suite"
  echo ""
}

# Run all test suites
for suite in "$TESTS_DIR"/test_*.sh; do
  run_suite "$(basename "$suite")"
done

# Summary
echo "=== Results ==="
echo "Passed: $PASS / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed: $FAIL"
  exit 1
else
  echo "All tests passed."
fi
