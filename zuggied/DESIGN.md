# Zuggie Standalone: Design Document

## Decisions
- **Language**: Python (Claude Agent SDK, asyncio, Textual for TUI)
- **Repo**: Same repo, standalone tool lives in `zuggied/` subfolder. Existing plugin stays at `plugins/zuggie/`.
- **Frontend**: TUI first (Textual)

## Problem Statement

The current zuggie Claude Code plugin has two fundamental limitations:
1. **Worktree isolation is instruction-based only** — agents are *told* not to write outside their worktree, but nothing enforces it at runtime
2. **No external event handling** — the plugin cannot listen for GitHub PRs, webhooks, or any external triggers

These are inherent to the Claude Code plugin model. To solve them, we need a standalone daemon that manages agent sessions, enforces isolation at the runtime level, and can react to external events.

---

## Architecture Overview

```
+-------------------+       Unix Socket        +-------------------+
|   Frontend        | <======================> |   Daemon          |
|   (TUI / Webapp)  |   JSON-RPC over ndjson   |   (zuggied)       |
+-------------------+                          +--------+----------+
                                                        |
                                    +-------------------+-------------------+
                                    |                                       |
                           +--------+----------+               +-----------+---------+
                           |  Agent Runtime    |               |  Event Sources      |
                           |  (Claude SDK)     |               |  GitHub, manual,    |
                           |                   |               |  file watcher, ...  |
                           +-------------------+               +---------------------+
```

**Three components:**
- **zuggied** — long-running daemon. Manages projects, sessions, agents, events. Single process, async.
- **Frontend** — TUI or webapp. Connects to daemon over unix socket. Stateless display layer. Multiple frontends can connect simultaneously.
- **Agent sessions** — Claude SDK invocations managed as async tasks within the daemon.

---

## Core Concepts

### Projects
User registers a project directory with the daemon. The daemon tracks it in a local SQLite database. Project dir must be on the same host (for now).

### Sessions
A session = a unit of work on a project. Creating a session automatically provisions a git worktree. The session spawns an **orchestrator agent** that drives the work — deciding what to plan, implement, review, and merge based on context and available skills.

### Events
External event sources (GitHub webhooks, etc.) can trigger session creation. Events are matched to registered projects and either auto-trigger sessions or queue for user approval.

---

## Daemon (zuggied)

### Responsibilities
- Unix socket server (JSON-RPC 2.0, newline-delimited JSON)
- Project registration and management
- Session lifecycle (create, cancel, cleanup)
- Agent runtime (Claude SDK integration)
- Worktree management (create, merge, remove)
- Event source management (GitHub webhooks, etc.)
- State persistence (SQLite)

### Data Storage
```
~/.zuggie/
  zuggie.sock              # Unix socket
  zuggie.pid               # PID file
  config.toml              # Global daemon config
  db.sqlite                # All state
  logs/
    daemon.log
    sessions/<session-id>.log
```

Project-level worktrees continue to live in `.zuggie/` within the project directory.

### Data Model (SQLite)

**projects** — id, name, path, config (JSON), created_at
**sessions** — id, project_id, status, task, base_branch, feature_branch, worktree_path, created_at, updated_at
**events** — id, source, type, project_id, payload (JSON), status, created_at
**agent_logs** — id, session_id, agent_type, role, content, timestamp

---

## Agent Architecture

### The Orchestrator is an Agent

The orchestrator is an LLM-powered agent — not imperative code. It receives a task, assesses the situation, and makes judgment calls about what to do next using **skills** exposed as tools.

This mirrors the current plugin design where the orchestrator (SKILL.md) is an LLM that decides when to plan, when to explore, when to spawn engineers, and how to triage review feedback. The difference: the daemon provides **runtime-enforced infrastructure** (worktrees, isolation, event handling) that the plugin couldn't.

### Skills as Tools

The daemon exposes zuggie's capabilities as **custom MCP tools** that the orchestrator agent can call. These are the building blocks the orchestrator reasons about:

| Skill (Tool) | Description |
|---------------|-------------|
| `create_worktree` | Create an isolated git worktree for a milestone |
| `remove_worktree` | Clean up a worktree |
| `spawn_agent` | Run a sub-agent (tech-lead, engineer, reviewer) in a specific worktree with specific tools |
| `merge_branch` | Merge a milestone branch into the feature branch |
| `get_diff` | Get the diff for a branch (for review) |
| `get_session_state` | Read current session state (milestones, statuses, plan) |
| `update_session_state` | Persist decisions (plan, milestone status, etc.) |
| `create_pr` | Create a GitHub PR from the feature branch |

The orchestrator calls these tools as it sees fit. It might:
- Spawn a tech-lead, read the plan, then spawn engineers in parallel
- Skip planning for a simple task and go straight to implementation
- Decide a review issue is minor and proceed without fixing it
- Adapt its strategy based on exploration findings

