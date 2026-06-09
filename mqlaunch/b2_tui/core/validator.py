from __future__ import annotations

import argparse
import sys

from mqlaunch.b2_tui.config import PROMPTS_DIR, REGISTRY_JSON, RUNS_DIR
from mqlaunch.b2_tui.core.project_loader import find_prompt
from mqlaunch.b2_tui.core.router import ROUTE_PRIMARY
from mqlaunch.b2_tui.models import Prompt


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

    for route, pid in ROUTE_PRIMARY.items():
        if find_prompt(prompts, pid) is None:
            print(f"  WARN  route '{route}' primary prompt {pid} not found")

    if not REGISTRY_JSON.exists():
        print(f"  WARN  registry/projects.json not found (optional): {REGISTRY_JSON}")

    if not RUNS_DIR.exists():
        print(f"  WARN  Obsidian runs dir not found (created on first compose): {RUNS_DIR}")

    return 1 if errors else 0
