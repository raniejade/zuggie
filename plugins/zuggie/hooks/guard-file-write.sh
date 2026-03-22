#!/bin/bash
# Block Edit/Write to files outside the worktree when cwd is inside one.
# Only applies to zuggie agents.
input=$(cat)
agent=$(echo "$input" | jq -r '.agent_type // empty')

# Only guard zuggie agents
case "$agent" in
  zuggie-engineer|zuggie-tech-lead|zuggie-reviewer) ;;
  *) exit 0 ;;
esac

path=$(echo "$input" | jq -r '.tool_input.file_path')
cwd=$(echo "$input" | jq -r '.cwd // empty')

if echo "$cwd" | grep -q '\.claude/zuggie/' && ! echo "$path" | grep -q '/\.claude/zuggie/'; then
  echo '{"decision":"block","reason":"You are in a worktree but editing a file outside it. Use the worktree copy of this file instead."}'
fi
