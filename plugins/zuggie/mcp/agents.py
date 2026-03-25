"""Agent configuration and CLI invocation logic for the zuggie MCP server."""

import asyncio
import json
import os
from typing import Any

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


async def run_agent(
    agent_type: str,
    cwd: str,
    prompt: str,
    plugin_root: str,
) -> str:
    """Run a claude agent as a subprocess and return the text result.

    Constructs the `claude` CLI command with the appropriate flags for the
    given agent type, executes it in the specified working directory, and
    parses the JSON output to extract the assistant's final text response.

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
    stdout_bytes, stderr_bytes = await proc.communicate()

    if proc.returncode != 0:
        stderr_text = stderr_bytes.decode("utf-8", errors="replace").strip()
        return (
            f"Error: claude subprocess exited with code {proc.returncode}. "
            f"stderr: {stderr_text}"
        )

    # `--output-format stream-json` emits one JSON object per line
    # (newline-delimited JSON). We scan for the last message with
    # type == "result" which carries the assistant's final text response.
    stdout_text = stdout_bytes.decode("utf-8", errors="replace")
    result: str | None = None
    parse_errors: list[str] = []
    for line in stdout_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as exc:
            parse_errors.append(f"{exc}: {line[:120]}")
            continue
        if obj.get("type") == "result":
            result = obj.get("result")

    if result is None:
        errors_detail = "; ".join(parse_errors) if parse_errors else "no result message found"
        return (
            f"Error: could not extract result from claude stream-json output "
            f"({errors_detail}).\nRaw output: {stdout_text[:500]}"
        )

    return str(result)
