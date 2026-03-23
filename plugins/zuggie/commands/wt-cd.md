Switch into an existing worktree.

Usage: /zuggie:wt-cd <branch-name>

Steps:
1. If no branch name is given, list worktrees under `.claude/zuggie/`
   and ask which one to enter.
2. Verify the worktree exists: `.claude/zuggie/<branch-name>`
3. cd into it: `cd .claude/zuggie/<branch-name>`
4. Verify you are on the correct branch: `git branch --show-current`
   — it must NOT be main or master. If it is, stop and surface the
   error.
5. Confirm with a short message: "Switched to worktree <branch-name>"
