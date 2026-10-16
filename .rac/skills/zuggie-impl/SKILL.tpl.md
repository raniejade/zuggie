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
triage, spawn explorer subagents rather than reading the full surface
yourself. Keep exploration prompts focused and run multiple explorer
agents in parallel when the questions are independent.

## Subagent spawning contract

Use the harness's general subagent spawning tool for each role below.
These are prompt roles, not registered agent types. Leave model and
reasoning selection to the harness; do not set either in spawn arguments.

Resolve each file relative to this installed skill's own directory:

- Explorer: `references/explorer-prompt.md`
- Tech-lead: `references/tech-lead-prompt.md`
- Engineer: `references/engineer-prompt.md`
- Reviewer: `references/reviewer-prompt.md`

At every invocation, including retries, fixes, conflict resolution, and
re-reviews, read the selected role file and supply its full content in
the subagent instructions together with the contextual assignment listed
in that step. A role name or a path alone is not sufficient. Include the
assigned worktree, branch, bounded scope, ownership, and required inputs.
Actually spawn a separate subagent and wait for its output; never perform
or simulate a role inline. Keep review independent of implementation by
spawning a separate reviewer subagent. If general subagent spawning is
unavailable, report the blocker instead of substituting inline work.

## Hard rules

- NEVER merge anything into main or master. All work happens on
  feature branches. The user merges to main themselves.
- NEVER skip the Plan step. You MUST spawn a tech-lead subagent even
  if you think you already understand the task.
- NEVER write or edit code yourself. All code changes go through
  an engineer subagent.
- NEVER accept a deferral of the main task. If an engineer's summary
  indicates the core ask was skipped, deferred, or only partially done,
  treat it as blocking and re-spawn the engineer.

## Repository requirements

Explicit user scope and applicable repository instructions govern generic
checklists. Discover applicable ancestor/root and nested `AGENTS.md` and
`CLAUDE.md`, relevant referenced guidance, README, contribution and
validation rules for the task. Keep discovery bounded to the task surface.
Do not invent extra tests, refactors, compatibility, or remediation.
Surface conflicts with their sources instead of silently overriding them.

Track each gate's source, applicability, timing/prerequisites, owner,
command or review action, required evidence, and repository blocking
criteria. Before advancing a stage, check all gates due at that point.
Do not advance past a due gate that blocks under repository criteria;
obtain missing evidence through the responsible agent or report the
blocker. Future gates remain not yet due. An exemption needs a source and
reason; do not count a command as proof of behavior it cannot verify.

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

## Reference paths

The orchestrator passes reference checklist paths to the reviewer
at every review spawn. Resolve these paths relative to this installed
skill's own directory, never the current worktree or a hardcoded vendor
root. Use the harness-provided skill location to find this directory.

The two reference files are:

- `testing-patterns.md` — passed as `references.testing_patterns_path`
- `security-checklist.md` — passed as `references.security_checklist_path`

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
explorer subagents for questions such as related files, existing
patterns, or unclear APIs. Include task-bounded discovery of applicable
instruction files, relevant linked guidance, README, contribution and
validation requirements, including nested scopes. Pass source paths and
synthesized requirements/findings to the tech-lead; do not dump raw
explorer output. Check gates due before planning.

### Step 2 - Plan

Spawn a tech-lead subagent with:
- Task handle
- Feature branch and worktree path
- Exploration findings
- Discovered repository sources, requirements, gate timing and evidence
- Any existing authoritative plan or specific approach from the caller

Wait for the plan. Verify it includes at least one milestone with file
lists and steps, plus the gate inventory under its existing headings.
Check inventory completeness, timing/prerequisites, owners, required
evidence and blocking criteria against discovered requirements. Resolve
conflicts and satisfy gates due before implementation. If the plan
contains milestones whose titles begin with
`[explore]`, dispatch each `[explore]` milestone to explorer
(not engineer). Collect the text findings. Then re-invoke
tech-lead with the original plan as authoritative input plus
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

1. Spawn an engineer subagent in the milestone worktree, or the feature
   worktree for a single-milestone plan. Provide the plan, branch,
   worktree path, milestone number/title, task handle, repository source
   paths, applicable gate inventory and existing evidence. Require the
   engineer to read sources independently and satisfy gates when due.
   Check the summary for evidence, source-backed exemptions and remaining
   gates before advancing to review; route due missing work to its owner.
2. Spawn reviewer with the plan, engineer summary, scoped diff,
   worktree path, repository source paths, gate inventory, evidence,
   exemptions and outstanding/not-yet-due gates, and reference paths:
   - `references.testing_patterns_path` — resolved per the Reference paths section.
   - `references.security_checklist_path` — resolved per the Reference paths section.
3. Check due gates and triage the review:
   - Re-spawn engineer when **any** `[blocking]` issue is present,
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

If conflicts occur, abort the merge and spawn an engineer subagent in the
feature worktree with the milestone diff, conflicting file list, and
milestone description.

After merging, remove milestone worktrees and delete the milestone
branches.

### Step 6 - Final unified review

Check gates due before final review, including any requirements that
apply to the combined diff. Obtain missing evidence from the responsible
agent before advancing where repository criteria require it.

Spawn a reviewer subagent with:
- Plan
- All engineer summaries
- Repository source paths and complete gate inventory
- Evidence and exemptions for the combined diff/revision, plus outstanding
  and not-yet-due gates
- `git diff <BASE_BRANCH>...HEAD`
- Feature worktree path
- `references.testing_patterns_path` — resolved per the Reference paths section.
- `references.security_checklist_path` — resolved per the Reference paths section.

Triage final review: re-spawn engineer when any `[blocking]` line
is present. Defer `[minor]` issues. Re-review when verdict was
`request changes`. Fallback to verdict-only triage if tags are absent.

### Step 7 - Report

Check gates due before reporting completion. Include source-backed gate
status, exact actions/commands and outcomes, review evidence, exemptions,
and outstanding or not-yet-due requirements under the existing Status,
Tests / Verification, and Risks / Follow-ups sections. Do not claim a
blocked stage or a future commit/push gate has passed.

Report:
- Status
- Branch
- Implementation Map
- API / Interface Shape
- Representative Snippets
- Seams And Interactions
- Migration / Compatibility
- Tests / Verification
- Risks / Follow-ups

Synthesize the final report from the engineer milestone summaries and
the final reviewer output. Preserve the reviewer output contract and the
existing triage behavior.

Include representative snippets when the change materially affects APIs,
data flow, config, commands, or integrations. Use `None` only when a
section is genuinely not applicable.
