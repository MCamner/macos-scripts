#!/usr/bin/env python3
"""MQ Dashboard 2.0: keyboard-only, read-only terminal control surface.

No third-party dependencies. Never persists credentials or invokes mutating commands.
All status values come from real command output, otherwise show UNAVAILABLE.
"""
from __future__ import annotations

import argparse
import curses
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
SECTIONS = (
    "Home", "Repositories", "MCP Services", "AI Models", "Evidence & Learning",
    "GitHub & Releases", "Doctor", "Repair Planner", "Automation", "Help",
)
EVIDENCE_TABS = ("Overview", "Routing", "Hybrid Retrieval", "Memory", "History", "Export")
REPAIR_TABS = ("Overview", "Issues", "Analysis", "Fix Plan", "History", "Settings")
TIMEOUT = 12


def run_readonly(args: list[str], *, cwd: Path | None = None, timeout: int = TIMEOUT) -> tuple[bool, str]:
    """Execute a known read-only command; never invoke a shell."""
    try:
        result = subprocess.run(args, cwd=cwd, text=True, capture_output=True,
                                timeout=timeout, check=False)
        return result.returncode == 0, result.stdout.strip() if result.returncode == 0 else (result.stderr.strip() or "Command failed")
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, type(exc).__name__


def json_command(args: list[str], *, cwd: Path | None = None) -> tuple[dict, str]:
    ok, output = run_readonly(args, cwd=cwd)
    if not ok:
        return {}, "UNAVAILABLE: " + output[:120]
    try:
        value = json.loads(output)
        return value if isinstance(value, dict) else {}, "" if isinstance(value, dict) else "UNAVAILABLE: unexpected JSON"
    except ValueError:
        return {}, "UNAVAILABLE: invalid JSON"


