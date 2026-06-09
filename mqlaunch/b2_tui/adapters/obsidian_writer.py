from __future__ import annotations

import re
import sys
from datetime import datetime
from pathlib import Path

from mqlaunch.b2_tui.config import RUNS_DIR
from mqlaunch.b2_tui.models import Prompt


def _slug(text: str) -> str:
    return re.sub(r"[^\w]+", "-", text[:40]).strip("-").lower()


def write_run(prompt: Prompt, task: str, composed: str) -> Path:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    filename = f"{ts}-b2-{_slug(task)}.md"
    path = RUNS_DIR / filename
    content = f"""# B2 Prompt Run

## Project

{prompt.id} {prompt.name}

## User input

{task}

## Composed prompt

{composed}

## Task

{task}
"""
    path.write_text(content)
    return path


def open_file(path: Path) -> None:
    import subprocess
    subprocess.run(["open", str(path)], check=False)


def last_run_path() -> Path | None:
    if not RUNS_DIR.exists():
        return None
    runs = sorted(RUNS_DIR.glob("*-b2-*.md"))
    return runs[-1] if runs else None
