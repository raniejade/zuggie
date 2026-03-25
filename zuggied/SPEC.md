# zuggied Specification

## 1. Overview

zuggied is a per-project, single-process async daemon that orchestrates parallel AI agent work with git worktree isolation. One daemon instance manages one project directory. It manages session lifecycles, agent runtimes, and worktree provisioning, exposing all functionality over a Unix socket using JSON-RPC 2.0. Frontends (TUI, webapp, CLI scripts) are stateless consumers of this API.

This is a personal tool. There is no multi-user model, no authentication on the socket, and no horizontal scaling. To work on multiple projects simultaneously, run multiple daemon instances.

---

## 2. Daemon Lifecycle

### Startup Sequence

1. Resolve project root: the daemon is started with a project directory argument (or current working directory)
2. Validate: directory must exist and be a git repository (`git -C <path> rev-parse --show-toplevel`)
3. Create `<project>/.zuggie/` directory if it does not exist
4. Acquire PID file at `<project>/.zuggie/zuggie.pid`
   - If PID file exists and process is alive: exit with error
   - If PID file exists and process is dead: remove stale PID file, continue
5. Read configuration from `<project>/.zuggie/config.toml` (fall back to `~/.zuggie/config.toml` for defaults)
6. Open/create SQLite database at `<project>/.zuggie/db.sqlite`, run migrations
7. Scan for orphaned sessions (status `running`) and mark them `interrupted`
8. Bind Unix socket at `<project>/.zuggie/zuggie.sock`
9. Write current PID to `<project>/.zuggie/zuggie.pid`
10. Begin accepting connections

### PID File

| Property | Value |
|----------|-------|
| Path | `<project>/.zuggie/zuggie.pid` |
| Contents | ASCII decimal PID followed by newline |
| Stale detection | `kill(pid, 0)` — if `ESRCH`, PID is stale |
| Cleanup | Removed on graceful shutdown |

### Unix Socket

| Property | Value |
|----------|-------|
| Path | `<project>/.zuggie/zuggie.sock` |
| Type | `AF_UNIX`, `SOCK_STREAM` |
| Wire format | Newline-delimited JSON (each message is a complete JSON object terminated by `\n`) |
| Concurrency | Multiple simultaneous client connections allowed |

### Graceful Shutdown

Triggered by `daemon.shutdown` RPC or `SIGTERM`/`SIGINT`.

1. Stop accepting new connections
2. Cancel all running agent tasks (send cancellation to Claude SDK sessions)
3. Set all `running` sessions to `interrupted` in the database
4. Close all client connections
5. Close database
6. Remove `zuggie.sock`
7. Remove `zuggie.pid`
8. Exit 0

### Crash Recovery

On startup, the daemon detects unclean shutdown by finding sessions in `running` state. These are moved to `interrupted`. Worktrees on disk are not automatically removed. The user can:
- Resume interrupted sessions via `session.resume`
- Clean up orphaned worktrees via `session.cleanup`

---

## 3. Data Model

All state lives in `<project>/.zuggie/db.sqlite`. The daemon uses WAL mode for concurrent read access.

### Table: `sessions`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `TEXT` | `PRIMARY KEY` | UUIDv4 |
| `status` | `TEXT` | `NOT NULL` | One of: `creating`, `running`, `interrupted`, `completed`, `failed`, `cancelled` |
| `task` | `TEXT` | `NOT NULL` | User-provided task description |
| `base_branch` | `TEXT` | `NOT NULL` | Branch the session was created from |
| `feature_branch` | `TEXT` | `NOT NULL` | Feature branch name for this session |
| `worktree_path` | `TEXT` | | Absolute path to the feature worktree |
| `plan` | `TEXT` | | Opaque JSON blob persisted by the orchestrator |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 timestamp |
| `updated_at` | `TEXT` | `NOT NULL` | ISO 8601 timestamp |

