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

When you need to understand the codebase (e.g. before planning, during
triage), spawn **Explore** agents (`subagent_type: Explore`) rather
than using Glob, Grep, or Read yourself. Explore agents are fast and
cheap — use them freely for recon.

## Hard rules

- **NEVER merge anything into main or master.** All work happens on
  feature branches. The user merges to main themselves.
- **NEVER skip the Plan step.** You MUST spawn zuggie-tech-lead even if
  you think you already understand the task. The tech-lead reads the
  actual code, identifies files, and produces the milestone breakdown.
  Without it you are guessing.
- **NEVER write or edit code yourself.** All code changes go through
  zuggie-engineer agents.
- **NEVER accept a deferral of the main task.** If an engineer's
  summary indicates the core ask was skipped, deferred, or only
  partially done — treat it as a blocking issue. Re-spawn the engineer
  to complete the work. Excuses like "this is complex" or "can be done
  in a follow-up" are not acceptable — the task was already planned and
  scoped.

## Debugging

When you need to debug an issue at any point in the pipeline, invoke
`/zuggie-structured-debug` with a description of the issue instead of
debugging yourself or asking an engineer to debug ad-hoc. The debug
skill runs a full structured pipeline (explore → reproduce → review)
and produces a minimal reproducible example that isolates the root cause.

Use the debug skill's findings to inform next steps — whether that
means re-spawning an engineer with root-cause context or surfacing the
issue to the user.

## Progress tracking

Use `TaskCreate` and `TaskUpdate` to give the user real-time visibility
into the pipeline. Only the orchestrator calls these — agents do not.

Tasks are displayed in creation order, so create them just-in-time to
keep the list intuitive.

### Early pipeline tasks (create before Step 1)

Create these 3 tasks using `TaskCreate` at the very start:

1. **Set up workspace** — activeForm: `Setting up workspace`
2. **Explore codebase** — activeForm: `Exploring codebase`
3. **Create implementation plan** — activeForm: `Planning implementation`
   — blockedBy: task 2

### Milestone tasks (create after Step 2)

After the tech-lead produces the plan, create one task per milestone:
- Subject: `Implement: <milestone title>`
- activeForm: `Implementing <milestone title>`
- blockedBy: the Plan task, plus any milestone dependency tasks

### Late pipeline tasks (create after milestone tasks)

Create these immediately after the milestone tasks so they appear at
the bottom of the list:

1. **Merge milestones** — activeForm: `Merging milestone branches`
   — blockedBy: all milestone tasks
2. **Final review** — activeForm: `Running final review`
   — blockedBy: Merge task

### Single-milestone edge case

If the plan has exactly one milestone, skip creating the Merge task.
Set Final Review's blockedBy to the single milestone task instead.

## Pipeline

### Step 1 — Worktree

Mark the Setup task as `in_progress`.

First, check whether you are already inside a separate worktree by
running:

    git rev-parse --show-toplevel

and comparing it with:

    git worktree list

If the current working directory is inside a **non-main worktree** (i.e.
not the bare repo or the primary working tree) and the branch is clean
(`git status` shows no uncommitted changes), then **skip worktree
creation** — just use the current worktree as-is.

