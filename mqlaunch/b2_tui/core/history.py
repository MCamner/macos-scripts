from __future__ import annotations

import argparse
import json

from mqlaunch.b2_tui.config import HISTORY_FILE


def save_history(entry: dict) -> None:
    with HISTORY_FILE.open("a") as fh:
        fh.write(json.dumps(entry) + "\n")


def cmd_history(_prompts: object, args: argparse.Namespace) -> int:
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