### Table: `agents`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `TEXT` | `PRIMARY KEY` | UUIDv4 |
| `session_id` | `TEXT` | `NOT NULL, REFERENCES sessions(id)` | Parent session |
| `type` | `TEXT` | `NOT NULL` | One of: `orchestrator`, `tech_lead`, `engineer`, `reviewer`, `explorer` |
| `status` | `TEXT` | `NOT NULL` | One of: `running`, `completed`, `failed`, `cancelled` |
| `worktree_path` | `TEXT` | | Worktree this agent operates in (null for orchestrator) |
| `summary` | `TEXT` | | Agent's output summary upon completion |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 timestamp |
| `completed_at` | `TEXT` | | ISO 8601 timestamp |

### Table: `agent_messages`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Monotonic ordering |
| `agent_id` | `TEXT` | `NOT NULL, REFERENCES agents(id)` | Parent agent |
| `role` | `TEXT` | `NOT NULL` | `assistant`, `user`, `tool_use`, `tool_result` |
| `content` | `TEXT` | `NOT NULL` | Message content |
| `timestamp` | `TEXT` | `NOT NULL` | ISO 8601 timestamp |

### Indexes

```sql
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_agents_session ON agents(session_id);
CREATE INDEX idx_agent_messages_agent ON agent_messages(agent_id);
```

---

## 4. Session State Machine

```
                  session.create
                       |
                       v
                  +-----------+
                  | creating  |
                  +-----------+
                       |
              worktree + orchestrator ready
                       |
                       v
                  +-----------+     session.cancel     +------------+
                  |  running  | ---------------------> | cancelled  |
                  +-----------+                        +------------+
                   |    |    |
          agent    |    |    | unrecoverable
          error    |    |    | error
                   |    |    |
                   |    |    v
                   |    |  +-----------+
                   |    |  |  failed   |
                   |    |  +-----------+
                   |    |
                   |    | orchestrator completes
                   |    v
                   |  +-----------+
                   |  | completed |
                   |  +-----------+
                   |
          daemon shutdown / crash
                   |
                   v
             +-------------+     session.resume     +-----------+
             | interrupted | ---------------------> |  running  |
             +-------------+                        +-----------+
                   |
                   | session.cleanup
                   v
             +-------------+
             |  cancelled  |
             +-------------+
```

### State Definitions

| State | Description | Worktrees exist? | Agents running? |
|-------|-------------|-------------------|-----------------|
| `creating` | Worktree being provisioned, orchestrator starting | Being created | No |
| `running` | Orchestrator and/or sub-agents actively working | Yes | Yes |
| `interrupted` | Daemon shut down or crashed while session was active | Yes (possibly) | No |
| `completed` | Orchestrator finished successfully | Feature worktree kept; sub-worktrees removed | No |
| `failed` | Unrecoverable error during execution | Yes (for debugging) | No |
| `cancelled` | User explicitly cancelled | Removed by cleanup | No |

### Transition Table

| From | To | Trigger |
|------|----|---------|
| — | `creating` | `session.create` RPC |
| `creating` | `running` | Worktree created, orchestrator spawned |
| `creating` | `failed` | Worktree creation failed, git error |
| `running` | `completed` | Orchestrator agent returns successfully |
| `running` | `failed` | Unrecoverable agent error, SDK error |
| `running` | `cancelled` | `session.cancel` RPC |
| `running` | `interrupted` | Daemon shutdown or crash |
| `interrupted` | `running` | `session.resume` RPC |
| `interrupted` | `cancelled` | `session.cleanup` RPC |

---

## 5. Worktree Management

### Directory Layout

All worktrees live under `<project>/.zuggie/`:

```
<project>/
  .zuggie/
    zuggie/<slug>/                  # Feature worktree (session-level)
    zuggie/<slug>-<name>/           # Sub-worktree (created by orchestrator)
```

### Naming Conventions

| Worktree | Branch name | Directory |
|----------|-------------|-----------|
| Feature | `zuggie/<slug>` | `.zuggie/zuggie/<slug>` |
| Sub-worktree | `zuggie/<slug>-<name>` | `.zuggie/zuggie/<slug>-<name>` |

The `<slug>` is derived from the task description: lowercased, non-alphanumeric characters replaced with hyphens, truncated to 50 characters. If a branch with that name exists, a 4-character hex suffix is appended.

