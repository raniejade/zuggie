---
name: worktree-workflow
description: >
  Reference guide for git worktree usage. Load when creating,
  switching, or cleaning up worktrees, or when advising on
  worktree-based workflow.
version: 1.0.0
---

# Git worktree workflow

## When to use a worktree

Use a worktree for any non-trivial task: new features, bug fixes,
refactors, or anything spanning more than one or two files. Trivial
work (single typo, comment fix, README tweak) can stay on the
current branch.

## Creating a worktree

    git worktree add .claude/zuggie/<branch-name> -b <branch-name>
    cd .claude/zuggie/<branch-name>

Name branches descriptively: feature/auth-refresh, fix/null-check.

## Listing worktrees

    git worktree list

## Finishing up

    # From inside the worktree
    git add -A && git commit -m "..."

    # Clean up the worktree (do NOT merge back to main/master)
    git worktree remove .claude/zuggie/<branch-name>

**Important:** Never merge the branch back into main/master unless the
user explicitly asks you to. Leave the branch as-is for the user to
merge via PR or however they prefer.

## If you have uncommitted work on main

    git stash
    git worktree add .claude/zuggie/<branch-name> -b <branch-name>
    cd .claude/zuggie/<branch-name>
    git stash pop