def collect() -> dict:
    """Collect independent health sources; missing data is not success."""
    agent = HOME / "mq-agent"
    agent_cmd = [shutil.which("uv") or "/opt/homebrew/bin/uv", "run", "mq-agent"]
    env_repo = os.environ.get("MQ_STACK_MCP_REPO_PATH")
    # The mq-agent command inherits an explicitly configured checkout path.
    stack, stack_error = json_command(agent_cmd + ["stack", "status", "--json"], cwd=agent)
    routing, route_error = json_command(agent_cmd + ["route", "readiness", "--json"], cwd=agent)
    launchd = []
    for label, port in (("se.mq.mcp", 8765), ("se.mq.image", 8766)):
        ok, output = run_readonly(["launchctl", "print", f"gui/{os.getuid()}/{label}"])
        running = ok and any(x.strip() == "state = running" for x in output.splitlines())
        listen_ok, listen = run_readonly(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"])
        launchd.append({"name": label, "port": port, "state": "RUNNING" if running and listen_ok and bool(listen) else "UNAVAILABLE"})
    models_ok, models = run_readonly(["ollama", "list"], timeout=4)
    gh_ok, gh_output = run_readonly(["gh", "auth", "status"], timeout=4)
    return {"stack": stack, "stack_error": stack_error,
            "routing": routing, "routing_error": route_error,
            "services": launchd, "models": models if models_ok else None,
            "github": "AUTHENTICATED" if gh_ok else "UNAVAILABLE",
            "repo_path_override": env_repo or "not set",
            "collected_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}


def lines_for(section: str, tab: int, data: dict) -> list[str]:
    stack = data["stack"]
    repos = stack.get("repos", [])
    routing = data["routing"]
    tc = routing.get("task_classes", {}).get("docs-review", {})
    actual = tc.get("actual", {})
    route_counts = tc.get("routes", {})
    overall = stack.get("overall", "UNAVAILABLE")
    if section == "Home":
        return [
            "MQ DASHBOARD 2.0  /  CONTROL CENTER",
            "",
            f"Stack: {overall}       GitHub: {data['github']}",
            f"Repositories: {len(repos)} reported       MCP: " +
            ", ".join(s["state"] for s in data["services"]),
            f"Routing: {tc.get('recommendation', 'UNAVAILABLE')}",
            f"Applied docs-review: {actual.get('observations', 'UNAVAILABLE')}",
            f"Collected: {data['collected_at']}",
            "", "Use arrows/Enter to open a section. R refreshes live sources.",
        ]
    if section == "Repositories":
        return ["EXACT-HEAD REPOSITORY VERIFICATION", "",
                *[f"{r.get('name', '?'):<21} {str(r.get('version','?')):<10} {r.get('verification',{}).get('status','UNAVAILABLE'):<12} {(r.get('commit') or '-')[:8]}" for r in repos]] or ["UNAVAILABLE"]
    if section == "MCP Services":
        return ["LAUNCHD / LOCAL PORT HEALTH", "",
                *[f"{x['name']:<21} localhost:{x['port']:<6} {x['state']}" for x in data["services"]],
                "", "Read-only view. Restart requires separate authorized CLI action."]
    if section == "AI Models":
        return ["OLLAMA INSTALLED MODELS (not proof of model availability)", "",
                *(data["models"].splitlines()[:17] if data["models"] else ["UNAVAILABLE: Ollama list failed"])]
    if section == "GitHub & Releases":
        return [f"GitHub CLI: {data['github']}", "", "Repository verification is in Repositories.",
                "No releases or PRs are invented when disconnected."]
    if section == "Doctor":
        return ["READ-ONLY DIAGNOSTICS", "", f"Stack: {overall}",
                f"Stack detail: {data['stack_error'] or 'available'}",
                f"Routing detail: {data['routing_error'] or 'available'}",
                f"MCP checkout override: {data['repo_path_override']}",
                "", "For full diagnostics: mqlaunch doctor"]
    if section == "Evidence & Learning":
        current = EVIDENCE_TABS[tab]
        if current in ("Overview", "Routing"):
            return ["REAL APPLIED docs-review ROUTING EVIDENCE", "",
                f"Recommendation: {tc.get('recommendation', 'UNAVAILABLE')}",
                f"Eligible: {tc.get('eligible', 'UNAVAILABLE')}",
                f"Observations: {actual.get('observations', 'UNAVAILABLE')} / 20",
                f"Routes: {actual.get('candidate_routes', 'UNAVAILABLE')} / 2",
                f"Window (days): {actual.get('window_days', 'UNAVAILABLE')} / 14",
                f"Min samples/route: {actual.get('minimum_samples_per_route', 'UNAVAILABLE')} / 10",
                "", "PER-ROUTE COUNTS",
                *[f"  {name:<24} {number}" for name, number in sorted(route_counts.items())],
                "", "GATES",
                *[f"  {name}: {'PASS' if ok else 'BLOCKED'}" for name, ok in tc.get("gates", {}).items()],
                "", "Readiness does not authorize automatic routing."]
        if current == "History":
            path = HOME / "mq-evidence" / "routing-readiness"
            snaps = sorted(path.glob("*.json"))[-8:] if path.exists() else []
            return ["ROUTING READINESS SNAPSHOTS", "", *([p.name for p in snaps] or ["UNAVAILABLE: no snapshots"])]
        return [current.upper(), "", "UNAVAILABLE: no approved read-only adapter yet.",
                "No synthetic metrics, candidates, or export actions."]
    if section == "Repair Planner":
        current = REPAIR_TABS[tab]
        return [f"REPAIR PLANNER / {current.upper()}", "",
                "READ-ONLY MVP — no automated fixes or writes.",
                "", f"Stack: {overall}",
                f"Unverified or stale repos: {sum(r.get('verification',{}).get('status') != 'VERIFIED' for r in repos) if repos else 'UNAVAILABLE'}",
                "", "Inspect repo status with MQ Doctor.",
                "Proposals require evidence, preview, and explicit operator approval.",
                "Automated repair is DISABLED."]
    if section == "Automation":
        path = HOME / "mq-evidence" / "stack-status"
        snaps = sorted(path.glob("*.json"))[-6:] if path.exists() else []
        return ["EVALUATION SNAPSHOTS", "", *([p.name for p in snaps] or ["UNAVAILABLE: no snapshots"]),
                "", "Scheduling remains owned by launchd, not this dashboard."]
    return ["KEYBOARD NAVIGATION", "", "Up/Down: select section", "Enter: open selected section",
            "Left/Right: change sub-tabs", "Esc: return home", "1-9: jump to section",
            "R: refresh sources", "H: help", "Q: quit",
            "", "Mouse support intentionally disabled. No mutating operations."]


def draw(stdscr, selected: int, opened: bool, tab: int, data: dict, note: str) -> None:
    stdscr.erase()
    height, width = stdscr.getmaxyx()
    if height < 14 or width < 65:
        stdscr.addnstr(0, 0, "MQ Dashboard 2.0: resize terminal (65x14 minimum)", max(1, width-1))
        stdscr.refresh()
        return
    def row(y: int, x: int, value: str, attr: int = 0):
        if y < height-1 and x < width-1:
            stdscr.addnstr(y, x, value, max(1, width-x-1), attr)
    row(0, 1, " MQ DASHBOARD 2.0  |  mqlaunch  |  keyboard only ", curses.A_BOLD)
    row(1, 1, "-" * (width-2))
    navwidth = min(27, width // 3)
    row(3, 2, "MODULES", curses.A_BOLD)
    for i, section in enumerate(SECTIONS):
        row(5+i, 2, f"{i+1 if i<9 else 0:>2}  {section}", curses.A_REVERSE if i == selected else 0)
    x = navwidth + 2
    section = SECTIONS[selected] if opened else "Home"
    row(3, x, section.upper(), curses.A_BOLD)
    tabs = EVIDENCE_TABS if section == "Evidence & Learning" else REPAIR_TABS if section == "Repair Planner" else ()
    if tabs:
        row(4, x, "  ".join(f"[{t}]" if j == tab else t for j, t in enumerate(tabs)))
    text = lines_for(section, tab, data)
    for i, line in enumerate(text[:max(0, height-9)]):
        row(6+i, x, str(line))
    row(height-3, 1, "-" * (width-2))
    row(height-2, 1, "↑↓ select  Enter open  ←→ tabs  Esc back  1-9 quick  R refresh  H help  Q quit")
    if note:
        row(height-4, x, note[:width-x-2], curses.A_BOLD)
    stdscr.refresh()


def interactive(stdscr) -> None:
    curses.curs_set(0)
    stdscr.keypad(True)
    curses.mousemask(0)
    selected, opened, tab = 0, False, 0
    data, note = collect(), ""
    while True:
        draw(stdscr, selected, opened, tab, data, note)
        key = stdscr.getch()
        note = ""
        if key in (ord("q"), ord("Q")):
            break
        if key in (curses.KEY_UP, curses.KEY_DOWN):
            selected = (selected + (1 if key == curses.KEY_DOWN else -1)) % len(SECTIONS)
            tab = 0
        elif key in (10, 13, curses.KEY_ENTER):
            opened = True
        elif key in (27, 127):
            opened, selected, tab = False, 0, 0
        elif key in (curses.KEY_LEFT, curses.KEY_RIGHT):
            tabs = EVIDENCE_TABS if SECTIONS[selected] == "Evidence & Learning" else REPAIR_TABS if SECTIONS[selected] == "Repair Planner" else ()
            if tabs:
                opened = True
                tab = (tab + (1 if key == curses.KEY_RIGHT else -1)) % len(tabs)
        elif key in (ord("r"), ord("R")):
            note = "Refreshing read-only sources..."
            draw(stdscr, selected, opened, tab, data, note)
            data = collect()
            note = "Refreshed " + data["collected_at"]
        elif key in (ord("h"), ord("H")):
            selected, opened, tab = 9, True, 0
        elif ord("1") <= key <= ord("9"):
            selected, opened, tab = key-ord("1"), True, 0
        elif key == ord("0"):
            selected, opened, tab = 9, True, 0


def main() -> int:
    parser = argparse.ArgumentParser(description="MQ Dashboard 2.0")
    parser.add_argument("--json", action="store_true", help="Read-only diagnostics without a terminal")
    args = parser.parse_args()
    if args.json:
        print(json.dumps(collect(), indent=2, ensure_ascii=False))
        return 0
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("MQ Dashboard requires an interactive terminal; use --json for diagnostics.", file=sys.stderr)
        return 2
    try:
        curses.wrapper(interactive)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
