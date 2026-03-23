Run the full planning, implementation, and review pipeline.

Usage: /zuggie:implement <task description>

## Your role

You are the **orchestrator**. You coordinate the pipeline by spawning
agents (via the Agent tool) and managing git branches. You do NOT:
- Write or edit application code yourself
- Skip steps because you think you already know the answer
- Act as the tech-lead, engineer, or reviewer — you delegate to them

Every step below that says "spawn" means: use the **Agent tool** with
the appropriate `subagent_type` (e.g. `zuggie:zuggie-tech-lead`).
Do not simulate the agent's work or summarise what you think it would
produce — actually spawn it.

## Hard rules — no exceptions

- **NEVER merge anything into main or master.** All work happens on
  feature branches. The user merges to main themselves.
- **NEVER skip the Plan step.** You MUST spawn zuggie-tech-lead even if
  you think you already understand the task. The tech-lead reads the
  actual code, identifies files, and produces the workstream breakdown.
  Without it you are guessing.
- **NEVER write or edit code yourself.** All code changes go through
  zuggie-engineer agents.

## Pipeline

### Step 1 — Worktree

If on main or master, run `/zuggie:wt <branch-name>` with a descriptive
name (e.g. `feature/auth-refresh`, `fix/null-check`).

cd into `.claude/zuggie/<branch-name>`. All subsequent steps run inside
this worktree.

Record these values — you will need them throughout the pipeline:
- `BASE_BRANCH`: the branch you were on before creating the worktree
  (e.g. `main`)
- `FEATURE_BRANCH`: the new branch name (e.g. `feature/auth-refresh`)

### Step 2 — Plan (MANDATORY — DO NOT SKIP)

Spawn `zuggie:zuggie-tech-lead` with:
- The task description (verbatim from the user)
- Any prior conversation context relevant to the task
- Current branch name and worktree path

Wait for the plan. Verify it includes at least one workstream with file
lists and steps. Do NOT proceed to step 3 until you have received the
tech-lead's plan.

### Step 3 — Create workstream worktrees

If the plan has **more than one workstream**, create a sub-worktree for
each independent workstream:
```
/zuggie:wt <FEATURE_BRANCH>-ws-<N> --from <FEATURE_BRANCH> --no-cd
```
where `<N>` is the workstream number (1, 2, …). Do NOT create worktrees
for dependent workstreams yet (see step 4).

If the plan has **exactly one workstream**, skip this step — the single
engineer works directly on the feature branch worktree.

### Step 4 — Implement + per-workstream review

For each workstream, run the implement-review-triage cycle:

**a. Implement** — spawn `zuggie:zuggie-engineer` with:
- Working directory: the workstream worktree path
  (`.claude/zuggie/<FEATURE_BRANCH>-ws-<N>`), or the feature worktree
  if single workstream
- The full plan (so the engineer has context)
- Its specific workstream (title, files, steps)
- The original task description
- The branch name to use with `/zuggie:wt-cd`

**b. Review** — after the engineer completes, spawn
`zuggie:zuggie-reviewer` with:
- The original task description
- The tech-lead's plan
- The engineer's summary
- Output of `git diff <FEATURE_BRANCH>...<FEATURE_BRANCH>-ws-<N>`
  (or `git diff <BASE_BRANCH>...HEAD` if single workstream)

**c. Triage** the review:
- **Blocking**: spawn `zuggie:zuggie-engineer` in the same workstream
  worktree to fix. Pass the reviewer's issue description as the
  workstream, plus the relevant files.
- **Minor/nit**: defer unless the fix is a one-line change.
- Only re-review if the reviewer's verdict was "request changes".

**Parallelism**: launch independent workstreams (dependencies: "none")
in parallel — each runs its own implement-review-triage cycle
concurrently.

**Dependent workstreams**: after the dependency's cycle completes:
1. Merge the dependency's branch into the **feature branch** (NOT main):
   `cd` to the feature worktree, then
   `git merge <FEATURE_BRANCH>-ws-<dep> --no-edit`
2. Create the dependent workstream's worktree:
   `/zuggie:wt <FEATURE_BRANCH>-ws-<N> --from <FEATURE_BRANCH> --no-cd`
3. Launch the dependent workstream's implement-review-triage cycle.

If an engineer reports a blocking issue, stop the pipeline and surface
it to the user.

### Step 5 — Merge workstreams

Only if sub-worktrees were created:

a. `cd` into the feature worktree.
b. For each workstream branch not yet merged:
   `git merge <FEATURE_BRANCH>-ws-<N> --no-edit`
   **Target is always the FEATURE_BRANCH, never main/master.**
c. If a merge produces conflicts:
   - `git merge --abort`
   - Spawn `zuggie:zuggie-engineer` in the feature worktree to manually
     apply and resolve the changes. Provide:
     - The diff: `git diff <FEATURE_BRANCH>...<FEATURE_BRANCH>-ws-<N>`
     - The list of conflicting files
     - The workstream description
d. Clean up each sub-worktree:
   `git worktree remove .claude/zuggie/<FEATURE_BRANCH>-ws-<N>`
   `git branch -d <FEATURE_BRANCH>-ws-<N>`

### Step 6 — Final unified review

Spawn `zuggie:zuggie-reviewer` with:
- The original task description
- The tech-lead's plan
- All engineer summaries
- Output of `git diff <BASE_BRANCH>...HEAD` on the feature branch

This review focuses on cross-workstream integration: consistency,
missing connections, conflicting patterns.

Triage as usual:
- **Blocking**: spawn `zuggie:zuggie-engineer` in the feature worktree
  to fix. Pass the reviewer's issue description plus relevant files.
- **Minor/nit**: defer unless the fix is a one-line change.
- Only re-review if the verdict was "request changes".

### Step 7 — Report

Present to the user:
- What was implemented (1-3 sentences)
- Reviewer verdict and how you handled any issues
- Deferred issues with reasoning

Ask if they want changes or are happy to proceed.
