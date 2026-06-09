from __future__ import annotations

import json
from unittest.mock import patch

from mqlaunch.b2_tui.core.history import save_history


def test_save_history_writes_jsonl(tmp_path):
    history_file = tmp_path / "history.jsonl"
    entry = {"timestamp": "2026-06-09T20:00:00+00:00", "prompt_id": "02.11"}
    with patch("mqlaunch.b2_tui.core.history.HISTORY_FILE", history_file):
        save_history(entry)
    lines = history_file.read_text().splitlines()
    assert len(lines) == 1
    assert json.loads(lines[0])["prompt_id"] == "02.11"


def test_save_history_appends(tmp_path):
    history_file = tmp_path / "history.jsonl"
    with patch("mqlaunch.b2_tui.core.history.HISTORY_FILE", history_file):
        save_history({"prompt_id": "02.11"})
        save_history({"prompt_id": "05.03"})
    lines = history_file.read_text().splitlines()
    assert len(lines) == 2