Record these values:
- `BASE_BRANCH`: `main` (or `master` if that's the default branch)
- `FEATURE_BRANCH`: the current branch name

If you are on main or master (i.e. in the primary working tree), create
a worktree with a descriptive branch name (e.g. `feature/auth-refresh`,
`fix/null-check`):

    git worktree add .zuggie/<branch-name> -b <branch-name>

Then call `EnterWorktree` with `path: .zuggie/<branch-name>` to switch
the session into the new worktree. The orchestrator uses `EnterWorktree(path: …)`
for all worktree switches after creation — never raw `cd`.

Record these values:
- `BASE_BRANCH`: the branch you were on before creating the worktree
  (e.g. `main`)
- `FEATURE_BRANCH`: the new branch name (e.g. `feature/auth-refresh`)

All subsequent steps run inside the worktree (whether reused or newly
created).

Mark the Setup task as `completed`.

### Step 1a — Pre-planning recon

Mark the Explore task as `in_progress`.

Before planning, gather lightweight context so the tech-lead starts
with a clear picture instead of exploring from scratch.

Spawn one or more **Explore** agents (`subagent_type: Explore`) with
targeted questions about the codebase — e.g. "find files related to
X", "how does Y work", "what patterns does Z use". Keep prompts
focused; use multiple agents in parallel when the questions are
independent.

Delegate all codebase recon to Explore agents.

Mark the Explore task as `completed`.

### Step 2 — Plan (MANDATORY — DO NOT SKIP)

Mark the Plan task as `in_progress`.

Spawn `zuggie:zuggie-tech-lead` with:
- Task handle (one-line description)
- Current branch name and worktree path
- Exploration findings from Step 1a (summary text, not raw Explore output)

> **Note:** If the task description already contains a specific approach or plan, include it explicitly and instruct the tech-lead to follow it as-is — not replace it.

Wait for the plan. Verify it includes at least one milestone with file
lists and steps. Do NOT proceed to step 3 until you have received the
tech-lead's plan.

If the plan contains **exploration milestones** (type: exploration),
go to step 2a before proceeding. Otherwise, mark the Plan task as
`completed`, then create the milestone tasks followed by the late
pipeline tasks (see "Progress tracking" above).

### Step 2a — Exploration (only if the plan includes exploration milestones)

The Plan task stays `in_progress` throughout this step. Update its
activeForm to `Running exploration for plan`.

For each exploration milestone, spawn `zuggie:zuggie-engineer` with the
exploration milestone. The engineer investigates and reports findings
(no code changes expected).

Once all exploration milestones complete, update the Plan task's
activeForm to `Refining implementation plan`. Re-invoke
`zuggie:zuggie-tech-lead` with:
- The original task description
- The exploration findings from each engineer
- The previous plan (**AUTHORITATIVE** — do not change the approach; only refine milestones with concrete implementation details from the exploration findings)

The tech-lead will produce a revised plan with concrete implementation
milestones. Use the revised plan for all subsequent steps.

Mark the Plan task as `completed`. Create the milestone tasks followed
by the late pipeline tasks (see "Progress tracking" above).

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

For each milestone, mark its task as `in_progress` when launching it.
Update its activeForm during the cycle:
- `Implementing <title>` during implementation
- `Reviewing <title>` during review
- `Fixing review feedback for <title>` during triage fixes

Mark the milestone task as `completed` when its full cycle
(implement-review-triage) finishes.

For each milestone, run the implement-review-triage cycle:

**a. Implement** — spawn `zuggie:zuggie-engineer` with:
- Working directory: the milestone worktree path
  (`.zuggie/<FEATURE_BRANCH>-ms-<N>`), or the feature worktree
  if single milestone
- Branch name to work on
- Path to the plan file (engineer will Read it)
- Milestone handle: title, milestone number
- Path to the task description or a one-line task handle

**b. Review** — after the engineer completes, spawn
`zuggie:zuggie-reviewer` with:
- Path to the plan file and a one-line task handle
- The engineer's summary (terse fields)
- Git diff: `git diff <FEATURE_BRANCH>...<FEATURE_BRANCH>-ms-<N>`
  (or `git diff <BASE_BRANCH>...HEAD` if single milestone)
- Worktree path so the reviewer reads files from the correct branch

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
   Call `ExitWorktree(action: "keep")` to leave the current sub-worktree,
   then `EnterWorktree(path: .zuggie/<FEATURE_BRANCH>)` to enter the feature
   worktree, then run `git merge <FEATURE_BRANCH>-ms-<dep> --no-edit`.
2. Create the dependent milestone's worktree:
   `git worktree add .zuggie/<FEATURE_BRANCH>-ms-<N> -b <FEATURE_BRANCH>-ms-<N> <FEATURE_BRANCH>`
3. Launch the dependent milestone's implement-review-triage cycle.

If an engineer reports a blocking issue, stop the pipeline and surface
it to the user.

### Step 5 — Merge milestones

Mark the Merge task as `in_progress`. If this is a single-milestone
plan (no sub-worktrees), the Merge task was already deleted — skip
the task update.

Only if sub-worktrees were created:

a. Call `ExitWorktree(action: "keep")` if currently inside a sub-worktree,
   then call `EnterWorktree(path: .zuggie/<FEATURE_BRANCH>)` to enter the
   feature worktree.
b. For each milestone branch not yet merged:
   `git merge <FEATURE_BRANCH>-ms-<N> --no-edit`
   **Target is always the FEATURE_BRANCH, never main/master.**
c. If a merge produces conflicts:
   - `git merge --abort`
   - Spawn `zuggie:zuggie-engineer` in the feature worktree to manually
     apply and resolve the changes. Ensure the feature worktree is entered
     via `EnterWorktree(path: .zuggie/<FEATURE_BRANCH>)` before spawning.
     Provide:
     - The diff: `git diff <FEATURE_BRANCH>...<FEATURE_BRANCH>-ms-<N>`
     - The list of conflicting files
     - The milestone description
d. Clean up each sub-worktree:

       git worktree remove .zuggie/<FEATURE_BRANCH>-ms-<N>
       git branch -d <FEATURE_BRANCH>-ms-<N>

Mark the Merge task as `completed`.

### Step 6 — Final unified review

Mark the Final Review task as `in_progress`.

Spawn `zuggie:zuggie-reviewer` with:
- Path to the plan file and a one-line task handle
- All engineer summaries (terse fields)
- Git diff: `git diff <BASE_BRANCH>...HEAD` on the feature branch
- Feature worktree path so the reviewer reads files from the correct branch

This review focuses on cross-milestone integration: consistency,
missing connections, conflicting patterns.

Triage as usual:
- **Blocking**: spawn `zuggie:zuggie-engineer` in the feature worktree
  to fix. Pass the reviewer's issue description plus relevant files.
- **Minor/nit**: defer unless the fix is a one-line change.
- Only re-review if the verdict was "request changes".

Mark the Final Review task as `completed`.

### Step 7 — Report

**Feature:** <one-line summary of what was implemented>
**Branch:** <FEATURE_BRANCH>
**Reviewer verdict:** <verdict from final review>
**Deferred issues:** <none, or bullet list with reason>

Ask if they want changes or are happy to proceed.
