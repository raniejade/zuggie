# Guard bash: block mutating git commands outside worktree

out=$(echo '{"tool_input":{"command":"git commit -m \"fix\""},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git commit outside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git commit -m \"fix\""},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git commit inside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git add -A"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git add outside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git add -A"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/fix-bug"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git add inside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git push origin feature"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git push outside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git push origin feature"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git push inside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git merge feature-branch"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git merge outside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git rebase main"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git rebase outside worktree" "$out"

out=$(echo '{"tool_input":{"command":"git reset --hard HEAD~1"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git reset outside worktree" "$out"
