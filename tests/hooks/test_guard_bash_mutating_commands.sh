# Guard bash: block git add/commit on main/master, block other mutating commands outside worktree

# git commit on main branch → blocked
out=$(echo '{"tool_input":{"command":"git commit -m \"fix\""},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git commit on main" "$out"

# git commit on feature branch (worktree) → allowed
out=$(echo '{"tool_input":{"command":"git commit -m \"fix\""},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git commit on feature branch" "$out"

# git add on main branch → blocked
out=$(echo '{"tool_input":{"command":"git add -A"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git add on main" "$out"

# git add on feature branch (worktree) → allowed
out=$(echo '{"tool_input":{"command":"git add -A"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/fix-bug"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git add on feature branch" "$out"

# git push outside worktree → blocked
out=$(echo '{"tool_input":{"command":"git push origin feature"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git push outside worktree" "$out"

# git push inside worktree → allowed
out=$(echo '{"tool_input":{"command":"git push origin feature"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_allowed "git push inside worktree" "$out"

# git merge outside worktree → blocked
out=$(echo '{"tool_input":{"command":"git merge feature-branch"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git merge outside worktree" "$out"

# git rebase outside worktree → blocked
out=$(echo '{"tool_input":{"command":"git rebase main"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git rebase outside worktree" "$out"

# git reset outside worktree → blocked
out=$(echo '{"tool_input":{"command":"git reset --hard HEAD~1"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-bash.sh")
assert_blocked "git reset outside worktree" "$out"
