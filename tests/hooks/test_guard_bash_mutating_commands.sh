# Guard bash: block mutating git commands outside worktree

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git commit -m \"fix\""},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git commit outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git commit -m \"fix\""},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git commit inside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git add -A"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git add outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git add -A"},"cwd":"/project/.claude/zuggie/fix-bug"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git add inside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git push origin feature"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git push outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git push origin feature"},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git push inside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git merge feature-branch"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git merge outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git rebase main"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git rebase outside worktree" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"command":"git reset --hard HEAD~1"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git reset outside worktree" "$out"
