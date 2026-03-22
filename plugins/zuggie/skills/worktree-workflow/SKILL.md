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

    git worktree add ../<repo>-<branch-name> -b <branch-name>
    cd ../<repo>-<branch-name>

Name branches descriptively: feature/auth-refresh, fix/null-check.

## Listing worktrees

    git worktree list

## Finishing up

    # From inside the worktree
    git add -A && git commit -m "..."

    # Back in the main repo
    cd ../main-repo
    git merge <branch-name>
    git worktree remove ../<repo>-<branch-name>

## If you have uncommitted work on main

    git stash
    git worktree add ../<repo>-<branch-name> -b <branch-name>
    cd ../<repo>-<branch-name>
    git stash pop
