#!/usr/bin/env python3
"""b2tui — B2 Atlas Prompt OS terminal interface."""
from __future__ import annotations

import argparse
import sys

from mqlaunch.b2_tui.adapters.obsidian_writer import last_run_path, open_file, write_run
from mqlaunch.b2_tui.config import B2_SOURCE_DIR, HISTORY_FILE, PROJECT_INDEX, PROMPTS_DIR, RUNS_DIR
from mqlaunch.b2_tui.core.history import cmd_history
from mqlaunch.b2_tui.core.project_loader import find_prompt, load_prompts
from mqlaunch.b2_tui.core.prompt_composer import cmd_run
from mqlaunch.b2_tui.core.router import cmd_route
from mqlaunch.b2_tui.core.validator import cmd_validate
from mqlaunch.b2_tui.models import Prompt


def cmd_list(prompts: list[Prompt], _args: argparse.Namespace) -> int:
    if not prompts:
        print(f"No prompts found. Check {PROJECT_INDEX}", file=sys.stderr)
        return 1
    current_cat = ""
    for p in prompts:
        if p.category != current_cat:
            if current_cat:
                print()
            print(f"  {p.category}")
            print(f"  {'─' * len(p.category)}")
            current_cat = p.category
        star = " ★" if p.mq_stack else ""
        print(f"    {p.id:<8} {p.name}{star}")
    print(f"\n  {len(prompts)} prompts total")
    return 0


def cmd_categories(prompts: list[Prompt], _args: argparse.Namespace) -> int:
    seen: list[str] = []
    for p in prompts:
        if p.category not in seen:
            seen.append(p.category)
    for cat in seen:
        count = sum(1 for p in prompts if p.category == cat)
        print(f"  {cat}  ({count})")
    print(f"\n  {len(seen)} categories, {len(prompts)} prompts total")
    return 0


def cmd_show(prompts: list[Prompt], args: argparse.Namespace) -> int:
    target = find_prompt(prompts, args.id)
    if target is None:
        print(f"Prompt '{args.id}' not found. Run 'mq b2 list' to see all.", file=sys.stderr)
        return 1
    print(f"\n  {target.id} — {target.name}")
    print(f"  Category:  {target.category}")
    if target.mq_stack:
        print(f"  mq-stack:  {target.mq_stack}")
    print(f"  File:      {target.path}")
    if target.path.exists():
        lines = target.path.read_text().splitlines()
        print(f"\n  {'─' * 50}")
        for line in lines[:15]:
            print(f"  {line}")
        if len(lines) > 15:
            print(f"  … ({len(lines)} lines total)")
    else:
        print("  WARN  file not found on disk", file=sys.stderr)
    print()
    return 0


def cmd_compose(prompts: list[Prompt], args: argparse.Namespace) -> int:
    if not args.task.strip():
        print("  Error: task cannot be empty.", file=sys.stderr)
        return 1
    run_args = argparse.Namespace(id=args.id, context=args.task)
    rc = cmd_run(prompts, run_args)
    if rc == 0 and getattr(args, "review", False):
        return cmd_review_last(prompts, args)
    return rc


def cmd_review_last(_prompts: list[Prompt], args: argparse.Namespace) -> int:
    import shutil
    import subprocess
    path = last_run_path()
    if path is None:
        print("  No runs found. Run 'mq b2 compose' first.", file=sys.stderr)
        return 1
    if shutil.which("mq-agent") is None:
        print("  mq-agent not found in PATH.", file=sys.stderr)
        return 1
    cmd = ["mq-agent", "review", "file", str(path)]
    if getattr(args, "architecture", False):
        cmd.append("--architecture")
    if getattr(args, "security", False):
        cmd.append("--security")
    print(f"  Reviewing: {path.name}")
    return subprocess.run(cmd).returncode


def cmd_route_pipeline(prompts: list[Prompt], args: argparse.Namespace) -> int:
    from mqlaunch.b2_tui.core.router import ROUTE_PRIMARY, route
    best_route, _support, matched_kws = route(args.task)
    prompt_id = ROUTE_PRIMARY[best_route]
    prompt = find_prompt(prompts, prompt_id)

    print()
    print(f"  Routed to: {prompt_id}  {prompt.name if prompt else ''}")
    if matched_kws:
        kw_str = " + ".join(dict.fromkeys(matched_kws))
        print(f"  Reason: {kw_str}")
    print()

    compose_args = argparse.Namespace(
        id=prompt_id,
        task=args.task,
        review=getattr(args, "review", False),
        architecture=getattr(args, "architecture", False),
        security=getattr(args, "security", False),
    )
    return cmd_compose(prompts, compose_args)


