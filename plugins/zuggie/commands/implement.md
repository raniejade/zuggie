Run the full planning, implementation, and review pipeline.

Usage: /zuggie:implement <task description>

Pipeline:

1. **Worktree** — if on main or master, run `/zuggie:wt <branch-name>`
   with a descriptive name (e.g. feature/auth-refresh, fix/null-check).
   cd into `.claude/zuggie/<branch-name>`. All subsequent steps run
   inside the worktree.

2. **Plan** — invoke zuggie-tech-lead with:
   - The task description (verbatim)
   - Any prior conversation context relevant to the task
   - Current branch name and worktree path
   Wait for the plan. Verify it includes at least one workstream
   with file lists and steps.

3. **Implement** — for each workstream, invoke a zuggie-engineer with:
   - Working directory: the worktree path
   - The full plan (so the engineer has context)
   - Its specific workstream (title, files, steps)
   - The original task description
   Launch independent workstreams (dependencies: "none") in parallel.
   Launch dependent workstreams sequentially after their dependencies
   complete.
   If an engineer reports a blocking issue, stop the pipeline and
   surface it to the user.

4. **Review** — invoke zuggie-reviewer with:
   - The original task description
   - The tech-lead's plan
   - Each engineer's summary
   - Output of `git diff main...HEAD` (use the actual base branch)

5. **Triage** — read the reviewer's issues:
   - **Blocking**: invoke zuggie-engineer to fix. Pass the reviewer's
     issue description as the workstream, plus the relevant files.
   - **Minor/nit**: defer unless the fix is a one-line change.
   Only re-review if the reviewer's verdict was "request changes".
   If verdict was "approve with minor fixes", fixes do not need a
   second review pass.

6. **Report** — present to the user:
   - What was implemented (1-3 sentences)
   - Reviewer verdict and how you handled any issues
   - Deferred issues with reasoning
   Ask if they want changes or are happy to proceed.
