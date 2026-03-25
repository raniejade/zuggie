"""Agent configuration and CLI invocation logic for the zuggie MCP server."""

import asyncio
import json
import os
from typing import Any, TYPE_CHECKING

if TYPE_CHECKING:
    from fastmcp import Context

AGENT_CONFIGS: dict[str, dict[str, Any]] = {
    "engineer": {
        "model": "sonnet",
        "allowed_tools": ["Bash", "Read", "Edit", "Write", "Grep", "Glob"],
        "prompt_file": "agents/zuggie-engineer.md",
    },
    "tech-lead": {
        "model": "opus",
        "allowed_tools": ["Read", "Grep", "Glob", "Bash"],
        "prompt_file": "agents/zuggie-tech-lead.md",
    },
    "reviewer": {
        "model": "opus",
        "allowed_tools": ["Read", "Grep", "Glob"],
        "prompt_file": "agents/zuggie-reviewer.md",
    },
    "explore": {
        "model": "sonnet",
        "allowed_tools": ["Read", "Grep", "Glob", "Bash"],
        "prompt_file": None,
    },
}

_EXPLORE_SYSTEM_PROMPT = (
    "You are an exploration agent. Your job is to investigate and report findings. "
    "Read relevant files, search the codebase, and run commands to answer the questions posed to you. "
    "Return a clear, structured summary of your findings."
)


def load_system_prompt(plugin_root: str, agent_type: str) -> str:
    """Load and return the system prompt for an agent type.

    Reads the agent's .md file and strips the YAML frontmatter (the block
    between the first and second '---' delimiters), returning only the body.
    """
    config = AGENT_CONFIGS.get(agent_type)
    if config is None:
        raise ValueError(f"Unknown agent type: {agent_type!r}")

    prompt_file = config.get("prompt_file")
    if prompt_file is None:
        return _EXPLORE_SYSTEM_PROMPT

    full_path = os.path.join(plugin_root, prompt_file)
    with open(full_path, "r", encoding="utf-8") as fh:
        content = fh.read()

    # Strip YAML frontmatter: everything between the first and second '---'
    if content.startswith("---"):
        end = content.find("---", 3)
        if end != -1:
            content = content[end + 3:].lstrip("\n")

    return content


def _extract_text_from_assistant_message(obj: dict) -> str | None:
    """Extract text content from a stream-json assistant message, if any."""
    message = obj.get("message")
    if not isinstance(message, dict):
        return None
    content = message.get("content")
    if not isinstance(content, list):
        return None
    parts: list[str] = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text":
            text = block.get("text", "")
            if text:
                parts.append(text)
    return "\n".join(parts) if parts else None


async def run_agent(
    agent_type: str,
    cwd: str,
    prompt: str,
    plugin_root: str,
    context: "Context | None" = None,
) -> str:
    """Run a claude agent as a subprocess and return the text result.

    Constructs the `claude` CLI command with the appropriate flags for the
    given agent type, executes it in the specified working directory, and
    parses the JSON output incrementally to extract the assistant's final
    text response.

    If `context` is provided, intermediate assistant messages are sent as
    MCP log notifications so the orchestrator can see live progress.

    Returns an error message string if the subprocess exits non-zero.
    """
    config = AGENT_CONFIGS.get(agent_type)
    if config is None:
        return f"Error: unknown agent type {agent_type!r}"

    model: str = config["model"]
    allowed_tools: list[str] = config["allowed_tools"]
    system_prompt = load_system_prompt(plugin_root, agent_type)

    cmd = [
        "claude",
        "-p", prompt,
        "--output-format", "stream-json",
        "--verbose",
        "--model", model,
        "--allowedTools", ",".join(allowed_tools),
        "--permission-mode", "acceptEdits",
        "--system-prompt", system_prompt,
    ]

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=cwd,
    )

    assert proc.stdout is not None

    result: str | None = None
    parse_errors: list[str] = []
    raw_lines: list[str] = []

    # Read stdout incrementally line by line so we can send progress notifications
    async for raw_line in proc.stdout:
        line = raw_line.decode("utf-8", errors="replace").strip()
        if not line:
            continue
        raw_lines.append(line)
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as exc:
            parse_errors.append(f"{exc}: {line[:120]}")
            continue

        msg_type = obj.get("type")

        if msg_type == "assistant" and context is not None:
            text = _extract_text_from_assistant_message(obj)
            if text:
                try:
                    await context.log(
                        message=f"[{agent_type}] {text}",
                        level="info",
                        logger_name="zuggie.agent",
                    )
                except Exception:
                    # Never let notification failures abort the agent run
                    pass

        elif msg_type == "result":
            result = obj.get("result")

    # Wait for process to finish and collect stderr
    await proc.wait()

    if proc.returncode != 0:
        assert proc.stderr is not None
        stderr_bytes = await proc.stderr.read()
        stderr_text = stderr_bytes.decode("utf-8", errors="replace").strip()
        return (
            f"Error: claude subprocess exited with code {proc.returncode}. "
            f"stderr: {stderr_text}"
        )

    if result is None:
        errors_detail = "; ".join(parse_errors) if parse_errors else "no result message found"
        raw_output = "\n".join(raw_lines)
        return (
            f"Error: could not extract result from claude stream-json output "
            f"({errors_detail}).\nRaw output: {raw_output[:500]}"
        )

    return str(result)
