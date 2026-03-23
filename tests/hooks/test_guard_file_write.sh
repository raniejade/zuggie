# Guard file write: block Edit/Write to files outside the worktree when cwd is in one

# Block editing main repo file from worktree cwd
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/src/main.ts"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_blocked "edit main repo file from worktree cwd" "$out"

# Allow editing worktree file from worktree cwd
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/.claude/zuggie/feature/src/main.ts"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "edit worktree file from worktree cwd" "$out"

# Allow editing file from non-worktree cwd (pre-worktree setup)
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/src/main.ts"},"cwd":"'"$TEST_ROOT"'"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "edit file from non-worktree cwd" "$out"

# Write tool: block main repo file from worktree cwd
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/src/new.ts"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_blocked "write main repo file from worktree cwd" "$out"

# Write tool: allow worktree file from worktree cwd
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/.claude/zuggie/feature/src/new.ts"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "write worktree file from worktree cwd" "$out"

# Cross-worktree isolation: cwd in worktree A, file_path in worktree B
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/.claude/zuggie/fix-bug/src/main.ts"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_blocked "cross-worktree: edit worktree B file from worktree A cwd" "$out"

# Subdirectory: cwd in worktree A, file_path in worktree A subdirectory
out=$(echo '{"tool_input":{"file_path":"'"$TEST_ROOT"'/.claude/zuggie/feature/src/deep/nested.ts"},"cwd":"'"$TEST_ROOT"'/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "edit worktree A subdirectory file from worktree A cwd" "$out"
