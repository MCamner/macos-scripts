from __future__ import annotations

import argparse
from pathlib import Path
from unittest.mock import patch

from mqlaunch.b2_tui.core.validator import cmd_validate
from mqlaunch.b2_tui.models import Prompt


def test_validate_returns_1_when_prompts_dir_missing(tmp_path):
    with patch("mqlaunch.b2_tui.core.validator.PROMPTS_DIR", tmp_path / "nonexistent"):
        rc = cmd_validate([], argparse.Namespace())
    assert rc == 1


def test_validate_ok_for_valid_prompts(tmp_path):
    f = tmp_path / "02.11_Blueprint.md"
    f.write_text("x" * 100)
    p = Prompt(id="02.11", name="Blueprint", category="Architecture", path=f)
    with patch("mqlaunch.b2_tui.core.validator.PROMPTS_DIR", tmp_path):
        rc = cmd_validate([p], argparse.Namespace())
    assert rc == 0


def test_validate_returns_1_for_missing_file(tmp_path):
    p = Prompt(id="02.11", name="Blueprint", category="Architecture", path=tmp_path / "missing.md")
    with patch("mqlaunch.b2_tui.core.validator.PROMPTS_DIR", tmp_path):
        rc = cmd_validate([p], argparse.Namespace())
    assert rc == 1
