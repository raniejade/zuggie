#!/bin/bash
# Block direct git worktree add that bypasses /zuggie:wt (always enforced).
set +H
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command')

if echo "$cmd" | grep -q 'git worktree add' && ! echo "$cmd" | grep -q '\.claude/zuggie/'; then
  echo '{"decision":"block","reason":"Use /zuggie:wt instead of git worktree add directly."}'
fi
