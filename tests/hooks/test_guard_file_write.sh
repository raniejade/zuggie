# Guard file write: block Edit/Write to files outside worktree when cwd is in one

# Agent scoping
out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"file_path":"/project/src/main.ts"},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_blocked "zuggie agent: edit main repo file from worktree cwd" "$out"

out=$(echo '{"tool_input":{"file_path":"/project/src/main.ts"},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "no agent: edit main repo file from worktree cwd (not guarded)" "$out"

# Correct worktree usage
out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"file_path":"/project/.claude/zuggie/feature/src/main.ts"},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "edit worktree file from worktree cwd" "$out"

# Pre-worktree setup (cwd not in worktree)
out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"file_path":"/project/src/main.ts"},"cwd":"/project"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "edit file from non-worktree cwd" "$out"

# Write tool (same logic)
out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"file_path":"/project/src/new.ts"},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_blocked "write main repo file from worktree cwd" "$out"

out=$(echo '{"agent_type":"zuggie-engineer","tool_input":{"file_path":"/project/.claude/zuggie/feature/src/new.ts"},"cwd":"/project/.claude/zuggie/feature"}' | bash "$HOOKS_DIR/guard-file-write.sh")
assert_allowed "write worktree file from worktree cwd" "$out"
