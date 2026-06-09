#!/usr/bin/env python3
"""
mq-mcp review helper: reads selected script files, sends them through the
mq-mcp review engine (contract + skill + severity parser), and prints structured
findings. Never modifies files.

Requires OPENAI_API_KEY in environment or mq-mcp/.env.
"""

from __future__ import annotations

import argparse
import importlib
import os
import sys
from pathlib import Path

MQ_MCP_HOME = Path(os.getenv("MQ_MCP_HOME", str(Path.home() / "mq-mcp")))

DEFAULT_MODE = os.getenv("MQ_MCP_REVIEW_MODE", "comment")
DEFAULT_MAX_FILES = int(os.getenv("MQ_MCP_REVIEW_MAX_FILES", "8"))
DEFAULT_MAX_BYTES = int(os.getenv("MQ_MCP_REVIEW_MAX_BYTES", "80000"))

ALLOWED_SUFFIXES = {".py", ".sh", ".bash", ".zsh", ".md", ".json"}

SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__",
    ".mypy_cache", ".pytest_cache", "backups", "dist", "build",
}

SECRET_NAME_PARTS = {
    ".env", "id_rsa", "id_ed25519", "private", "secret", "token",
}


def _load_env() -> None:
    """Load OPENAI_API_KEY from mq-mcp/.env if not already set."""
    if os.environ.get("OPENAI_API_KEY"):
        return
    env_file = MQ_MCP_HOME / "mq-mcp" / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def _bootstrap_review_engine() -> None:
    """Add mq-mcp paths to sys.path so review engine modules are importable."""
    for p in [str(MQ_MCP_HOME), str(MQ_MCP_HOME / "mq-mcp")]:
        if p not in sys.path:
            sys.path.insert(0, p)


def is_secret_like(path: Path) -> bool:
    lowered = path.name.lower()
    return any(part in lowered for part in SECRET_NAME_PARTS)


def is_allowed_file(path: Path) -> bool:
    if not path.is_file():
        return False
    if path.suffix.lower() not in ALLOWED_SUFFIXES:
        return False
    if is_secret_like(path):
        return False
    return True


def iter_target_files(targets: list[str], max_files: int) -> list[Path]:
    found: list[Path] = []

    for raw in targets:
        target = Path(raw).expanduser()

        if not target.exists():
            print(f"WARN: target does not exist: {raw}", file=sys.stderr)
            continue

        if target.is_file():
            if is_allowed_file(target):
                found.append(target.resolve())
            continue

        if target.is_dir():
            for path in sorted(target.rglob("*")):
                if len(found) >= max_files:
                    return found
                if any(part in SKIP_DIRS for part in path.parts):
                    continue
                if is_allowed_file(path):
                    found.append(path.resolve())

    return found[:max_files]


def load_contract(mode: str) -> str:
    contracts_dir = MQ_MCP_HOME / "reviews" / "contracts"
    candidate = contracts_dir / f"{mode}-review.md"
    fallback = contracts_dir / "comment-review.md"
    if candidate.exists():
        return candidate.read_text(encoding="utf-8")
    if fallback.exists():
        return fallback.read_text(encoding="utf-8")
    return ""


def load_skill_for(path: Path, mode: str) -> tuple[str, str]:
    """Route the file to a review skill. Falls back to shell-review for .sh files."""
    skills_dir = MQ_MCP_HOME / "reviews" / "skills"

    try:
        review_router = importlib.import_module("review_engine.review_router")
        route_file = getattr(review_router, "route_file", None)
        if callable(route_file):
            fake_rel = path.name
            name, content = route_file(fake_rel)
            if name != "none":
                return name, content
    except Exception:
        pass

    # Explicit fallback by extension
    suffix = path.suffix.lower()
    skill_map = {
        ".sh": "shell-review.md",
        ".bash": "shell-review.md",
        ".zsh": "shell-review.md",
        ".py": "python-comment-review.md",
        ".md": "markdown-review.md",
        ".json": "json-review.md",
    }
    skill_file = skills_dir / skill_map.get(suffix, "")
    if skill_file.exists():
        return skill_file.stem, skill_file.read_text(encoding="utf-8")

    return "none", ""