def cmd_export_last(_prompts: list[Prompt], _args: argparse.Namespace) -> int:
    path = last_run_path()
    if path is None:
        print("  No runs found in Obsidian yet. Run 'mq b2 compose' first.", file=sys.stderr)
        return 1
    print(f"  Last run: {path}")
    return 0


def cmd_open_last(_prompts: list[Prompt], _args: argparse.Namespace) -> int:
    path = last_run_path()
    if path is None:
        print("  No runs found in Obsidian yet. Run 'mq b2 compose' first.", file=sys.stderr)
        return 1
    open_file(path)
    print(f"  Opened: {path}")
    return 0


def cmd_config(_prompts: list[Prompt], _args: argparse.Namespace) -> int:
    checks = [
        ("B2 source dir",     B2_SOURCE_DIR),
        ("PROJECT_INDEX.md",  PROJECT_INDEX),
        ("Prompts dir",       PROMPTS_DIR),
        ("Obsidian runs dir", RUNS_DIR),
        ("History file dir",  HISTORY_FILE.parent),
    ]
    ok = True
    for label, path in checks:
        exists = path.exists()
        status = "OK  " if exists else "FAIL"
        print(f"  {status}  {label}: {path}")
        if not exists:
            ok = False
    return 0 if ok else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="b2tui",
        description="B2 Atlas Prompt OS — terminal interface",
    )
    sub = parser.add_subparsers(dest="command", metavar="command")

    sub.add_parser("list", help="List all B2 prompts by category")
    sub.add_parser("categories", help="List all categories")

    show_p = sub.add_parser("show", help="Show a single prompt by ID")
    show_p.add_argument("id", help="Prompt ID, e.g. 02.11")

    compose_p = sub.add_parser("compose", help="Compose prompt from ID + task description")
    compose_p.add_argument("id", help="Prompt ID, e.g. 02.11")
    compose_p.add_argument("task", help="Task description")
    compose_p.add_argument("--review", action="store_true", help="Review composed prompt with mq-agent after compose")
    compose_p.add_argument("--architecture", action="store_true", help="Use architecture review mode")
    compose_p.add_argument("--security", action="store_true", help="Use security review mode")

    run_p = sub.add_parser("run", help="Run a prompt by ID (interactive)")
    run_p.add_argument("id", help="Prompt ID, e.g. 02.11")
    run_p.add_argument("--context", "-c", help="Context string (skips interactive prompt)")

    route_p = sub.add_parser("route", help="Find best prompt for a task description")
    route_p.add_argument("task", help="Task description, e.g. 'ta fram blueprint för TUI'")
    route_p.add_argument("--no-run", action="store_true", help="Only show route, don't offer to run")
    route_p.add_argument("--compose", action="store_true", help="Compose with routed prompt (non-interactive)")
    route_p.add_argument("--review", action="store_true", help="Review after compose (implies --compose)")
    route_p.add_argument("--architecture", action="store_true", help="Architecture review mode")
    route_p.add_argument("--security", action="store_true", help="Security review mode")

    sub.add_parser("validate", help="Validate all prompt files are readable")
    sub.add_parser("export-last", help="Show path to last Obsidian run")
    sub.add_parser("open-last", help="Open last Obsidian run in editor")
    sub.add_parser("config", help="Show path configuration status")

    review_p = sub.add_parser("review-last", help="Review last B2 run with mq-agent")
    review_p.add_argument("--architecture", action="store_true", help="Architecture review mode")
    review_p.add_argument("--security", action="store_true", help="Security review mode")

    hist_p = sub.add_parser("history", help="Show recent runs")
    hist_p.add_argument("subcommand", nargs="?", choices=["last", "export"], help="last or export")
    hist_p.add_argument("--limit", "-n", type=int, default=10, help="Number of entries to show")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command is None:
        from mqlaunch.b2_tui.tui.app import B2App
        prompts = load_prompts()
        app = B2App(prompts)
        app.run()
        return 0

    prompts = load_prompts()

    dispatch = {
        "list":       cmd_list,
        "categories": cmd_categories,
        "show":       cmd_show,
        "compose":    cmd_compose,
        "run":        cmd_run,
        "route":      cmd_route,
        "validate":   cmd_validate,
        "export-last":  cmd_export_last,
        "open-last":    cmd_open_last,
        "config":       cmd_config,
        "history":      cmd_history,
        "review-last":  cmd_review_last,
    }

    if args.command == "route" and (getattr(args, "compose", False) or getattr(args, "review", False)):
        return cmd_route_pipeline(prompts, args)

    handler = dispatch.get(args.command)
    if handler is None:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 1

    return handler(prompts, args)


if __name__ == "__main__":
    sys.exit(main())