The daemon implements these tools with proper isolation, state management, and git safety — the agent just invokes them.

### Sub-Agents

When the orchestrator calls `spawn_agent`, the daemon:
1. Creates a new Claude SDK session with the appropriate system prompt (tech-lead, engineer, or reviewer)
2. Sets `cwd` to the assigned worktree
3. Configures `allowed_tools` based on agent type
4. Registers isolation hooks
5. Streams the agent's output back to the orchestrator and to subscribed frontends

Sub-agents are isolated SDK sessions. They don't share context with each other — only the orchestrator sees all outputs and makes cross-cutting decisions.

### Agent Tool Permissions

| Agent | Tools | Notes |
|-------|-------|-------|
| Orchestrator | Skills (MCP tools above) + Read/Grep/Glob | Cannot directly edit files. Works through skills. |
| Tech-lead | Read, Grep, Glob, Bash | Read-only exploration + plan production |
| Engineer | Read, Write, Edit, Bash, Grep, Glob | Full access, constrained to worktree by isolation hooks |
| Reviewer | Read, Grep, Glob | Read-only, no Bash |

---

## Worktree Isolation (Runtime Enforcement)

This is the core improvement over the plugin. Four enforcement layers:

### Layer 1: `cwd` Scoping
Every agent invocation sets `cwd` to its assigned worktree. The SDK's built-in tools (Read, Write, Edit, Glob, Grep) resolve relative paths against this `cwd`.

### Layer 2: PreToolUse Hook
A SDK hook inspects every tool call before execution:
- **Write/Edit**: validate that `file_path` resolves within the worktree boundary (prevent path traversal via `../`)
- **Bash**: block dangerous commands — `git checkout main/master`, `git push`, `git merge`, `cd` to paths outside the worktree
- **Block** the call if a violation is detected, returning an error message to the agent

### Layer 3: `allowed_tools` Scoping
Tech-lead and reviewer agents simply don't have Write/Edit tools. They can't modify files even if they tried.

### Layer 4: Git Operation Serialization
An asyncio Lock per project prevents concurrent git operations (commit, merge, worktree add/remove) from corrupting the repo. Multiple agents can read concurrently, but mutating git operations are serialized.

---

## Event System

### Architecture
Internal async pub/sub EventBus within the daemon process. Event sources are long-running asyncio tasks.

### Event Sources

**GitHub Webhook Source:**
- Small `aiohttp` HTTP server on a configurable port
- Validates webhook signatures (HMAC)
- Maps GitHub events to registered projects via repository URL
- Supported events: `pull_request.opened`, `pull_request.synchronize`, `issue_comment.created`, etc.

**Manual Triggers:**
- Frontend sends `session.create` — the simplest "event"

**File Watcher (future):**
- OS-level file change notifications (kqueue on macOS)
- Could trigger re-review or re-test sessions

### Event → Session Flow

Per-project trigger configuration:
```toml
[projects."myproject".triggers]
pr_opened = { workflow = "review", auto = true }
pr_comment = { workflow = "respond", auto = false }  # queued for user approval
```

When an event arrives:
1. Event source publishes to EventBus
2. Event is persisted to `events` table
3. Handler checks project trigger config
4. If `auto = true` → create session automatically with appropriate task description
5. If `auto = false` → mark as `pending`, frontend shows it for user approval

---

## Frontend Protocol (Unix Socket API)

Wire format: newline-delimited JSON-RPC 2.0. Each message is a single JSON object terminated by `\n`.

### Request/Response

```json
{"jsonrpc": "2.0", "id": 1, "method": "project.register", "params": {"path": "/home/user/myproject"}}
{"jsonrpc": "2.0", "id": 1, "result": {"project_id": "abc-123", "name": "myproject"}}
```

### Server-Pushed Notifications

```json
{"jsonrpc": "2.0", "method": "session.event", "params": {"session_id": "xyz", "type": "agent_output", "data": {"agent": "tech_lead", "chunk": "## Plan\n..."}}}
```

### Methods

| Method | Params | Description |
|--------|--------|-------------|
| `project.register` | `{path}` | Register a project directory |
| `project.unregister` | `{project_id}` | Remove a project |
| `project.list` | `{}` | List all projects |
| `session.create` | `{project_id, task}` | Start a new session (creates worktree, spawns orchestrator) |
| `session.list` | `{project_id?}` | List sessions, optionally filtered |
| `session.get` | `{session_id}` | Full session details |
| `session.cancel` | `{session_id}` | Cancel a running session |
| `session.cleanup` | `{session_id, delete_branch?}` | Remove worktrees, optionally delete branch |
| `session.subscribe` | `{session_id}` | Start streaming session events |
| `session.unsubscribe` | `{session_id}` | Stop streaming |
| `daemon.status` | `{}` | Daemon health/stats |
| `daemon.shutdown` | `{}` | Graceful shutdown |

