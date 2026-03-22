# Guard bash: non-git commands are not blocked

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"npm test"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "npm test outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"cargo build"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "cargo build outside worktree" "$out"
