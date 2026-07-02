from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest

from mqlaunch.b2_tui.config import PROJECT_INDEX
from mqlaunch.b2_tui.core.project_loader import (
    _category_to_dir,
    find_prompt,
    load_prompts,
)
from mqlaunch.b2_tui.models import Prompt

_MINIMAL_INDEX = """\
## 02 Architecture

| ID | Name | mq-stack use |
|---|---|---|
| **02.11** | **Integration Architecture Blueprint** | ★ Main stack blueprint |
| 02.03 | Low-Level Implementation Design | |
"""


def test_category_to_dir():
    assert _category_to_dir("02 Architecture") == "02_Architecture"


def test_category_to_dir_multiword():
    assert _category_to_dir("01 Core Thinking") == "01_Core_Thinking"


def test_find_prompt_by_exact_id():
    p = Prompt(id="02.11", name="Blueprint", category="02 Architecture", path=Path("/fake"))
    assert find_prompt([p], "02.11") is p


def test_find_prompt_by_name_substring():
    p = Prompt(id="02.11", name="Integration Blueprint", category="02 Architecture", path=Path("/fake"))
    assert find_prompt([p], "blueprint") is p


def test_find_prompt_not_found():
    p = Prompt(id="02.11", name="Blueprint", category="02 Architecture", path=Path("/fake"))
    assert find_prompt([p], "99.99") is None


def test_load_prompts_missing_index_returns_empty(tmp_path):
    with patch("mqlaunch.b2_tui.core.project_loader.PROJECT_INDEX", tmp_path / "nonexistent.md"):
        assert load_prompts() == []


def test_load_prompts_parses_index(tmp_path):
    index = tmp_path / "PROJECT_INDEX.md"
    index.write_text(_MINIMAL_INDEX)

    # Create fake prompt file
    cat_dir = tmp_path / "prompts" / "02_Architecture"
    cat_dir.mkdir(parents=True)
    (cat_dir / "02.11_Integration_Architecture_Blueprint.md").write_text("prompt content")

    with (
        patch("mqlaunch.b2_tui.core.project_loader.PROJECT_INDEX", index),
        patch("mqlaunch.b2_tui.core.project_loader.PROMPTS_DIR", tmp_path / "prompts"),
    ):
        prompts = load_prompts()

    assert len(prompts) == 2
    p = next(p for p in prompts if p.id == "02.11")
    assert p.name == "Integration Architecture Blueprint"
    assert p.category == "02 Architecture"
    assert p.mq_stack == "★ Main stack blueprint"


def test_load_prompts_real_index():
    if not PROJECT_INDEX.exists():
        pytest.skip(f"local B2 PROJECT_INDEX.md not found: {PROJECT_INDEX}")

    prompts = load_prompts()
    assert len(prompts) == 43
    ids = {p.id for p in prompts}
    assert "02.11" in ids
    categories = {p.category for p in prompts}
    assert len(categories) == 8