The `<name>` for sub-worktrees is provided by the orchestrator when calling `create_worktree`. The daemon does not interpret it — it's an opaque label.

### Creation

Feature worktree (during `session.create`):

```
git worktree add <project>/.zuggie/zuggie/<slug> -b zuggie/<slug>
```

Sub-worktree (during orchestrator execution via `create_worktree`):

```
git worktree add <project>/.zuggie/zuggie/<slug>-<name> -b zuggie/<slug>-<name> zuggie/<slug>
```

Sub-worktrees branch from the feature branch, not from the base branch.

### Merge

The orchestrator triggers merges via the `merge_branch` skill. Merge always targets the feature branch:

1. Acquire the git operation lock
2. `git -C <feature_worktree> merge <source_branch> --no-edit`
3. If merge conflicts: abort merge, return conflict file list to orchestrator
4. Release lock

**The `merge_branch` tool rejects any target that is `main`, `master`, or the session's `base_branch`. The daemon never merges into the base branch.**

### Cleanup Rules

| Event | Feature worktree | Sub-worktrees | Branches |
|-------|------------------|---------------|----------|
| Session completes | Kept | Removed | Sub-worktree branches deleted, feature branch kept |
| Session cancelled | Removed | Removed | All branches deleted |
| Session failed | Kept (debugging) | Kept (debugging) | All branches kept |
| Explicit `session.cleanup` | Removed | Removed | Deleted unless `keep_branch: true` |

Worktree removal sequence:

```
git worktree remove <path> --force
git branch -D <branch>
```

### Git Operation Lock

A single `asyncio.Lock` for the project. Acquired for any mutating git operation:
- `git worktree add`
- `git worktree remove`
- `git merge`
- `git commit`
- `git branch -D`

Read operations (`git diff`, `git log`, `git branch --show-current`) do not acquire the lock.

---

## 6. Agent Runtime

### Agent Types

| Type | Model | SDK Tools | MCP Tools | Purpose |
|------|-------|-----------|-----------|---------|
| `orchestrator` | opus | Read, Grep, Glob | Orchestrator skills (see below) | Drives session workflow, spawns sub-agents |
| `explorer` | sonnet | Read, Grep, Glob | `git_status`, `git_diff`, `git_log` | Lightweight codebase reconnaissance |
| `tech_lead` | opus | Read, Grep, Glob, Bash | `git_status`, `git_diff`, `git_log` | Produces implementation plan |
| `engineer` | sonnet | Read, Write, Edit, Bash, Grep, Glob | `git_commit`, `git_status`, `git_diff`, `git_log` | Implements work in a worktree |
| `reviewer` | opus | Read, Grep, Glob | `git_diff`, `git_log` | Reviews diffs, produces verdict |

### MCP Tools

The daemon exposes MCP tools to agents. Different agent types get different tool sets.

#### Git Tools (Sub-Agent MCP Server)

These replace direct `git` command usage. The daemon implements each one scoped to the agent's worktree, acquiring the git lock for mutating operations.

| Tool | Parameters | Returns | Mutating? | Description |
|------|------------|---------|-----------|-------------|
| `git_status` | `{}` | `{status: string}` | No | `git status` in agent's worktree |
| `git_diff` | `ref?, staged?` | `{diff: string}` | No | Diff against ref or staged changes |
| `git_log` | `max_count?, ref?` | `{log: string}` | No | Commit history |
| `git_commit` | `message, paths?` | `{sha: string}` | Yes | Stage and commit. Paths default to all changes. |

Agents never run `git` commands directly — `git` is blocked in the PreToolUse hook.

#### Orchestrator Skills (Orchestrator MCP Server)

These are only available to the orchestrator:

| Tool | Parameters | Returns | Description |
|------|------------|---------|-------------|
| `spawn_agent` | `type, worktree?, prompt` | `{agent_id, summary}` | Spawn a sub-agent. Blocks until agent completes. |
| `spawn_agents` | `agents: Array<{type, worktree?, prompt}>` | `Array<{agent_id, summary}>` | Spawn multiple agents in parallel. Blocks until all complete. |
| `create_worktree` | `name` | `{path, branch}` | Create a sub-worktree branching from the feature branch |
| `remove_worktree` | `path` | `{}` | Remove a worktree and its branch |
| `merge_branch` | `source_branch, target_worktree` | `{success, conflicts?}` | Merge source into target |
| `get_diff` | `base, head` | `{diff}` | `git diff <base>...<head>` |
| `get_session_state` | `{}` | `{session, agents}` | Current session state |
| `update_plan` | `plan` | `{}` | Persist plan JSON to session record |
| `create_pr` | `title, body, base?` | `{url, number}` | Create a GitHub PR from the feature branch |

### Isolation

#### Layer 1: OS-Level Sandbox (Primary)

Every agent session is created with `sandbox.enabled = True`. The SDK uses OS-level primitives (`sandbox-exec` on macOS, `bubblewrap` on Linux) to enforce filesystem and network boundaries. All child processes (including Bash commands) inherit these restrictions.

The daemon sets `cwd` to the agent's assigned worktree. The sandbox automatically grants read/write access to `cwd`, so no explicit `allowWrite` is needed for the worktree itself. This is the primary isolation mechanism — enforced by the OS, not by hooks or instructions.

**Orchestrator:** `cwd` = feature worktree.
**Sub-agents:** `cwd` = their assigned worktree (feature or sub-worktree).

```python
ClaudeAgentOptions(
    cwd="/path/to/worktree",
    sandbox={
        "enabled": True,
        "autoAllowBashIfSandboxed": True,
    }
)
```

#### Layer 2: `disallowed_tools`

The SDK's `disallowed_tools` list is always enforced, even in `bypassPermissions` mode. Used to hard-block tools by agent type.

All agent types have `Agent` in their `disallowed_tools` — the SDK's built-in subagent spawning is never used. All agent spawning goes through the daemon's `spawn_agent`/`spawn_agents` MCP tools, giving the daemon full control over each sub-agent's `cwd`, sandbox, and tool restrictions.

| Agent Type | `disallowed_tools` |
|------------|-------------------|
| Orchestrator | `Write`, `Edit`, `Bash`, `Agent` |
| Tech-lead | `Write`, `Edit`, `Agent` |
| Engineer | `Agent` |
| Reviewer | `Write`, `Edit`, `Bash`, `Agent` |
| Explorer | `Write`, `Edit`, `Agent` |

#### Layer 3: PreToolUse Hook (Defense-in-Depth)

A hook on sub-agent sessions blocks `git` commands in Bash entirely. All git operations go through MCP tools (Section 6), which the daemon implements with proper scoping and locking.

Pattern: block any Bash command starting with `git `.

#### Layer 4: Git Operation Serialization

The project's `asyncio.Lock` (Section 5) prevents concurrent mutating git operations. The MCP git tools acquire this lock for mutating operations (`git_commit`) and release it after completion.

---

## 7. Protocol Specification

Wire format: JSON-RPC 2.0 over newline-delimited JSON on a Unix socket.

### Envelopes

**Request:**
```typescript
{
  jsonrpc: "2.0";
  id: number | string;
  method: string;
  params?: object;
}
```

**Success response:**
```typescript
{
  jsonrpc: "2.0";
  id: number | string;
  result: object;
}
```

**Error response:**
```typescript
{
  jsonrpc: "2.0";
  id: number | string;
  error: {
    code: number;
    message: string;
    data?: object;
  };
}
```

**Server-pushed notification (no `id`):**
```typescript
{
  jsonrpc: "2.0";
  method: string;
  params: object;
}
```

### Error Codes

| Code | Name | Description |
|------|------|-------------|
| `-32700` | `PARSE_ERROR` | Invalid JSON |
| `-32600` | `INVALID_REQUEST` | Not a valid JSON-RPC request |
| `-32601` | `METHOD_NOT_FOUND` | Unknown method |
| `-32602` | `INVALID_PARAMS` | Invalid method parameters |
| `-32603` | `INTERNAL_ERROR` | Unexpected daemon error |
| `2001` | `SESSION_NOT_FOUND` | No session with given ID |
| `2002` | `SESSION_NOT_RUNNING` | Operation requires session in `running` state |
| `2003` | `SESSION_NOT_RESUMABLE` | Session is not in `interrupted` state |
| `2004` | `SESSION_ALREADY_SUBSCRIBED` | Client already subscribed to this session |
| `3001` | `WORKTREE_ERROR` | Git worktree operation failed |
| `3002` | `MERGE_CONFLICT` | Merge produced conflicts |

