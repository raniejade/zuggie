---
name: zuggie-structured-debug
description: >
  Structured debugging pipeline that creates a minimal reproducible example
  for a bug, regression, or crash. TRIGGER when: user asks to "debug with
  zuggie", "use zuggie-structured-debug", reports a bug, regression, or
  crash, or asks to reproduce a failing behavior.
version: 1.0.0
---

Run the structured debug pipeline: observe, hypothesize, bisect, minimize, explain, review, and optionally hand off to the fix workflow.

Usage: /zuggie-structured-debug <bug description>

## Your role

You are the **orchestrator**. You coordinate the pipeline by spawning
agents (via the Agent tool) and managing git branches. You do NOT:
- Write or edit application code yourself
- Skip steps because you think you already know the answer
- Act as the debugger or reviewer — you delegate to them

Every step below that says "spawn" means: use the **Agent tool** with
the appropriate `subagent_type` (e.g. `zuggie:zuggie-debugger`).
Do not simulate the agent's work — actually spawn it.

Spawn **Explore** agents (`subagent_type: Explore`) for all codebase recon.

## Hard rules

- **NEVER merge anything into main or master.** All work happens on debug branches. The user merges to main themselves.
- **NEVER skip the Observations step.** You MUST spawn Explore agents to gather observed facts before invoking the debugger.
- **NEVER write or edit code yourself.** All code changes go through the debugger agent.
- **NEVER accept a deferral of the reproduction task.** If the debugger's summary indicates the reproduction was skipped, deferred, or only partially done — treat it as a blocking issue. Re-spawn the debugger with a note that the previous attempt was incomplete.

## Progress tracking

Use `TaskCreate` and `TaskUpdate` to give the user real-time visibility
into the pipeline. Only the orchestrator calls these — agents do not.

Tasks are displayed in creation order, so create them just-in-time.

### Early pipeline tasks (create before Step 1)

Create these 4 tasks using `TaskCreate` at the very start:

1. **Set up workspace** — activeForm: `Setting up workspace`
2. **Gather observations** — activeForm: `Gathering observations`
3. **Run structured debug** — activeForm: `Running structured debug`
   — blockedBy: task 2
4. **Review reproduction** — activeForm: `Reviewing reproduction`
   — blockedBy: task 3

## Pipeline

### Step 1 — Worktree

Mark the Setup task as `in_progress`.

Check whether you are already inside a separate worktree:

    git rev-parse --show-toplevel

Compare with:

    git worktree list

If the current working directory is inside a **non-main worktree** and
the branch is clean (`git status` shows no uncommitted changes), skip
worktree creation — use the current worktree as-is.

Record:
- `BASE_BRANCH`: `main` (or `master` if that's the default branch)
- `DEBUG_BRANCH`: the current branch name

If you are on main or master, create a worktree with a descriptive
branch name derived from the bug description:

    git worktree add .zuggie/<branch-name> -b <branch-name>
    cd .zuggie/<branch-name>

Record:
- `BASE_BRANCH`: the branch you were on before creating the worktree
- `DEBUG_BRANCH`: the new branch name

All subsequent steps run inside the worktree.

Mark the Setup task as `completed`.

### Step 2 — Observations

Mark the Gather observations task as `in_progress`.

Spawn one or more **Explore** agents to collect **observed facts only** — no theories:
- What the user reports (symptom, environment, reproduction steps if given)
- Where the symptom surfaces in code (entry point, call stack area)
- Recent changes in that area (`git log` on the affected files)
- Existing tests that exercise that area

Synthesize into an **Observation Brief** — strictly factual, no hypotheses.
Write it to `.zuggie/<DEBUG_BRANCH>/observation-brief.md`.

Pass the file path forward — do not inline the content.

Mark the Gather observations task as `completed`.

### Step 3–5 — Debugger (hypothesize + bisect + minimize + explain)

Mark the Run structured debug task as `in_progress`.

Spawn `zuggie:zuggie-debugger` with:
- Path to the Observation Brief file
- The worktree path (absolute path to `.zuggie/<DEBUG_BRANCH>`)
- The branch name (`DEBUG_BRANCH`)
- Directive: maintain and return a **hypothesis ledger** with entries
  `{id, statement, prediction, test, result, status}`, status ∈
  `{pending, supported, refuted}`. Minimum 2 hypotheses must be
  considered — even if the first seems obvious. The ledger is a
  required output.

Wait for the debugger's Reproduction Summary. The summary must include:
- A hypothesis ledger with at least 2 entries, each marked supported or refuted
- A bisect result (commit range or "not a regression")
- A causal mechanism statement in 1–2 sentences

**Mechanism gate:** "It fails when X is called" is not a mechanism.
"When X is called with Y not yet initialized, Z reads stale cache and
returns nil" is. If the returned summary lacks a causal mechanism
statement, re-spawn the debugger with feedback that the mechanism is
missing or descriptive rather than causal.

If the summary indicates the reproduction was skipped, deferred, or
only partially done — treat it as a blocking issue and re-spawn.

If the debugger reports a genuine blocker (e.g. missing dependency,
broken environment) after systematic investigation, surface it to the
user and stop.

Mark the Run structured debug task as `completed`.

### Step 6 — Review reproduction

Mark the Review reproduction task as `in_progress`.

Spawn `zuggie:zuggie-reviewer` with:
- A note: this is a **reproduction review**. Treat the Observation Brief
  as the plan, and the Reproduction Summary as the engineer summary.
- Path to the Observation Brief file (`.zuggie/<DEBUG_BRANCH>/observation-brief.md`)
- Debugger's Reproduction Summary (includes hypothesis ledger, bisect result, mechanism)
- Git diff: `git diff <BASE_BRANCH>...HEAD` on the debug branch
- Worktree path
- Evaluation criteria (include verbatim in the reviewer prompt):
  - Observation Brief is factual (no smuggled hypotheses)
  - Hypothesis ledger has real alternatives, not strawmen
  - Reproduction is minimal
  - Mechanism statement is causal, not merely descriptive

Triage the review verdict:
- **Blocking**: re-spawn `zuggie:zuggie-debugger` with the reviewer's
  specific feedback, the original Observation Brief path, and the
  worktree details.
- **Minor/nit**: defer unless the fix is trivial.
- Only re-review if the reviewer's verdict was "request changes".

Mark the Review reproduction task as `completed`.

### Step 7 — Report + optional fix handoff

**Repro file(s):** <paths, relative to repo root>
**Run command:** <exact command>
**Mechanism:** <one-line bug cause>
**Reviewer verdict:** <verdict>
**Deferred issues:** <none, or bullet list>

Ask: **"Would you like to fix this bug using the zuggie workflow?"**

- If yes: instruct the user to run `/zuggie` passing the bug description, repro file path, and branch name. The repro is the verification test.
- If no: done.
