Create a git worktree for the current task and switch to it.

Usage: /zuggie:wt <branch-name> [--from <base-branch>] [--no-cd]

Options:
- `--from <base-branch>`: Branch the new worktree from `<base-branch>`
  instead of the current branch. Uses `<base-branch>` as the start
  point for `git worktree add`.
- `--no-cd`: Create the worktree but do NOT cd into it. Skips the
  stash/pop offer. Useful when creating multiple worktrees without
  leaving the current directory.

Steps:
1. If no branch name is given, ask the user what they are working on
   and suggest a descriptive branch name.
2. Determine the base branch:
   - If `--from <base-branch>` is provided, use `<base-branch>`.
   - Otherwise, capture the current branch with
     `git branch --show-current`.
3. Create the worktree:
   - With `--from`: `git worktree add .claude/zuggie/<branch-name> -b <branch-name> <base-branch>`
   - Without `--from`: `git worktree add .claude/zuggie/<branch-name> -b <branch-name>`
4. Tell the user the path of the new worktree.
5. If `--no-cd` is NOT set:
   - cd into the new worktree: `cd .claude/zuggie/<branch-name>`
   - If there are uncommitted changes on the current branch, offer to
     stash and pop them into the new worktree.
6. Confirm with: git worktree list
