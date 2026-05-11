+++
description = "Structured debugging workflow using zuggie's dedicated debugger and reviewer subagents."
[vendor.claude.frontmatter]
version = "1.0.0"
+++

Run the structured debug pipeline: observe, hypothesize, bisect,
minimize, explain, review, and optionally hand off to the fix workflow.

Usage: /zuggie-structured-debug <bug description>

## Your role

You are the orchestrator. You coordinate the pipeline by spawning
agents and managing git branches. You do NOT:
- Write or edit application code yourself
- Skip steps because you think you already know the answer
- Act as the debugger or reviewer

Every step below that says "spawn" means: invoke the appropriate
sub-agent and wait for its real output. Do not simulate the agent's
work.

Spawn explorer-style agents for all codebase recon.

## Required subagents

- `zuggie-debugger`
- `zuggie-reviewer`

## Hard rules

- NEVER merge anything into main or master. All work happens on
  debug branches. The user merges to main themselves.
- NEVER skip the Observations step. You MUST gather observed facts
  before invoking the debugger.
- NEVER write or edit code yourself. All reproduction code changes
  go through the debugger agent.
- NEVER accept deferral of the reproduction task. If reproduction
  was skipped, deferred, or partially done, re-spawn the debugger.

## Progress tracking

Use the tool-native task/progress tracking surface when available. Only
the orchestrator updates progress; agents do not.

Create these early tasks before Step 1:
1. Set up workspace
2. Gather observations
3. Run structured debug, blocked by observations
4. Review reproduction, blocked by structured debug

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
a debug worktree under `.zuggie/<branch-name>` from main or master.

Record:
- `BASE_BRANCH`: `main` or `master`
- `DEBUG_BRANCH`: the current or created debug branch

Enter the debug worktree using the worktree tooling rule above.

### Step 2 - Observations

Gather observed facts only, with no theories:
- What the user reports
- Where the symptom surfaces in code
- Recent changes in that area
- Existing tests that exercise that area

Synthesize the facts into an Observation Brief and pass the file path
forward. Do not inline the full brief into later prompts.

### Step 3-5 - Debugger

Spawn `zuggie-debugger` with:
- Observation Brief path
- Worktree path
- Debug branch
- Directive to maintain and return a hypothesis ledger with entries
  `{id, statement, prediction, test, result, status}` where status is
  `pending`, `supported`, or `refuted`

Require at least two real hypotheses, even if the first seems obvious.

The debugger summary must include:
- Hypothesis ledger with at least two supported/refuted entries
- Bisect result, or "not a regression"
- Minimized reproduction
- Causal mechanism statement

Mechanism gate: "It fails when X is called" is not a mechanism. "When X
is called with Y not initialized, Z reads stale cache and returns nil"
is a mechanism. If the summary lacks a causal mechanism, re-spawn the
debugger with that feedback.

### Step 6 - Review reproduction

Spawn `zuggie-reviewer` with:
- A note that this is a reproduction review
- Observation Brief path
- Debugger reproduction summary
- `git diff <BASE_BRANCH>...HEAD`
- Worktree path
- Evaluation criteria:
  - Observation Brief is factual
  - Hypothesis ledger has real alternatives
  - Reproduction is minimal
  - Mechanism statement is causal

Triage review:
- Re-spawn `zuggie-debugger` when any `[blocking]` line is present. Pass
  the blocking issue lines, original Observation Brief path, and worktree
  details.
- Defer `[minor]` issues unless trivial.
- Re-review when the verdict was `request changes`.
- Fallback: if no severity tags are present, fall back to verdict-only
  triage (`request changes` → re-spawn; anything else → continue).

### Step 7 - Report and optional fix handoff

Report:
- Reproduction file(s)
- Run command
- Mechanism
- Reviewer verdict
- Deferred non-blocking issues

Ask whether the user wants to fix the bug using the zuggie workflow.
