# Guard bash: non-git commands are not blocked

out=$(echo '{"tool_input":{"command":"npm test"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "npm test outside worktree" "$out"

out=$(echo '{"tool_input":{"command":"cargo build"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "cargo build outside worktree" "$out"
