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

setup_fixtures() {
  TEST_ROOT=$(mktemp -d)
  export TEST_ROOT
  # Create a real git repo so git branch --show-current works
  git init "$TEST_ROOT" >/dev/null 2>&1
  git -C "$TEST_ROOT" commit --allow-empty -m "init" >/dev/null 2>&1
  # Create real worktrees with context files
  git -C "$TEST_ROOT" worktree add "$TEST_ROOT/.claude/zuggie/feature" -b feature >/dev/null 2>&1
  echo '{"branch":"feature","base_branch":"main"}' \
    > "$TEST_ROOT/.claude/zuggie/feature/.zuggie-context.json"
  mkdir -p "$TEST_ROOT/.claude/zuggie/feature/src"
  git -C "$TEST_ROOT" worktree add "$TEST_ROOT/.claude/zuggie/fix-bug" -b fix-bug >/dev/null 2>&1
  echo '{"branch":"fix-bug","base_branch":"main"}' \
    > "$TEST_ROOT/.claude/zuggie/fix-bug/.zuggie-context.json"
  mkdir -p "$TEST_ROOT/.claude/zuggie/fix-bug/src"
  # Non-worktree project root (no context file)
  mkdir -p "$TEST_ROOT/src"
}

teardown_fixtures() {
  # Remove worktrees before deleting the directory
  git -C "$TEST_ROOT" worktree remove "$TEST_ROOT/.claude/zuggie/feature" --force 2>/dev/null
  git -C "$TEST_ROOT" worktree remove "$TEST_ROOT/.claude/zuggie/fix-bug" --force 2>/dev/null
  rm -rf "$TEST_ROOT"
}

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

setup_fixtures
trap teardown_fixtures EXIT

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
