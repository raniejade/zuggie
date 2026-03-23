# Guard bash: worktree creation guard is always enforced (not agent-scoped)

out=$(echo '{"tool_input":{"command":"git worktree add /tmp/wt -b feature"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-worktree-creation.sh")
assert_blocked "zuggie agent: git worktree add wrong path" "$out"

out=$(echo '{"tool_input":{"command":"git worktree add /tmp/wt -b feature"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-worktree-creation.sh")
assert_blocked "no agent: git worktree add wrong path" "$out"

out=$(echo '{"tool_input":{"command":"git worktree add /tmp/wt -b feature"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-worktree-creation.sh")
assert_blocked "non-zuggie agent: git worktree add wrong path" "$out"

out=$(echo '{"tool_input":{"command":"git worktree add .claude/zuggie/feature -b feature"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-worktree-creation.sh")
assert_allowed "git worktree add via zuggie path" "$out"
