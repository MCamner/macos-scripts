from __future__ import annotations

import argparse
import json
import sys

from mqlaunch.b2_tui.config import HISTORY_FILE


def save_history(entry: dict) -> None:
    with HISTORY_FILE.open("a") as fh:
        fh.write(json.dumps(entry) + "\n")


def _read_entries(limit: int | None = None) -> list[dict]:
    if not HISTORY_FILE.exists():
        return []
    entries = []
    for line in HISTORY_FILE.read_text().splitlines():
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return entries[-limit:] if limit else entries


def _print_entry(entry: dict) -> None:
    ts = entry.get("timestamp", "")[:16].replace("T", " ")
    cmd = entry.get("command", "compose")
    pid = entry.get("prompt_id", "?")
    name = entry.get("prompt_name", "")
    ctx = (entry.get("context", "") or "")[:40]
    out = entry.get("output_file", "")
    print(f"  {ts}  [{cmd}]  {pid:<8} {name}")
    if ctx:
        print(f"           └─ {ctx}")
    if out:
        print(f"           └─ {out}")


def cmd_history(_prompts: object, args: argparse.Namespace) -> int:
    subcommand = getattr(args, "subcommand", None)
    limit = getattr(args, "limit", 10)

    if subcommand == "last":
        entries = _read_entries(1)
        if not entries:
            print("  No history yet.")
            return 0
        _print_entry(entries[0])
        return 0

    if subcommand == "export":
        return _export_markdown()

    entries = _read_entries(limit)
    if not entries:
        print("  No history yet.")
        return 0
    for entry in entries:
        _print_entry(entry)
    return 0


def _export_markdown() -> int:
    from mqlaunch.b2_tui.config import RUNS_DIR
    entries = _read_entries()
    if not entries:
        print("  No history to export.")
        return 0
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    out = RUNS_DIR / "b2-history.md"
    lines = ["# B2 TUI History\n"]
    for e in reversed(entries):
        ts = e.get("timestamp", "")[:16].replace("T", " ")
        cmd = e.get("command", "compose")
        pid = e.get("prompt_id", "?")
        name = e.get("prompt_name", "")
        ctx = e.get("context", "") or ""
        lines.append(f"## {ts} — {pid} {name}\n")
        lines.append(f"- command: `{cmd}`\n")
        if ctx:
            lines.append(f"- task: {ctx}\n")
        lines.append("")
    out.write_text("\n".join(lines))
    print(f"  Exported: {out}")
    return 0