### Streaming Event Types

After `session.subscribe`, the client receives notifications:
- `stage_changed` — orchestrator moved to a new phase
- `agent_output` — streaming text from any agent (for live display)
- `agent_spawned` — a sub-agent was created (type, worktree)
- `agent_completed` — a sub-agent finished (summary, verdict)
- `tool_use` — an agent invoked a tool (name, input summary)
- `error` — something went wrong
- `completed` — session finished

---

## Session Lifecycle

```
Frontend                         Daemon
   |                               |
   |-- session.create ------------>|
   |   {project_id, task}          |
   |                               |-- Validate project
   |                               |-- Determine base branch
   |                               |-- Create worktree: .zuggie/<branch>
   |                               |-- Insert session record
   |                               |-- Spawn orchestrator agent (async task)
   |<-- session.created -----------|
   |   {session_id, branch}        |
   |                               |
   |-- session.subscribe --------->|
   |                               |
   |<-- session.event -------------|  (orchestrator decides to plan)
   |   {type: agent_spawned,       |
   |    agent: tech_lead}          |
   |                               |
   |<-- session.event -------------|  (streaming tech-lead output)
   |   {type: agent_output, ...}   |
   |                               |
   |<-- session.event -------------|  (orchestrator spawns engineers)
   |   {type: agent_spawned,       |
   |    agent: engineer, ms: 1}    |
   |                               |
   |   ... (continues streaming)   |
   |                               |
   |<-- session.event -------------|
   |   {type: completed}           |
```

### Cleanup
- On completion: milestone worktrees removed, feature worktree kept (user inspects, creates PR)
- On cancel: all agent tasks cancelled, all worktrees removed
- On explicit cleanup (`session.cleanup`): feature worktree removed, optionally delete branch

### Daemon Restart Recovery
- Active sessions are marked `paused` on shutdown
- On startup, orphaned worktrees are detected
- User can resume paused sessions from the frontend

---

## Package Structure

```
zuggie/                         # Repo root (existing)
  plugins/zuggie/               # Existing Claude Code plugin (unchanged)
  zuggied/                      # New standalone tool
    pyproject.toml
    src/zuggied/
      __init__.py
      cli.py                    # CLI entry point
      daemon/
        server.py               # Unix socket server + main loop
        pid.py                  # PID file management
        config.py               # Config loading (TOML)
      core/
        project.py              # Project CRUD
        session.py              # Session lifecycle
        worktree.py             # Git worktree operations
      agents/
        runtime.py              # Claude SDK wrapper
        isolation.py            # PreToolUse isolation hooks
        skills.py               # MCP tools exposed to orchestrator
        prompts/                # System prompt files
      events/
        bus.py                  # Internal event bus
        sources/
          github.py             # GitHub webhook listener
          manual.py             # Manual triggers
      protocol/
        messages.py             # JSON-RPC message types
        handler.py              # Request dispatcher
      db/
        models.py               # Dataclasses
        store.py                # SQLite access layer
      tui/
        app.py                  # Textual TUI app
```

---

## Key Design Decisions

1. **Orchestrator is an LLM agent, not code.** It uses skills/tools to drive the workflow. This preserves the flexibility of the current plugin — the agent can adapt, skip steps, handle edge cases, and make judgment calls that rigid code cannot.

2. **Infrastructure is code, not instructions.** Worktree isolation, git safety, event handling — these are enforced by the daemon runtime via hooks and tool restrictions. The agent doesn't need to "remember" not to write outside its worktree.

3. **Skills as MCP tools.** The orchestrator's capabilities are defined as tools. Adding a new capability (e.g., "run tests", "deploy preview") is just adding a new tool — the orchestrator can immediately reason about when to use it.

4. **Unix socket + JSON-RPC.** Simple, well-understood protocol. Any frontend (TUI, webapp, CLI script, IDE plugin) can connect. No HTTP overhead for local communication.

5. **SQLite for state.** Single-file database, no external dependencies, good enough for local daemon use. Session state survives daemon restarts.

---

## Open Questions

1. **Orchestrator prompt design** — How much of the current SKILL.md should be ported vs. letting the agent discover the workflow through available tools? A minimal prompt with good tool descriptions might be sufficient.

2. **Session interaction** — Should the user be able to "chat" with a running session (provide feedback, redirect the orchestrator mid-flight)? The protocol supports it (`session.send_message`), but the UX needs thought.

3. **Multi-project sessions** — Could a session span multiple registered projects? (e.g., update a library and its consumers). Not needed now, but worth considering in the data model.

4. **Authentication** — The GitHub webhook source needs a way to store/manage webhook secrets per project. Where does this config live?
