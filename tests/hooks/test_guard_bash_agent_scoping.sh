# Guard bash: only zuggie agents are guarded

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git commit -m \"fix\""},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "zuggie agent: git commit outside worktree is blocked" "$out"

out=$(echo '{"tool_input":{"command":"git commit -m \"fix\""},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "no agent: git commit outside worktree is allowed" "$out"

out=$(echo '{"agent_type":"some-other-agent","tool_input":{"command":"git commit -m \"fix\""},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "non-zuggie agent: git commit outside worktree is allowed" "$out"
