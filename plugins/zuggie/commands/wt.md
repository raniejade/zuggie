Create a git worktree for the current task and switch to it.

Usage: /zuggie:wt <branch-name>

Steps:
1. If no branch name is given, ask the user what they are working on
   and suggest a descriptive branch name.
2. Run: git worktree add .claude/zuggie/<branch-name> -b <branch-name>
3. Write the context file. First capture the current branch with
   `git branch --show-current` for base_branch, then run:
   `jq -n --arg wt ".claude/zuggie/<branch-name>" --arg br "<branch-name>" --arg base "<current-branch>" '{worktree_path:$wt,branch:$br,base_branch:$base}' > .claude/zuggie/<branch-name>/.zuggie-context.json`
4. Exclude the context file from git:
   `grep -qxF '.zuggie-context.json' .git/info/exclude 2>/dev/null || echo '.zuggie-context.json' >> .git/info/exclude`
5. Tell the user the path of the new worktree.
6. cd into the new worktree: `cd .claude/zuggie/<branch-name>`
7. If there are uncommitted changes on the current branch, offer to
   stash and pop them into the new worktree.
8. Confirm with: git worktree list
