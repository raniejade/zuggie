# Guard bash: worktree creation guard is always enforced (not agent-scoped)

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git worktree add /tmp/wt -b feature"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "zuggie agent: git worktree add wrong path" "$out"

out=$(echo '{"tool_input":{"command":"git worktree add /tmp/wt -b feature"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "no agent: git worktree add wrong path" "$out"

out=$(echo '{"agent_type":"some-other-agent","tool_input":{"command":"git worktree add /tmp/wt -b feature"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "non-zuggie agent: git worktree add wrong path" "$out"

out=$(echo '{"tool_input":{"command":"git worktree add .claude/zuggie/feature -b feature"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git worktree add via zuggie path" "$out"
