# Tests for plugins/zuggie/hooks/lib/context.sh

source "$HOOKS_DIR/lib/context.sh"

# Helper: assert a function returns exit code 0
assert_returns_0() {
  local test_name="$1"
  local exit_code="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$exit_code" -eq 0 ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: exit 0"
    echo "    got:      exit $exit_code"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: assert a function returns exit code 1
assert_returns_1() {
  local test_name="$1"
  local exit_code="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$exit_code" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: exit 1"
    echo "    got:      exit $exit_code"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: assert output equals expected
assert_output_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: '$expected'"
    echo "    got:      '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: assert output is empty
assert_output_empty() {
  local test_name="$1"
  local actual="$2"
  TOTAL=$((TOTAL + 1))
  if [ -z "$actual" ]; then
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    expected: empty output"
    echo "    got:      '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# Test 1: zuggie_in_worktree at worktree root returns 0
zuggie_in_worktree "$TEST_ROOT/.claude/zuggie/feature"
assert_returns_0 "zuggie_in_worktree at worktree root" $?

# Test 2: zuggie_in_worktree in subdirectory returns 0 (walks up)
zuggie_in_worktree "$TEST_ROOT/.claude/zuggie/feature/src"
assert_returns_0 "zuggie_in_worktree in worktree subdirectory" $?

# Test 3: zuggie_in_worktree outside worktree returns 1
zuggie_in_worktree "$TEST_ROOT"
assert_returns_1 "zuggie_in_worktree outside worktree" $?

# Test 4: zuggie_worktree_root from worktree root prints worktree root path
out=$(zuggie_worktree_root "$TEST_ROOT/.claude/zuggie/feature")
assert_output_eq "zuggie_worktree_root from worktree root" "$TEST_ROOT/.claude/zuggie/feature" "$out"

# Test 5: zuggie_worktree_root from subdirectory prints worktree root (not subdir)
out=$(zuggie_worktree_root "$TEST_ROOT/.claude/zuggie/feature/src")
assert_output_eq "zuggie_worktree_root from subdirectory" "$TEST_ROOT/.claude/zuggie/feature" "$out"

# Test 6: zuggie_worktree_root outside worktree returns 1, no output
out=$(zuggie_worktree_root "$TEST_ROOT" 2>/dev/null)
rc=$?
assert_returns_1 "zuggie_worktree_root outside worktree returns 1" $rc
assert_output_empty "zuggie_worktree_root outside worktree no output" "$out"

# Test 7: zuggie_read_context returns valid JSON with branch and base_branch
out=$(zuggie_read_context "$TEST_ROOT/.claude/zuggie/feature")
branch=$(echo "$out" | jq -r '.branch // empty')
base_branch=$(echo "$out" | jq -r '.base_branch // empty')
TOTAL=$((TOTAL + 1))
if [ "$branch" = "feature" ] && [ "$base_branch" = "main" ]; then
  PASS=$((PASS + 1))
else
  echo "  FAIL: zuggie_read_context returns valid JSON with branch and base_branch"
  echo "    expected: branch=feature, base_branch=main"
  echo "    got:      branch=$branch, base_branch=$base_branch"
  FAIL=$((FAIL + 1))
fi