---

### Methods

#### `session.create`

Create a new session. Provisions a worktree and spawns the orchestrator agent.

**Params:**
```typescript
{
  task: string;              // Task description for the orchestrator
  base_branch?: string;      // Default: current HEAD branch of the project
}
```

**Result:**
```typescript
{
  session_id: string;         // UUIDv4
  feature_branch: string;     // e.g. "zuggie/add-auth-refresh"
  worktree_path: string;      // Absolute path
  status: "creating";
}
```

The session transitions to `running` asynchronously once the worktree is ready and the orchestrator is spawned. Clients should subscribe to receive the transition event.

**Errors:** `WORKTREE_ERROR`

---

#### `session.list`

List sessions, optionally filtered by status.

**Params:**
```typescript
{
  status?: string | string[];     // Filter by status(es)
  limit?: number;                 // Default 50
  offset?: number;                // Default 0
}
```

**Result:**
```typescript
{
  sessions: Array<{
    id: string;
    status: string;
    task: string;
    feature_branch: string;
    created_at: string;
    updated_at: string;
  }>;
  total: number;
}
```

---

#### `session.get`

Get full details for a session including agent history.

**Params:**
```typescript
{ session_id: string }
```

**Result:**
```typescript
{
  id: string;
  status: string;
  task: string;
  base_branch: string;
  feature_branch: string;
  worktree_path: string | null;
  plan: object | null;
  agents: Array<{
    id: string;
    type: string;
    status: string;
    worktree_path: string | null;
    summary: string | null;
    created_at: string;
    completed_at: string | null;
  }>;
  created_at: string;
  updated_at: string;
}
```

**Errors:** `SESSION_NOT_FOUND`

---

#### `session.cancel`

Cancel a running session. All agent tasks are cancelled, worktrees are removed.

**Params:**
```typescript
{ session_id: string }
```

**Result:**
```typescript
{ status: "cancelled" }
```

**Errors:** `SESSION_NOT_FOUND`, `SESSION_NOT_RUNNING`

---

#### `session.resume`

Resume an interrupted session. Re-spawns the orchestrator with the saved plan and session state.

**Params:**
```typescript
{ session_id: string }
```

**Result:**
```typescript
{
  session_id: string;
  status: "running";
}
```

**Errors:** `SESSION_NOT_FOUND`, `SESSION_NOT_RESUMABLE`

---

#### `session.cleanup`

Remove worktrees and optionally delete branches for a terminal session.

**Params:**
```typescript
{
  session_id: string;
  keep_branch?: boolean;     // Default false. If true, keep the feature branch.
}
```

**Result:**
```typescript
{
  removed_worktrees: string[];    // Paths that were removed
  deleted_branches: string[];     // Branch names that were deleted
}
```

**Errors:** `SESSION_NOT_FOUND`

---

#### `session.subscribe`

Subscribe to streaming events for a session. After this call, the server sends `session.event` notifications for the specified session on this connection.

**Params:**
```typescript
{ session_id: string }
```

**Result:**
```typescript
{}
```

**Errors:** `SESSION_NOT_FOUND`, `SESSION_ALREADY_SUBSCRIBED`

---

#### `session.unsubscribe`

Stop receiving streaming events for a session on this connection.

**Params:**
```typescript
{ session_id: string }
```

**Result:**
```typescript
{}
```

**Errors:** `SESSION_NOT_FOUND`

---

#### `daemon.status`

Health check and summary statistics.

**Params:**
```typescript
{}
```

**Result:**
```typescript
{
  pid: number;
  uptime_seconds: number;
  version: string;
  project_path: string;
  current_branch: string;
  active_sessions: number;
  connected_clients: number;
}
```

---

#### `daemon.shutdown`

Initiate graceful shutdown. The daemon sends the response, then begins the shutdown sequence (Section 2).

