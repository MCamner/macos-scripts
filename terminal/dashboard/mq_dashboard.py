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


def init_palette() -> bool:
    """Use terminal-native colors, with monochrome fallback."""
    if not curses.has_colors() or os.environ.get("NO_COLOR"):
        return False
    curses.start_color()
    try:
        curses.use_default_colors()
    except curses.error:
        pass
    for index, fg in ((1, curses.COLOR_CYAN), (2, curses.COLOR_GREEN),
                      (3, curses.COLOR_YELLOW), (4, curses.COLOR_MAGENTA),
                      (5, curses.COLOR_BLUE)):
        curses.init_pair(index, fg, -1)
    return True


def status_style(value: str, colors: bool) -> int:
    if not colors:
        return curses.A_BOLD
    upper = str(value).upper()
    if upper in ("VERIFIED", "PASS", "RUNNING", "ELIGIBLE", "AUTHENTICATED"):
        return curses.color_pair(2) | curses.A_BOLD
    if upper in ("STALE", "UNVERIFIED", "REQUIRED", "AWAITING_OPERATOR_APPROVAL"):
        return curses.color_pair(3) | curses.A_BOLD
    return curses.color_pair(1)


def draw(stdscr, selected: int, opened: bool, tab: int, data: dict, note: str) -> None:
    """Responsive framed TUI: dashboard grid on wide terminals, single pane on narrow."""
    stdscr.erase()
    height, width = stdscr.getmaxyx()
    if height < 18 or width < 65:
        stdscr.addnstr(0, 0, "MQ Dashboard 2.0: resize terminal (65x18 minimum)", max(1, width - 1))
        stdscr.refresh()
        return
    colors = init_palette()
    cyan = curses.color_pair(1) if colors else curses.A_BOLD
    muted = curses.A_DIM
    highlight = curses.A_REVERSE | curses.A_BOLD

    def put(y: int, x: int, value: str, style: int = 0) -> None:
        if not 0 <= y < height - 1 or not 0 <= x < width - 1:
            return
        try:
            stdscr.addnstr(y, x, str(value), max(1, width - x - 1), style)
        except curses.error:
            pass

    def box(y: int, x: int, h: int, w: int, title: str, body: list[str]) -> None:
        if h < 3 or w < 12:
            return
        right = min(width - 2, x + w - 1)
        bottom = min(height - 4, y + h - 1)
        inner = max(0, right - x - 1)
        put(y, x, "┌" + "─" * inner + "┐", cyan)
        for yy in range(y + 1, bottom):
            put(yy, x, "│", cyan)
            put(yy, right, "│", cyan)
        put(bottom, x, "└" + "─" * inner + "┘", cyan)
        put(y, x + 2, f" {title[:max(1,inner-4)]} ", cyan | curses.A_BOLD)
        for n, line in enumerate(body[:max(0, bottom-y-1)]):
            text = str(line)[:max(1, inner-3)]
            put(y + 1 + n, x + 2, text, status_style(text.split()[-1], colors) if text.split() else 0)

    put(0, 1, " MQ  DASHBOARD 2.0   //   CONTROL CENTER ", cyan | curses.A_BOLD)
    put(0, max(2, width - 23), data.get("collected_at", "UNAVAILABLE")[-19:], muted)
    put(1, 1, "─" * (width - 2), cyan)
    section = SECTIONS[selected] if opened else "Home"
    if section == "Home" and width >= 104 and height >= 38:
        stack = data.get("stack", {})
        repos = stack.get("repos", [])
        routing = data.get("routing", {}).get("task_classes", {}).get("docs-review", {})
        actual = routing.get("actual", {})
        first = 2
        col = (width - 5) // 3
        widths = [col, col, width - 4 - 2 * col]
        xs = [1, 2 + col, 3 + 2 * col]
        box(first, 1, 5, width-2, "STACK HEALTH",
            [f"STACK: {stack.get('overall','UNAVAILABLE')}      GitHub: {data.get('github','UNAVAILABLE')}",
             "MCP: " + ", ".join(f"{svc['name']} {svc['state']}" for svc in data.get("services", []))])
        repo_lines = [f"{r.get('name','?'):<19} {r.get('verification',{}).get('status','UNAVAILABLE')}" for r in repos]
        svc_lines = [f"{svc['name']}  :{svc['port']}  {svc['state']}" for svc in data.get("services", [])]
        ai_lines = (data.get("models") or "UNAVAILABLE").splitlines()[:6]
        box(8, xs[0], 12, widths[0], "REPOSITORIES", repo_lines or ["UNAVAILABLE"])
        box(8, xs[1], 12, widths[1], "MCP SERVICES", svc_lines or ["UNAVAILABLE"])
        box(8, xs[2], 12, widths[2], "AI MODELS", ai_lines)
        box(21, xs[0], 9, widths[0], "EVIDENCE & LEARNING",
            [f"Readiness: {routing.get('recommendation','UNAVAILABLE')}",
             f"Applied: {actual.get('observations','UNAVAILABLE')} / 20",
             f"Routes: {actual.get('candidate_routes','UNAVAILABLE')} / 2",
             f"Window: {actual.get('window_days','UNAVAILABLE')} / 14 days",
             "Approval: REQUIRED"])
        box(21, xs[1], 9, widths[1], "RECENT EVALUATION",
            [p.name for p in sorted((HOME/"mq-evidence"/"stack-status").glob("*.json"))[-5:]]
            if (HOME/"mq-evidence"/"stack-status").exists() else ["UNAVAILABLE"])
        box(21, xs[2], 9, widths[2], "GITHUB & REPAIR",
            [f"GitHub: {data.get('github','UNAVAILABLE')}",
             "Repair Planner: READ-ONLY",
             "No automatic writes or restarts"])
        actions = [f"{i+1 if i<9 else 0}:{name}" for i, name in enumerate(SECTIONS[1:])]
        box(30, 1, min(height-33, 6), width-2, "QUICK ACTIONS  [1-9,0]", ["   ".join(actions[:5]), "   ".join(actions[5:])])
    else:
        navwidth = min(28, width // 3)
        box(3, 1, min(len(SECTIONS)+4,height-8), navwidth, "MODULES",
            [f"{i+1 if i<9 else 0:>2}  {s}" for i,s in enumerate(SECTIONS)])
        for i in range(min(len(SECTIONS),height-9)):
            if i == selected:
                put(4+i, 3, f"{i+1 if i<9 else 0:>2}  {SECTIONS[i]}", highlight)
        tabs = EVIDENCE_TABS if section == "Evidence & Learning" else REPAIR_TABS if section == "Repair Planner" else ()
        x = navwidth + 2
        body = lines_for(section, tab, data)
        if tabs:
            put(3, x, "  ".join(f"[{i+1}:{t}]" if i == tab else t for i,t in enumerate(tabs))[:width-x-2], cyan)
        box(5, x, height-9, width-x-1, section.upper(), body)
    put(height-3, 1, "─"*(width-2), cyan)
    put(height-2, 1, "↑↓ Select  Enter Open  ←→ Tabs  Esc Back  1-9 Quick  R Refresh  H Help  Q Quit", muted)
    if note:
        put(height-4, 3, note, cyan | curses.A_BOLD)
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
