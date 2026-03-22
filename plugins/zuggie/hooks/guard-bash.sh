#!/bin/bash
# Guard git commands to ensure worktree discipline.
set +H

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command')

# Block direct git worktree add that bypasses /zuggie:wt (always enforced)
if echo "$cmd" | grep -q 'git worktree add' && ! echo "$cmd" | grep -q '\.claude/zuggie/'; then
  echo '{"decision":"block","reason":"Use /zuggie:wt instead of git worktree add directly."}'
  exit 0
fi

# Remaining guards only apply to zuggie agents
agent=$(echo "$input" | jq -r '.agent_type // empty')
case "$agent" in
  zuggie-engineer|zuggie-tech-lead|zuggie-reviewer) ;;
  *) exit 0 ;;
esac

# Block mutating git commands when not in a worktree
cwd=$(echo "$input" | jq -r '.cwd // empty')
if ! echo "$cwd" | grep -q '\.claude/zuggie/' && echo "$cmd" | grep -qE 'git\s+(commit|add|push|merge|rebase|reset|cherry-pick|rm|mv|restore|clean)'; then
  echo '{"decision":"block","reason":"Mutating git commands must run inside a worktree. cd into .claude/zuggie/<branch> first."}'
fi
