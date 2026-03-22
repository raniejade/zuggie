# Guard bash: read-only git commands are always allowed

out=$(echo '{"agent_type":"zuggie-tech-lead","tool_input":{"command":"git log --oneline -10"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git log outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-tech-lead","tool_input":{"command":"git diff HEAD~1"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git diff outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-tech-lead","tool_input":{"command":"git status"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git status outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-tech-lead","tool_input":{"command":"git branch --show-current"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git branch outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-tech-lead","tool_input":{"command":"git rev-parse --abbrev-ref HEAD"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git rev-parse outside worktree" "$out"
