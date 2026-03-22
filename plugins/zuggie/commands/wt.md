Create a git worktree for the current task and switch to it.

Usage: /zuggie:wt <branch-name>

Steps:
1. If no branch name is given, ask the user what they are working on
   and suggest a descriptive branch name.
2. Run: git worktree add .claude/zuggie/<branch-name> -b <branch-name> # zuggie:wt
3. Tell the user the path of the new worktree.
4. Remind them to cd into it to continue working there.
5. If there are uncommitted changes on the current branch, offer to
   stash and pop them into the new worktree.
6. Confirm with: git worktree list
