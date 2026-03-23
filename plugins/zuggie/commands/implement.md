Run the full planning, implementation, and review pipeline.

Usage: /zuggie:implement <task description>

Pipeline:

1. **Worktree** — if on main or master, run `/zuggie:wt <branch-name>`
   with a descriptive name (e.g. feature/auth-refresh, fix/null-check).
   cd into `.claude/zuggie/<branch-name>`. All subsequent steps run
   inside the worktree. Record the feature branch name for later.

2. **Plan** — invoke zuggie-tech-lead with:
   - The task description (verbatim)
   - Any prior conversation context relevant to the task
   - Current branch name and worktree path
   When referring to files in the repo, always use paths relative to the
   repo root (e.g. `src/auth.ts`, not `/Users/…/src/auth.ts`).
   Wait for the plan. Verify it includes at least one workstream
   with file lists and steps.

3. **Create workstream worktrees** — if the plan has more than one
   workstream, create a sub-worktree for each independent workstream:
   ```
   /zuggie:wt <feature-branch>-ws-<N> --from <feature-branch> --no-cd
   ```
   where `<N>` is the workstream number (1, 2, …). Do NOT create
   worktrees for dependent workstreams yet (see step 4).
   If the plan has exactly one workstream, skip this step — the single
   engineer works directly on the feature branch worktree.

4. **Implement + per-workstream review** — for each workstream, run
   the implement-review-triage cycle:

   a. Invoke zuggie-engineer with:
      - Working directory: the workstream worktree path
        (`.claude/zuggie/<feature-branch>-ws-<N>`), or the feature
        worktree if single workstream
      - The full plan (so the engineer has context)
      - Its specific workstream (title, files, steps)
      - The original task description
      - The branch name to use with `/zuggie:wt-cd`

   b. After the engineer completes, invoke zuggie-reviewer with:
      - The original task description
      - The tech-lead's plan
      - The engineer's summary
      - Output of `git diff <feature-branch>...<feature-branch>-ws-<N>`
        (or `git diff <base-branch>...HEAD` if single workstream)

   c. Triage the review:
      - **Blocking**: invoke zuggie-engineer in the same workstream
        worktree to fix. Pass the reviewer's issue description as the
        workstream, plus the relevant files.
      - **Minor/nit**: defer unless the fix is a one-line change.
      - Only re-review if the reviewer's verdict was "request changes".

   Launch independent workstreams (dependencies: "none") in parallel
   — each runs its own implement-review-triage cycle concurrently.

   For dependent workstreams, after the dependency's cycle completes:
   1. Merge the dependency's branch into the feature branch:
      `cd` to the feature worktree, then
      `git merge <feature-branch>-ws-<dep> --no-edit`
   2. Create the dependent workstream's worktree:
      `/zuggie:wt <feature-branch>-ws-<N> --from <feature-branch> --no-cd`
   3. Launch the dependent workstream's implement-review-triage cycle.

   If an engineer reports a blocking issue, stop the pipeline and
   surface it to the user.

5. **Merge workstreams** — if sub-worktrees were created:
   a. `cd` into the feature worktree.
   b. For each workstream branch not yet merged:
      `git merge <feature-branch>-ws-<N> --no-edit`
   c. If a merge produces conflicts:
      - `git merge --abort`
      - Invoke zuggie-engineer in the feature worktree to manually
        apply and resolve the changes. Provide:
        - The diff: `git diff <feature-branch>...<feature-branch>-ws-<N>`
        - The list of conflicting files
        - The workstream description
   d. Clean up each sub-worktree:
      `git worktree remove .claude/zuggie/<feature-branch>-ws-<N>`
      `git branch -d <feature-branch>-ws-<N>`

6. **Final unified review** — invoke zuggie-reviewer with:
   - The original task description
   - The tech-lead's plan
   - All engineer summaries
   - Output of `git diff <base-branch>...HEAD` on the feature branch
   This review focuses on cross-workstream integration: consistency,
   missing connections, conflicting patterns.
   Triage as usual:
   - **Blocking**: invoke zuggie-engineer in the feature worktree to
     fix. Pass the reviewer's issue description plus relevant files.
   - **Minor/nit**: defer unless the fix is a one-line change.
   Only re-review if the verdict was "request changes".

7. **Report** — present to the user:
   - What was implemented (1-3 sentences)
   - Reviewer verdict and how you handled any issues
   - Deferred issues with reasoning
   Ask if they want changes or are happy to proceed.
