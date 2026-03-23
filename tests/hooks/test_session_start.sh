# Tests for plugins/zuggie/hooks/init-context.sh

SESSION_START="$HOOKS_DIR/init-context.sh"

# Helper: assert env file contains a line matching pattern
assert_env_contains() {
  local test_name="$1"
  local pattern="$2"
  local env_file="$3"
  TOTAL=$((TOTAL + 1))
  if grep -q "$pattern" "$env_file" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected env file to contain: $pattern"
    echo "    env file contents:"
    cat "$env_file" 2>/dev/null | sed 's/^/      /'
    FAIL=$((FAIL + 1))
  fi
}

# Helper: assert env file does NOT contain a line matching pattern
assert_env_not_contains() {
  local test_name="$1"
  local pattern="$2"
  local env_file="$3"
  TOTAL=$((TOTAL + 1))
  if ! grep -q "$pattern" "$env_file" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected env file NOT to contain: $pattern"
    echo "    env file contents:"
    cat "$env_file" 2>/dev/null | sed 's/^/      /'
    FAIL=$((FAIL + 1))
  fi
}

# Test 1: Run from worktree cwd with CLAUDE_ENV_FILE set
# → env file contains ZUGGIE_BRANCH, ZUGGIE_BASE_BRANCH, ZUGGIE_WORKTREE_ROOT, ZUGGIE_AGENT_ID
env_file=$(mktemp)
input="{\"agent_id\":\"test-agent-123\",\"cwd\":\"$TEST_ROOT/.claude/zuggie/feature\"}"
echo "$input" | CLAUDE_ENV_FILE="$env_file" bash "$SESSION_START"

assert_env_contains "worktree: ZUGGIE_BRANCH exported" "ZUGGIE_BRANCH" "$env_file"
assert_env_contains "worktree: ZUGGIE_BASE_BRANCH exported" "ZUGGIE_BASE_BRANCH" "$env_file"
assert_env_contains "worktree: ZUGGIE_WORKTREE_ROOT exported" "ZUGGIE_WORKTREE_ROOT" "$env_file"
assert_env_contains "worktree: ZUGGIE_AGENT_ID exported" "ZUGGIE_AGENT_ID" "$env_file"
rm -f "$env_file"

# Test 2: Run from non-worktree cwd with CLAUDE_ENV_FILE set
# → env file only has ZUGGIE_AGENT_ID (no worktree vars)
env_file=$(mktemp)
input="{\"agent_id\":\"test-agent-456\",\"cwd\":\"$TEST_ROOT\"}"
echo "$input" | CLAUDE_ENV_FILE="$env_file" bash "$SESSION_START"

assert_env_contains "non-worktree: ZUGGIE_AGENT_ID exported" "ZUGGIE_AGENT_ID" "$env_file"
assert_env_not_contains "non-worktree: ZUGGIE_BRANCH not exported" "ZUGGIE_BRANCH" "$env_file"
assert_env_not_contains "non-worktree: ZUGGIE_BASE_BRANCH not exported" "ZUGGIE_BASE_BRANCH" "$env_file"
assert_env_not_contains "non-worktree: ZUGGIE_WORKTREE_ROOT not exported" "ZUGGIE_WORKTREE_ROOT" "$env_file"
rm -f "$env_file"

# Test 3: Run with CLAUDE_ENV_FILE unset → exits cleanly (exit 0), no errors
input="{\"agent_id\":\"test-agent-789\",\"cwd\":\"$TEST_ROOT/.claude/zuggie/feature\"}"
echo "$input" | bash "$SESSION_START"
rc=$?
TOTAL=$((TOTAL + 1))
if [ "$rc" -eq 0 ]; then
  PASS=$((PASS + 1))
else
  echo "  FAIL: unset CLAUDE_ENV_FILE exits cleanly"
  echo "    expected: exit 0"
  echo "    got:      exit $rc"
  FAIL=$((FAIL + 1))
fi
