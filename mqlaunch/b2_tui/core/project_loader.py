from __future__ import annotations

import re
import sys
from pathlib import Path

from mqlaunch.b2_tui.config import PROJECT_INDEX, PROMPTS_DIR
from mqlaunch.b2_tui.models import Prompt

# Matches "## 01 Core Thinking" style section headers
_SECTION_RE = re.compile(r"^## (\d{2} .+)$")
# Matches table rows: | 01.07 | Meta Reasoning Solver | ★ ... |
# Also handles bolded IDs: | **01.07** | **Meta Reasoning Solver** | ★ ... |
_ROW_RE = re.compile(r"^\|\s*\*{0,2}(\d{2}\.\d{2})\*{0,2}\s*\|\s*\*{0,2}([^|*]+?)\*{0,2}\s*\|\s*([^|]*?)\s*\|")


def _category_to_dir(category: str) -> str:
    """'02 Architecture' → '02_Architecture'"""
    return category.strip().replace(" ", "_")


def _find_prompt_file(prompt_id: str, category_dir: str) -> Path | None:
    cat_path = PROMPTS_DIR / category_dir
    if not cat_path.is_dir():
        return None
    for f in cat_path.iterdir():
        if f.name.startswith(prompt_id + "_") or f.name.startswith(prompt_id + "."):
            return f
    return None


def load_prompts() -> list[Prompt]:
    if not PROJECT_INDEX.exists():
        print(f"  WARN  PROJECT_INDEX.md not found: {PROJECT_INDEX}", file=sys.stderr)
        return []

    prompts: list[Prompt] = []
    current_category = ""
    current_dir = ""

    for line in PROJECT_INDEX.read_text().splitlines():
        section_match = _SECTION_RE.match(line)
        if section_match:
            current_category = section_match.group(1)
            current_dir = _category_to_dir(current_category)
            continue

        if not current_category:
            continue

        row_match = _ROW_RE.match(line)
        if not row_match:
            continue

        pid = row_match.group(1).strip()
        name = row_match.group(2).strip()
        mq_stack = row_match.group(3).strip()

        path = _find_prompt_file(pid, current_dir)
        if path is None:
            # Prompt listed in index but file missing — include with empty path for validator
            path = PROMPTS_DIR / current_dir / f"{pid}_missing.md"

        prompts.append(Prompt(
            id=pid,
            name=name,
            category=current_category,
            path=path,
            mq_stack=mq_stack,
        ))

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