**Params:**
```typescript
{}
```

**Result:**
```typescript
{}
```

---

## 8. Streaming Events

After a client calls `session.subscribe`, the daemon pushes `session.event` notifications for that session. Envelope:

```typescript
{
  jsonrpc: "2.0";
  method: "session.event";
  params: {
    session_id: string;
    event_type: string;
    timestamp: string;       // ISO 8601
    data: object;            // Varies by event_type
  };
}
```

### Event Types

#### `session_status_changed`

```typescript
{
  previous_status: string;
  new_status: string;
}
```

#### `agent_spawned`

```typescript
{
  agent_id: string;
  agent_type: "tech_lead" | "engineer" | "reviewer" | "explorer";
  worktree_path: string | null;
}
```

#### `agent_output`

Streaming text chunk from an agent (for live display).

```typescript
{
  agent_id: string;
  agent_type: string;
  chunk: string;
}
```

#### `agent_tool_use`

```typescript
{
  agent_id: string;
  agent_type: string;
  tool_name: string;
  input_summary: string;     // Truncated/summarised tool input
}
```

#### `agent_tool_blocked`

```typescript
{
  agent_id: string;
  agent_type: string;
  tool_name: string;
  reason: string;
}
```

#### `agent_completed`

```typescript
{
  agent_id: string;
  agent_type: string;
  summary: string;
  status: "completed" | "failed";
}
```

#### `plan_updated`

The plan is an opaque JSON blob owned by the orchestrator. The daemon persists it but does not interpret its structure.

```typescript
{
  plan: object;
}
```

#### `worktree_created`

```typescript
{
  path: string;
  branch: string;
  type: "feature" | "sub";
}
```

#### `worktree_removed`

```typescript
{
  path: string;
  branch: string;
}
```

#### `merge_completed`

```typescript
{
  source_branch: string;
  target_branch: string;
  success: boolean;
  conflicts: string[] | null;
}
```

#### `session_completed`

Terminal event. No more events follow after this.

```typescript
{
  status: "completed" | "failed" | "cancelled";
  summary: string | null;       // Orchestrator's final summary (if completed)
  error: string | null;         // Error message (if failed)
  duration_seconds: number;
}
```

---

## 9. Configuration

### Per-Project Config: `<project>/.zuggie/config.toml`

Project-specific configuration. Takes precedence over global defaults.

```toml
[daemon]
log_dir = ".zuggie/logs"              # Relative to project root

[daemon.limits]
max_concurrent_sessions = 5
max_agents_per_session = 10

[agents]
orchestrator_model = "claude-opus-4-20250514"
tech_lead_model = "claude-opus-4-20250514"
engineer_model = "claude-sonnet-4-20250514"
reviewer_model = "claude-opus-4-20250514"
explorer_model = "claude-sonnet-4-20250514"
max_agent_turns = 200
max_concurrent_agents = 3             # Max parallel sub-agents per session

[agents.api]
provider = "anthropic"
# API key read from ANTHROPIC_API_KEY env var

[session]
base_branch = ""                      # Default: auto-detect from HEAD
```

### Global Defaults: `~/.zuggie/config.toml`

Same schema as per-project config. Values here are used when the per-project config does not specify a key.

### Filesystem Layout

```
<project>/
  .zuggie/
    config.toml                # Project-level configuration
    zuggie.sock                # Unix socket (runtime only)
    zuggie.pid                 # PID file (runtime only)
    db.sqlite                  # All persistent state
    logs/
      daemon.log
      sessions/
        <session-id>.log       # Per-session agent transcript
    zuggie/<slug>/             # Feature worktree
    zuggie/<slug>-<name>/      # Sub-worktree

~/.zuggie/
  config.toml                  # Global defaults (optional)
```

---

## Appendix: Future Scope

Explicitly out of scope for this specification:

- **Event sources** — GitHub webhooks, file watchers, and automatic session triggering
- **`session.send_message`** — interactive user input to running sessions
- **Cross-project orchestration** — coordinating sessions across multiple daemon instances
- **Frontend implementation** — TUI, webapp, CLI client details
