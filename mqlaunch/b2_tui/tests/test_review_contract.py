from __future__ import annotations

import argparse
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

from mqlaunch.b2_tui.core.review_contract import (
    has_blocking,
    parse_review_json,
    render_findings,
    render_summary,
    severity_counts,
    severity_of,
)
from mqlaunch.b2_tui.main import cmd_review_last


# ── parse_review_json ──────────────────────────────────────────────────────

def test_parse_findings_list():
    data = json.dumps([{"severity": "HIGH", "message": "x"}, {"severity": "LOW", "message": "y"}])
    findings = parse_review_json(data)
    assert len(findings) == 2
    assert findings[0]["severity"] == "HIGH"


def test_parse_findings_wrapped():
    data = json.dumps({"findings": [{"severity": "BLOCKER", "message": "critical issue"}]})
    findings = parse_review_json(data)
    assert len(findings) == 1
    assert findings[0]["severity"] == "BLOCKER"


def test_parse_findings_nested_result():
    data = json.dumps({"result": {"findings": [{"severity": "MEDIUM", "message": "ok"}]}})
    findings = parse_review_json(data)
    assert len(findings) == 1


def test_parse_invalid_json_returns_empty():
    assert parse_review_json("not json at all") == []


def test_parse_empty_string_returns_empty():
    assert parse_review_json("") == []


# ── severity_of ────────────────────────────────────────────────────────────

def test_severity_of_uses_severity_key():
    assert severity_of({"severity": "HIGH"}) == "HIGH"


def test_severity_of_falls_back_to_label():
    assert severity_of({"label": "medium"}) == "MEDIUM"


def test_severity_of_unknown_returns_unspecified():
    assert severity_of({"message": "no severity key"}) == "UNSPECIFIED"


# ── has_blocking ───────────────────────────────────────────────────────────

def test_has_blocking_true_for_blocker():
    assert has_blocking([{"severity": "BLOCKER"}, {"severity": "LOW"}]) is True


def test_has_blocking_true_for_critical():
    assert has_blocking([{"severity": "CRITICAL"}]) is True


def test_has_blocking_false_for_high():
    assert has_blocking([{"severity": "HIGH"}, {"severity": "MEDIUM"}]) is False


def test_has_blocking_empty_list():
    assert has_blocking([]) is False


# ── render_summary ─────────────────────────────────────────────────────────

def test_render_summary_ordered():
    findings = [
        {"severity": "LOW", "message": "a"},
        {"severity": "HIGH", "message": "b"},
        {"severity": "MEDIUM", "message": "c"},
    ]
    summary = render_summary(findings)
    assert "HIGH 1" in summary
    assert "MEDIUM 1" in summary
    assert "LOW 1" in summary
    assert summary.index("HIGH") < summary.index("MEDIUM") < summary.index("LOW")


def test_render_summary_no_findings():
    assert "No findings" in render_summary([])


# ── cmd_review_last with JSON capture ─────────────────────────────────────

def _args(**kwargs) -> argparse.Namespace:
    defaults = {"architecture": False, "security": False, "risk": False}
    defaults.update(kwargs)
    return argparse.Namespace(**defaults)


def test_review_last_json_capture_passes_json_flag(tmp_path):
    fake_path = tmp_path / "2026-06-10-b2-test.md"
    fake_path.write_text("# B2 Run\n")
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = json.dumps({"findings": []})
    mock_result.stderr = ""
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value="/usr/local/bin/mq-agent"):
            with patch("subprocess.run", return_value=mock_result) as mock_run:
                rc = cmd_review_last([], _args())
    assert rc == 0
    cmd = mock_run.call_args[0][0]
    assert "--json" in cmd


def test_review_last_blocker_returns_1(tmp_path):
    fake_path = tmp_path / "2026-06-10-b2-test.md"
    fake_path.write_text("# B2 Run\n")
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = json.dumps({"findings": [{"severity": "BLOCKER", "message": "critical"}]})
    mock_result.stderr = ""
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value="/usr/local/bin/mq-agent"):
            with patch("subprocess.run", return_value=mock_result):
                rc = cmd_review_last([], _args())
    assert rc == 1


def test_review_last_risk_flag_passed(tmp_path):
    fake_path = tmp_path / "2026-06-10-b2-test.md"
    fake_path.write_text("# B2 Run\n")
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = json.dumps({"findings": []})
    mock_result.stderr = ""
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value="/usr/local/bin/mq-agent"):
            with patch("subprocess.run", return_value=mock_result) as mock_run:
                cmd_review_last([], _args(risk=True))
    cmd = mock_run.call_args[0][0]
    assert "--risk" in cmd