def review_file(
    path: Path,
    contract: str,
    model: str,
    mode: str,
    deep: bool,
    max_bytes: int,
) -> str:
    try:
        data = path.read_bytes()
    except Exception as exc:
        return f"Could not read file: {exc}"

    if len(data) > max_bytes:
        return f"File too large ({len(data)} bytes > {max_bytes}), skipped."

    content = data.decode("utf-8", errors="replace")
    skill_name, skill_content = load_skill_for(path, mode)

    try:
        openai = importlib.import_module("openai")
    except Exception as exc:
        return f"OpenAI client not available: {exc}"

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        return "OPENAI_API_KEY not set."

    client = openai.OpenAI(api_key=api_key)

    try:
        severity_engine = importlib.import_module("review_engine.severity_engine")
        parse_findings = getattr(severity_engine, "parse_findings")
        format_summary = getattr(severity_engine, "format_summary")

        if deep:
            multi_pass = importlib.import_module("review_engine.multi_pass_reviewer")
            MultiPassReviewer = getattr(multi_pass, "MultiPassReviewer")
            reviewer = MultiPassReviewer(client, model)
            result = reviewer.run(
                file_path=path.name,
                file_content=content,
                contract=contract,
                skill_content=skill_content,
                skill_name=skill_name,
            )
            return result.output

        skill_section = (
            f"\n\n## Skill: {skill_name}\n\n{skill_content}" if skill_content else ""
        )
        system = (
            "You are a code review engine operating under a strict review contract.\n"
            "Follow the contract exactly. Do not deviate from the output format.\n"
            "Do not modify code. Output only structured review findings.\n\n"
            f"{contract}{skill_section}"
        )
        user = (
            f"Review this file under the contract above.\n\n"
            f"File: {path.name}\n\n"
            f"```\n{content}\n```"
        )

        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            max_tokens=2048,
        )
        raw = (response.choices[0].message.content or "").strip()
        findings = parse_findings(raw)
        return format_summary(findings, path.name) if findings else raw

    except Exception as exc:
        return f"Review failed: {exc}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Review scripts with mq-mcp review engine for structured findings."
    )
    parser.add_argument(
        "targets",
        nargs="*",
        default=["."],
        help="Files or directories to review. Defaults to current directory.",
    )
    parser.add_argument(
        "--mode",
        default=DEFAULT_MODE,
        choices=["comment", "security", "architecture"],
        help=f"Review mode (default: {DEFAULT_MODE})",
    )
    parser.add_argument(
        "--deep",
        action="store_true",
        help="Run multi-pass review (structure + review + consistency). ~3x API calls.",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=DEFAULT_MAX_FILES,
        help=f"Max files to review (default: {DEFAULT_MAX_FILES})",
    )
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=DEFAULT_MAX_BYTES,
        help=f"Max bytes per file (default: {DEFAULT_MAX_BYTES})",
    )

    args = parser.parse_args()

    _load_env()
    _bootstrap_review_engine()

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set in environment or mq-mcp/.env", file=sys.stderr)
        return 1

    model = os.environ.get("OPENAI_MODEL", "gpt-4.1-mini")
    contract = load_contract(args.mode)
    if not contract:
        print(f"ERROR: No review contract found for mode '{args.mode}'", file=sys.stderr)
        return 1

    files = iter_target_files(args.targets, args.max_files)

    print("# mq-mcp Review")
    print(f"# Mode:      {args.mode}{'  [deep]' if args.deep else ''}")
    print(f"# Model:     {model}")
    print(f"# Files:     {len(files)}")
    print()

    if not files:
        print("NO_SUPPORTED_FILES_FOUND")
        return 1

    for index, path in enumerate(files, start=1):
        print("=" * 80)
        print(f"FILE {index}/{len(files)}: {path}")
        print("=" * 80)
        print()

        result = review_file(
            path=path,
            contract=contract,
            model=model,
            mode=args.mode,
            deep=args.deep,
            max_bytes=args.max_bytes,
        )
        print(result)
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
