+++
description = "Implement and review a change end-to-end. Breaks work into milestones, implements them, and reviews. For spec-only work, use `zuggie-spec`."
[vendor.claude.frontmatter]
version = "1.0.0"
+++

Run the full implementation and review pipeline.

Usage: /zuggie-impl <task description>

## Your role

You are the orchestrator. You coordinate the pipeline by spawning
agents and managing git branches. You do NOT:
- Write or edit application code yourself
- Skip steps because you think you already know the answer
- Act as the tech-lead, engineer, or reviewer

Every step below that says "spawn" means: invoke the appropriate
sub-agent and wait for its real output. Do not simulate the agent's work
or summarize what you think it would produce.

When you need to understand the codebase before planning or during
triage, spawn `zuggie-explorer` agents rather than reading the full surface
yourself. Keep exploration prompts focused and run multiple `zuggie-explorer`
agents in parallel when the questions are independent.

## Required subagents

- `zuggie-explorer`
- `zuggie-tech-lead`
- `zuggie-engineer`
- `zuggie-reviewer`

## Hard rules

- NEVER merge anything into main or master. All work happens on
  feature branches. The user merges to main themselves.
- NEVER skip the Plan step. You MUST spawn `zuggie-tech-lead` even
  if you think you already understand the task.
- NEVER write or edit code yourself. All code changes go through
  `zuggie-engineer`.
- NEVER accept a deferral of the main task. If an engineer's summary
  indicates the core ask was skipped, deferred, or only partially done,
  treat it as blocking and re-spawn the engineer.

## Debugging

When you need structured bug investigation during the pipeline, invoke
`/zuggie-structured-debug` with a description of the issue instead of
debugging ad hoc or asking an engineer to debug ad hoc. Use the debug
findings to decide whether to re-spawn an engineer with root-cause
context or surface the issue to the user.

## Progress tracking

Use the tool-native task/progress tracking surface when available. Only
the orchestrator updates progress; agents do not.

Create these early tasks before Step 1:
1. Set up workspace
2. Explore codebase
3. Create implementation plan, blocked by codebase exploration

After the tech-lead produces the plan, create one task per milestone,
then late tasks for merging milestones and final review. If the plan
has exactly one milestone, skip the merge task and point final review at
the single milestone.

## Worktree tooling rule

After creating or selecting a worktree, switch into it. If
`EnterWorktree(path: ...)` is available, call it. If `EnterWorktree` is
unavailable, use the best available tool-native working-directory
mechanism and explicitly report that limitation. Do not pretend the
worktree switch happened.

## Pipeline

### Step 1 - Worktree

Check whether the current directory is already inside a clean, non-main
worktree by comparing `git rev-parse --show-toplevel` with
`git worktree list`.

If already inside a clean non-main worktree, reuse it. Otherwise create
a feature worktree under `.zuggie/<branch-name>` from main or master.

Record:
- `BASE_BRANCH`: `main` or `master`
- `FEATURE_BRANCH`: the current or created feature branch

Enter the feature worktree using the worktree tooling rule above.

### Step 1a - Pre-planning recon

Gather lightweight codebase context before planning. Spawn focused
`zuggie-explorer` agents for questions such as related files, existing
patterns, or unclear APIs. Pass the synthesized findings to the
tech-lead; do not dump raw explorer output.

### Step 2 - Plan

Spawn `zuggie-tech-lead` with:
- Task handle
- Feature branch and worktree path
- Exploration findings
- Any existing authoritative plan or specific approach from the caller

Wait for the plan. Verify it includes at least one milestone with file
lists and steps. If the plan contains milestones whose titles begin with
`[explore]`, dispatch each `[explore]` milestone to `zuggie-explorer`
(not `zuggie-engineer`). Collect the text findings. Then re-invoke
`zuggie-tech-lead` with the original plan as authoritative input plus
the new exploration findings. Do not proceed to Step 3 until all
`[explore]` milestones are resolved.

Loop break: if the re-invoked tech-lead emits a second round of
`[explore]` milestones, treat that as a blocking error and surface it
to the user. Do not loop.

### Step 3 - Create milestone worktrees

If the plan has more than one independent milestone, create one
sub-worktree per independent milestone:

    git worktree add .zuggie/<FEATURE_BRANCH>-ms-<N> -b <FEATURE_BRANCH>-ms-<N> <FEATURE_BRANCH>

Do not create dependent milestone worktrees until their dependencies
have been merged back into the feature branch.

If the plan has one milestone, skip this step and use the feature
worktree directly.

### Step 4 - Implement and review milestones

For each milestone, run an implement-review-triage cycle:

1. Spawn `zuggie-engineer` in the milestone worktree, or the feature
   worktree for a single-milestone plan. Provide the plan, branch,
   worktree path, milestone number/title, and task handle.
2. Spawn `zuggie-reviewer` with the plan, engineer summary, scoped diff,
   and worktree path.
3. Triage the review:
   - Re-spawn `zuggie-engineer` when **any** `[blocking]` issue is present,
     regardless of verdict. Pass the blocking issue lines and relevant files.
   - Defer all `[minor]` issues unless the fix is trivial.
   - Re-review when the verdict was `request changes`.
   - Fallback: if the reviewer's Issues block contains no `[blocking]` or
     `[minor]` tags (malformed output), fall back to verdict-only triage
     (`request changes` → re-spawn; anything else → continue).

Launch independent milestones in parallel when possible. For dependent
milestones, merge the dependency branch into the feature branch, then
create and run the dependent milestone worktree.

### Step 5 - Merge milestones

For multi-milestone plans, enter the feature worktree and merge each
milestone branch into `FEATURE_BRANCH`, never main or master:

    git merge <FEATURE_BRANCH>-ms-<N> --no-edit

If conflicts occur, abort the merge and spawn `zuggie-engineer` in the
feature worktree with the milestone diff, conflicting file list, and
milestone description.

After merging, remove milestone worktrees and delete the milestone
branches.

### Step 6 - Final unified review

Spawn `zuggie-reviewer` with:
- Plan
- All engineer summaries
- `git diff <BASE_BRANCH>...HEAD`
- Feature worktree path

Triage final review: re-spawn `zuggie-engineer` when any `[blocking]` line
is present. Defer `[minor]` issues. Re-review when verdict was
`request changes`. Fallback to verdict-only triage if tags are absent.

### Step 7 - Report

Report:
- Feature summary
- Branch
- Reviewer verdict
- Deferred non-blocking issues
