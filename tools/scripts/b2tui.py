#!/usr/bin/env python3
"""b2tui — B2 Atlas Prompt OS terminal interface."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

VAULT = Path.home() / "mqobsidian"
PROMPTS_DIR = VAULT / "_prompts" / "saved-prompts-md-export"
HISTORY_FILE = Path.home() / ".b2tui_history.jsonl"

SKIP_FILES = {"INDEX.md", "README.md", "EXPORT_NOTES.md", "PROMPT_EXPORT_INDEX.md"}

ROUTES: dict[str, list[str]] = {
    "architecture": [
        "design", "blueprint", "component", "integration", "structure",
        "arkitektur", "system", "hld", "lld", "requirements", "krav",
    ],
    "implementation": [
        "kod", "code", "config", "flow", "test", "rollback",
        "implementation", "bygga", "bygg", "deploy", "operationer", "raci",
    ],
    "review": [
        "granska", "review", "audit", "kontrakt", "repo-status",
        "inspect", "check", "kritik",
    ],
    "research": [
        "undersök", "tech", "evaluation", "research", "ny teknik",
        "market", "analys", "jämför", "compare",
    ],
    "content": [
        "rapport", "presentation", "tui", "tool", "docs", "interactive",
        "report", "write", "skriva", "content",
    ],
    "learning": [
        "förstå", "lär", "concept", "repetera", "learning",
        "explain", "förklara", "feynman",
    ],
    "decision": [
        "prioritera", "välj", "approach", "roadmap", "decision",
        "decide", "strategi", "strategy",
    ],
}

ROUTE_PRIMARY: dict[str, str] = {
    "architecture": "02.11",
    "implementation": "02.03",
    "review": "02.10",
    "research": "04.02",
    "content": "05.03",
    "learning": "06.01",
    "decision": "03.04",
}


@dataclass
class Prompt:
    id: str
    name: str
    category: str
    path: Path


def _parse_id(filename: str) -> str:
    m = re.match(r"^(\d+\.\d+)", filename)
    return m.group(1) if m else ""


def _parse_name(filename: str) -> str:
    stem = Path(filename).stem
    m = re.match(r"^\d+\.\d+_?(.*)", stem)
    raw = m.group(1) if m else stem
    return raw.replace("_", " ").strip()


def _parse_category(dir_name: str) -> str:
    m = re.match(r"^\d+_(.*)", dir_name)
    raw = m.group(1) if m else dir_name
    return raw.replace("_", " ")


def load_prompts() -> list[Prompt]:
    if not PROMPTS_DIR.exists():
        return []
    prompts: list[Prompt] = []
    for cat_dir in sorted(PROMPTS_DIR.iterdir()):
        if not cat_dir.is_dir():
            continue
        category = _parse_category(cat_dir.name)
        for f in sorted(cat_dir.iterdir()):
            if f.name in SKIP_FILES or f.suffix != ".md":
                continue
            pid = _parse_id(f.name)
            if not pid:
                continue
            prompts.append(Prompt(id=pid, name=_parse_name(f.name), category=category, path=f))
    return prompts


def find_prompt(prompts: list[Prompt], query: str) -> Prompt | None:
    query = query.strip().lower()
    for p in prompts:
        if p.id.lower() == query:
            return p
    for p in prompts:
        if query in p.name.lower():
            return p
    return None


def _copy_to_clipboard(text: str) -> bool:
    try:
        subprocess.run(["pbcopy"], input=text.encode(), check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def _save_history(entry: dict) -> None:
    with HISTORY_FILE.open("a") as fh:
        fh.write(json.dumps(entry) + "\n")


def cmd_projects(prompts: list[Prompt], _args: argparse.Namespace) -> int:
    if not prompts:
        print(f"No prompts found in {PROMPTS_DIR}", file=sys.stderr)
        return 1
    current_cat = ""
    for p in prompts:
        if p.category != current_cat:
            if current_cat:
                print()
            print(f"  {p.category}")
            print(f"  {'─' * len(p.category)}")
            current_cat = p.category
        print(f"    {p.id:<8} {p.name}")
    print(f"\n  {len(prompts)} prompts total")
    return 0


def cmd_run(prompts: list[Prompt], args: argparse.Namespace) -> int:
    target = find_prompt(prompts, args.id)
    if target is None:
        print(f"Prompt '{args.id}' not found. Run 'b2tui projects' to list all.", file=sys.stderr)
        return 1

    content = target.path.read_text()

    print(f"\n  {target.id} — {target.name}")
    print(f"  {'─' * 50}")
    preview_lines = content.splitlines()[:12]
    for line in preview_lines:
        print(f"  {line}")
    if len(content.splitlines()) > 12:
        print(f"  … ({len(content.splitlines())} lines total)")

    print()
    if args.context:
        user_context = args.context
    else:
        try:
            user_context = input("  Context (what are you working on?): ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n  Cancelled.")
            return 0

    composed = f"{content}\n\n---\n\nContext:\n{user_context}" if user_context else content

    copied = _copy_to_clipboard(composed)
    status = "Copied to clipboard." if copied else "pbcopy not available — printing prompt:"
    print(f"\n  {status}")
    if not copied:
        print(composed)

    _save_history({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "prompt_id": target.id,
        "prompt_name": target.name,
        "category": target.category,
        "context": user_context,
    })

    return 0


def cmd_route(prompts: list[Prompt], args: argparse.Namespace) -> int:
    task = args.task.lower()
    scores: dict[str, int] = {route: 0 for route in ROUTES}
    for route, keywords in ROUTES.items():
        for kw in keywords:
            if kw in task:
                scores[route] += 1

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    best_route, best_score = ranked[0]

    if best_score == 0:
        print("  No clear route match — defaulting to: architecture")
        best_route = "architecture"

    primary_id = ROUTE_PRIMARY[best_route]
    primary = find_prompt(prompts, primary_id)

    print(f"\n  Route: {best_route}")
    if primary:
        print(f"  Primary prompt: {primary.id} — {primary.name}")
    print()

    print("  All route scores:")
    for route, score in ranked:
        marker = "→" if route == best_route else " "
        pid = ROUTE_PRIMARY[route]
        p = find_prompt(prompts, pid)
        pname = p.name if p else pid
        print(f"  {marker} {route:<14} {score}  ({pid} {pname})")

    if primary and not args.no_run:
        print()
        try:
            run = input("  Run this prompt? [Y/n]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return 0
        if run in ("", "y", "yes", "ja"):
            run_args = argparse.Namespace(id=primary.id, context=None)
            return cmd_run(prompts, run_args)

    return 0


def cmd_validate(prompts: list[Prompt], _args: argparse.Namespace) -> int:
    if not PROMPTS_DIR.exists():
        print(f"  FAIL  prompts dir not found: {PROMPTS_DIR}", file=sys.stderr)
        return 1

    errors = 0
    for p in prompts:
        if not p.path.exists():
            print(f"  FAIL  {p.id}  file missing: {p.path}")
            errors += 1
            continue
        content = p.path.read_text().strip()
        if not content:
            print(f"  WARN  {p.id}  file is empty")
        elif len(content) < 50:
            print(f"  WARN  {p.id}  very short content ({len(content)} chars)")
        else:
            print(f"  OK    {p.id}  {p.name}")

    print(f"\n  {len(prompts)} prompts checked, {errors} errors")
    if errors:
        return 1

    for route, pid in ROUTE_PRIMARY.items():
        p = find_prompt(prompts, pid)
        if p is None:
            print(f"  WARN  route '{route}' primary prompt {pid} not found")

    return 0


def cmd_history(_prompts: list[Prompt], args: argparse.Namespace) -> int:
    if not HISTORY_FILE.exists():
        print("  No history yet.")
        return 0
    lines = HISTORY_FILE.read_text().splitlines()
    limit = getattr(args, "limit", 10)
    recent = lines[-limit:]
    for line in recent:
        try:
            entry = json.loads(line)
            ts = entry.get("timestamp", "")[:16].replace("T", " ")
            pid = entry.get("prompt_id", "?")
            name = entry.get("prompt_name", "")
            ctx = entry.get("context", "")[:40]
            print(f"  {ts}  {pid:<8} {name}")
            if ctx:
                print(f"           └─ {ctx}")
        except json.JSONDecodeError:
            continue
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="b2tui",
        description="B2 Atlas Prompt OS — terminal interface",
    )
    sub = parser.add_subparsers(dest="command", metavar="command")

    sub.add_parser("projects", help="List all B2 prompts by category")

    run_p = sub.add_parser("run", help="Run a prompt by ID")
    run_p.add_argument("id", help="Prompt ID, e.g. 02.11")
    run_p.add_argument("--context", "-c", help="Context string (skips interactive prompt)")

    route_p = sub.add_parser("route", help="Find best prompt for a task description")
    route_p.add_argument("task", help="Task description, e.g. 'ta fram blueprint för TUI'")
    route_p.add_argument("--no-run", action="store_true", help="Only show route, don't offer to run")

    sub.add_parser("validate", help="Validate all prompt files are readable")

    hist_p = sub.add_parser("history", help="Show recent runs")
    hist_p.add_argument("--limit", "-n", type=int, default=10, help="Number of entries to show")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        return 0

    prompts = load_prompts()

    dispatch = {
        "projects": cmd_projects,
        "run": cmd_run,
        "route": cmd_route,
        "validate": cmd_validate,
        "history": cmd_history,
    }

    handler = dispatch.get(args.command)
    if handler is None:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 1

    return handler(prompts, args)


if __name__ == "__main__":
    sys.exit(main())
