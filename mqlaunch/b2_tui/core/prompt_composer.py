from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime, timezone

from mqlaunch.b2_tui.adapters.obsidian_writer import write_run
from mqlaunch.b2_tui.core.history import save_history
from mqlaunch.b2_tui.core.project_loader import find_prompt
from mqlaunch.b2_tui.models import Prompt


def _copy_to_clipboard(text: str) -> bool:
    try:
        subprocess.run(["pbcopy"], input=text.encode(), check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def cmd_run(prompts: list[Prompt], args: argparse.Namespace) -> int:
    target = find_prompt(prompts, args.id)
    if target is None:
        print(f"Prompt '{args.id}' not found. Run 'mq b2 list' to see all.", file=sys.stderr)
        return 1

    content = target.path.read_text()

    print(f"\n  {target.id} — {target.name}")
    print(f"  {'─' * 50}")
    for line in content.splitlines()[:12]:
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

    if not user_context:
        print("  Error: task/context cannot be empty.", file=sys.stderr)
        return 1

    composed = f"{content}\n\n---\n\nContext:\n{user_context}"

    copied = _copy_to_clipboard(composed)
    print(f"\n  {'Copied to clipboard.' if copied else 'pbcopy not available — printing prompt:'}")
    if not copied:
        print(composed)

    out_path = write_run(target, user_context, composed)
    print(f"  Saved: {out_path}")

    save_history({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "prompt_id": target.id,
        "prompt_name": target.name,
        "category": target.category,
        "context": user_context,
        "output_file": str(out_path),
    })

    return 0
