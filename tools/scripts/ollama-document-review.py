#!/usr/bin/env python3
"""
Review-only helper: reads selected script files, sends them to a local Ollama
model, and prints suggested comment/docstring improvements. Never modifies files.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_MODEL = os.getenv("MQ_OLLAMA_REVIEW_MODEL", "qwen3:4b-instruct")
DEFAULT_MAX_FILES = int(os.getenv("MQ_OLLAMA_REVIEW_MAX_FILES", "8"))
DEFAULT_MAX_BYTES = int(os.getenv("MQ_OLLAMA_REVIEW_MAX_BYTES", "45000"))

ALLOWED_SUFFIXES = {".py", ".sh", ".bash", ".zsh"}

SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__",
    ".mypy_cache", ".pytest_cache", "backups", "dist", "build",
}

SECRET_NAME_PARTS = {
    ".env", "id_rsa", "id_ed25519", "private", "secret", "token", "keychain",
}

SYSTEM_PROMPT = """\
You are MQ Ollama Document Review.

You review source files for documentation improvements only.

Rules:
- Focus on comments, docstrings, function descriptions, section headers,
  safety notes, side effects, and non-obvious logic.
- Do not suggest behavior changes.
- Do not rename functions or variables.
- Do not change command behavior.
- Do not introduce dependencies.
- Avoid obvious noise comments (do not explain what every line does).
- Prefer concise comments that explain WHY something exists.
- If a function touches files, shell commands, credentials, environment
  variables, subprocesses, or network calls, suggest a short safety/side-effect note.
- If no useful improvement is needed, write exactly: NO_COMMENT_CHANGES_NEEDED
- Do not reveal chain-of-thought or internal reasoning.
"""


def ollama_endpoint() -> str:
    explicit = os.getenv("OLLAMA_ENDPOINT")
    if explicit:
        return explicit
    host = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
    return f"{host}/api/generate"


def is_secret_like(path: Path) -> bool:
    lowered = path.name.lower()
    return any(part in lowered for part in SECRET_NAME_PARTS)


def is_allowed_file(path: Path) -> bool:
    if not path.is_file():
        return False
    if path.suffix not in ALLOWED_SUFFIXES:
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


def read_file_limited(path: Path, max_bytes: int) -> str | None:
    data = path.read_bytes()

    if len(data) > max_bytes:
        print(
            f"WARN: skipping large file ({len(data)} bytes > {max_bytes}): {path}",
            file=sys.stderr,
        )
        return None

    return data.decode("utf-8", errors="replace")


def build_prompt(path: Path, content: str) -> str:
    return (
        f"Review this file and suggest documentation/comment improvements.\n\n"
        f"File: {path}\n\n"
        f"Return format:\n"
        f"1. A short summary of what the file does.\n"
        f"2. Suggested comment/docstring improvements.\n"
        f"3. If useful, a small unified diff that only changes comments/docstrings.\n"
        f"4. If nothing should change, write: NO_COMMENT_CHANGES_NEEDED\n\n"
        f"Important:\n"
        f"- Documentation-only suggestions.\n"
        f"- No behavior changes.\n"
        f"- No dependency changes.\n"
        f"- No formatting-only churn.\n\n"
        f"File content:\n```\n{content}\n```\n"
    )


def call_ollama(model: str, endpoint: str, prompt: str) -> str:
    payload = {
        "model": model,
        "system": SYSTEM_PROMPT,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2},
    }

    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=240) as response:
            raw = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            raise RuntimeError(
                f"Model not found in Ollama: {model!r}\n"
                f"Pull it first: ollama pull {model}"
            ) from exc
        raise RuntimeError(
            f"Ollama returned HTTP {exc.code}: {exc.reason}\n"
            f"Endpoint: {endpoint}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(
            f"Could not reach Ollama at {endpoint}\n"
            "Try: ollama serve\n"
            f"Details: {exc}"
        ) from exc

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Ollama returned invalid JSON:\n{raw}") from exc

    return str(parsed.get("response", "")).strip()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Review scripts with local Ollama for better comments/docstrings."
    )
    parser.add_argument(
        "targets",
        nargs="*",
        default=["."],
        help="Files or directories to review. Defaults to current directory.",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Ollama model (default: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--endpoint",
        default=ollama_endpoint(),
        help="Ollama generate endpoint",
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
    files = iter_target_files(args.targets, args.max_files)

    print("# Ollama Document Review")
    print(f"# Model:    {args.model}")
    print(f"# Endpoint: {args.endpoint}")
    print(f"# Files:    {len(files)}")
    print()

    if not files:
        print("NO_SUPPORTED_FILES_FOUND")
        return 1

    for index, path in enumerate(files, start=1):
        content = read_file_limited(path, args.max_bytes)
        if content is None:
            continue

        print("=" * 80)
        print(f"FILE {index}/{len(files)}: {path}")
        print("=" * 80)
        print()

        try:
            result = call_ollama(args.model, args.endpoint, build_prompt(path, content))
        except RuntimeError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1

        print(result if result else "NO_RESPONSE_FROM_OLLAMA")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
