Run the full planning, implementation, and review pipeline.

Usage: /zuggie:implement <task description>

Can be invoked by the user directly or by the main agent when a
conversation has converged on a clear plan.

Pipeline:

1. Worktree check — if on main or master, create a worktree before
   doing anything else by running `/zuggie:wt <branch-name>`.
   Pick a descriptive branch name (e.g. feature/auth-refresh,
   fix/null-check).

2. Plan — invoke the zuggie-tech-lead agent with:
   - The task description
   - Any prior conversation context relevant to the plan
   - Contents of relevant files identified so far
   - Current branch and worktree context
   Wait for zuggie-tech-lead to return a plan and workstream breakdown.

3. Implement — for each workstream in the plan, invoke a zuggie-engineer agent.
   Pass each zuggie-engineer:
   - The full plan
   - Its specific workstream
   - The files it will need (read and pass contents)
   - The original task description verbatim
   Spawn zuggie-engineer agents in parallel for independent workstreams.
   Wait for all to complete before proceeding.

4. Review — invoke the zuggie-reviewer agent with:
   - The original task description
   - The zuggie-tech-lead's plan
   - A summary of what each zuggie-engineer did
   - Full output of git diff

5. Triage — for each issue the zuggie-reviewer raised, decide whether to fix
   it now or defer. Blocking issues should be fixed now. Minor issues
   and nits are deferred unless trivial to address. Invoke zuggie-engineer
   agents as needed for fixes, same as step 3.

6. Ask the user for feedback. Present:
   - A short summary of what was implemented
   - What the reviewer flagged and how you handled it
   - Any deferred issues with your reasoning
   Ask if they are happy to proceed or want changes.
