from __future__ import annotations

import json
import shutil
import subprocess


def call_inspect(path: str = ".") -> dict:
    """Run repo-signal inspect --json and return parsed dict. Empty dict on failure."""
    if shutil.which("repo-signal") is None:
        return {"_error": "repo-signal not found in PATH"}
    result = subprocess.run(
        ["repo-signal", "inspect", path, "--json"],
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(result.stdout)
    except (json.JSONDecodeError, ValueError):
        return {"_error": result.stderr or "could not parse repo-signal output"}


def repo_name(data: dict) -> str:
    return str(data.get("repo", {}).get("name", "unknown"))


def git_summary(data: dict) -> str:
    git = data.get("git", {})
    branch = git.get("branch", "?")
    clean = git.get("clean", True)
    state = "clean" if clean else f"dirty ({git.get('change_count', '?')} changes)"
    return f"{branch}  {state}"


def readiness_summary(data: dict) -> str:
    pr = data.get("public_readiness", {})
    if not pr.get("available"):
        return "unavailable"
    score = pr.get("score", "?")
    total = pr.get("total", "?")
    status = pr.get("status", "?")
    return f"{score}/{total}  {status}"


def issues(data: dict) -> list[dict]:
    return [item for item in data.get("issues", []) if isinstance(item, dict)]


def has_issues(data: dict) -> bool:
    return bool(issues(data))


def render_repo_status(data: dict) -> str:
    if "_error" in data:
        return f"  Error: {data['_error']}"
    lines: list[str] = []
    lines.append(f"  Repo:       {repo_name(data)}")
    lines.append(f"  Git:        {git_summary(data)}")
    lines.append(f"  Readiness:  {readiness_summary(data)}")
    open_issues = issues(data)
    if open_issues:
        lines.append("")
        lines.append(f"  Issues ({len(open_issues)}):")
        for item in open_issues:
            level = item.get("level", "?").upper()
            msg = item.get("message", str(item))
            lines.append(f"  [{level}]  {msg}")
    else:
        lines.append("  Issues:     none")
    return "\n".join(lines)
