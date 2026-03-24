---
name: zuggie
description: >
  Full planning, implementation, and review pipeline using zuggie agents.
  TRIGGER when: user asks to "implement using zuggie", "use zuggie",
  "implement with zuggie", or references the zuggie workflow for
  implementing a task.
version: 1.0.0
---

Run the full planning, implementation, and review pipeline.

Usage: /zuggie <task description>

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
  actual code, identifies files, and produces the milestone breakdown.
  Without it you are guessing.
- **NEVER write or edit code yourself.** All code changes go through
  zuggie-engineer agents.

## Bash rules

These apply to you (the orchestrator) and all agents you spawn.

- Do not chain Bash commands with `&&` or `;` — run each command as a
  separate Bash call so failures are visible. Piping output to another
  command (e.g. `cmd | grep`) is fine.

**You MUST include the following block verbatim in the prompt of every
agent you spawn** (tech-lead, engineer, reviewer — no exceptions):

> **Bash rules — follow these exactly:**
> - Do not chain Bash commands with `&&` or `;` — run each command as a
>   separate Bash call so failures are visible. Piping output to another
>   command (e.g. `cmd | grep`) is fine.

## Pipeline

### Step 1 — Worktree

If on main or master, create a worktree with a descriptive branch name
(e.g. `feature/auth-refresh`, `fix/null-check`):

    git worktree add .zuggie/<branch-name> -b <branch-name>
    cd .zuggie/<branch-name>

All subsequent steps run inside this worktree.

Record these values — you will need them throughout the pipeline:
- `BASE_BRANCH`: the branch you were on before creating the worktree
  (e.g. `main`)
- `FEATURE_BRANCH`: the new branch name (e.g. `feature/auth-refresh`)

### Step 2 — Plan (MANDATORY — DO NOT SKIP)

Spawn `zuggie:zuggie-tech-lead` with:
- The task description (verbatim from the user)
- Any prior conversation context relevant to the task
- Current branch name and worktree path

Wait for the plan. Verify it includes at least one milestone with file
lists and steps. Do NOT proceed to step 3 until you have received the
tech-lead's plan.

If the plan contains **exploration milestones** (type: exploration),
go to step 2a before proceeding.

### Step 2a — Exploration (only if the plan includes exploration milestones)

For each exploration milestone, spawn `zuggie:zuggie-engineer` with the
exploration milestone. The engineer investigates and reports findings
(no code changes expected).

Once all exploration milestones complete, re-invoke `zuggie:zuggie-tech-lead`
with:
- The original task description
- The exploration findings from each engineer
- The previous plan (for reference)

The tech-lead will produce a revised plan with concrete implementation
milestones. Use the revised plan for all subsequent steps.

### Step 3 — Create milestone worktrees

If the plan has **more than one milestone**, create a sub-worktree for
each independent milestone:

    git worktree add .zuggie/<FEATURE_BRANCH>-ms-<N> -b <FEATURE_BRANCH>-ms-<N> <FEATURE_BRANCH>

where `<N>` is the milestone number (1, 2, …). Do NOT cd into these —
stay in the feature worktree. Do NOT create worktrees for dependent
milestones yet (see step 4).

If the plan has **exactly one milestone**, skip this step — the single
engineer works directly on the feature branch worktree.

### Step 4 — Implement + per-milestone review

For each milestone, run the implement-review-triage cycle:

**a. Implement** — spawn `zuggie:zuggie-engineer` with:
- Working directory: the milestone worktree path
  (`.zuggie/<FEATURE_BRANCH>-ms-<N>`), or the feature worktree
  if single milestone
- The full plan (so the engineer has context)
- Its specific milestone (title, files, steps)
- The original task description
- The branch name to work on

**b. Review** — after the engineer completes, spawn
`zuggie:zuggie-reviewer` with:
- The original task description
- The tech-lead's plan
- The engineer's summary
- Output of `git diff <FEATURE_BRANCH>...<FEATURE_BRANCH>-ms-<N>`
  (or `git diff <BASE_BRANCH>...HEAD` if single milestone)

**c. Triage** the review:
- **Blocking**: spawn `zuggie:zuggie-engineer` in the same milestone
  worktree to fix. Pass the reviewer's issue description as the
  milestone, plus the relevant files.
- **Minor/nit**: defer unless the fix is a one-line change.
- Only re-review if the reviewer's verdict was "request changes".

**Parallelism**: launch independent milestones (dependencies: "none")
in parallel — each runs its own implement-review-triage cycle
concurrently.

**Dependent milestones**: after the dependency's cycle completes:
1. Merge the dependency's branch into the **feature branch** (NOT main):
   `cd` to the feature worktree, then
   `git merge <FEATURE_BRANCH>-ms-<dep> --no-edit`
2. Create the dependent milestone's worktree:
   `git worktree add .zuggie/<FEATURE_BRANCH>-ms-<N> -b <FEATURE_BRANCH>-ms-<N> <FEATURE_BRANCH>`
3. Launch the dependent milestone's implement-review-triage cycle.

If an engineer reports a blocking issue, stop the pipeline and surface
it to the user.

### Step 5 — Merge milestones

Only if sub-worktrees were created:

a. `cd` into the feature worktree.
b. For each milestone branch not yet merged:
   `git merge <FEATURE_BRANCH>-ms-<N> --no-edit`
   **Target is always the FEATURE_BRANCH, never main/master.**
c. If a merge produces conflicts:
   - `git merge --abort`
   - Spawn `zuggie:zuggie-engineer` in the feature worktree to manually
     apply and resolve the changes. Provide:
     - The diff: `git diff <FEATURE_BRANCH>...<FEATURE_BRANCH>-ms-<N>`
     - The list of conflicting files
     - The milestone description
d. Clean up each sub-worktree:

       git worktree remove .zuggie/<FEATURE_BRANCH>-ms-<N>
       git branch -d <FEATURE_BRANCH>-ms-<N>

### Step 6 — Final unified review

Spawn `zuggie:zuggie-reviewer` with:
- The original task description
- The tech-lead's plan
- All engineer summaries
- Output of `git diff <BASE_BRANCH>...HEAD` on the feature branch

This review focuses on cross-milestone integration: consistency,
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
