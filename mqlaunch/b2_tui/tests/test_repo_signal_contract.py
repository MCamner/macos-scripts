from __future__ import annotations

import argparse
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

from mqlaunch.b2_tui.core.repo_signal_contract import (
    call_inspect,
    git_summary,
    has_issues,
    issues,
    readiness_summary,
    render_repo_status,
    repo_name,
)
from mqlaunch.b2_tui.main import cmd_repo_status, cmd_roadmap_drift


# ── call_inspect ───────────────────────────────────────────────────────────

def test_call_inspect_no_binary(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda _: None)
    data = call_inspect()
    assert "_error" in data


def test_call_inspect_parses_json():
    payload = {"repo": {"name": "test"}, "git": {"branch": "main", "clean": True}, "issues": []}
    mock_result = MagicMock()
    mock_result.stdout = json.dumps(payload)
    with patch("subprocess.run", return_value=mock_result):
        with patch("shutil.which", return_value="/usr/bin/repo-signal"):
            data = call_inspect()
    assert data["repo"]["name"] == "test"


def test_call_inspect_invalid_json_returns_error():
    mock_result = MagicMock()
    mock_result.stdout = "not json"
    mock_result.stderr = "oops"
    with patch("subprocess.run", return_value=mock_result):
        with patch("shutil.which", return_value="/usr/bin/repo-signal"):
            data = call_inspect()
    assert "_error" in data


# ── repo helpers ───────────────────────────────────────────────────────────

def _sample_data(branch="main", clean=True, score=16, total=16, issue_list=None):
    return {
        "repo": {"name": "macos-scripts"},
        "git": {"branch": branch, "clean": clean, "change_count": 0},
        "public_readiness": {"available": True, "score": score, "total": total, "status": "ok"},
        "issues": issue_list or [],
    }


def test_repo_name():
    assert repo_name(_sample_data()) == "macos-scripts"


def test_git_summary_clean():
    assert "clean" in git_summary(_sample_data())
    assert "main" in git_summary(_sample_data())


def test_git_summary_dirty():
    data = _sample_data(clean=False)
    data["git"]["change_count"] = 3
    summary = git_summary(data)
    assert "dirty" in summary
    assert "3" in summary


def test_readiness_summary():
    assert "16/16" in readiness_summary(_sample_data())


def test_has_issues_false():
    assert has_issues(_sample_data()) is False


def test_has_issues_true():
    data = _sample_data(issue_list=[{"level": "warn", "message": "Missing examples"}])
    assert has_issues(data) is True


def test_render_repo_status_includes_name():
    out = render_repo_status(_sample_data())
    assert "macos-scripts" in out


def test_render_repo_status_shows_issues():
    data = _sample_data(issue_list=[{"level": "warn", "message": "Missing examples folder"}])
    out = render_repo_status(data)
    assert "WARN" in out
    assert "Missing examples folder" in out


def test_render_repo_status_error():
    out = render_repo_status({"_error": "not found"})
    assert "Error" in out


# ── cmd_repo_status ────────────────────────────────────────────────────────

def test_cmd_repo_status_ok(capsys):
    payload = _sample_data()
    with patch("mqlaunch.b2_tui.core.repo_signal_contract.call_inspect", return_value=payload):
        rc = cmd_repo_status([], argparse.Namespace(path=".", export=False))
    assert rc == 0
    assert "macos-scripts" in capsys.readouterr().out


def test_cmd_repo_status_error_returns_1(capsys):
    with patch("mqlaunch.b2_tui.core.repo_signal_contract.call_inspect", return_value={"_error": "nope"}):
        rc = cmd_repo_status([], argparse.Namespace(path=".", export=False))
    assert rc == 1


# ── cmd_roadmap_drift ──────────────────────────────────────────────────────

def test_roadmap_drift_reads_file(tmp_path, capsys):
    roadmap = tmp_path / "ROADMAP.md"
    version = tmp_path / "VERSION"
    roadmap.write_text("## v0.6.0 — done\n\n* [x] item one\n* [x] item two\n\n## v0.7.0 — partial\n\n* [x] done\n* [ ] open\n")
    version.write_text("0.6.0\n")
    import mqlaunch.b2_tui.main as m
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        rc = cmd_roadmap_drift([], argparse.Namespace())
    finally:
        m._REPO_ROOT = orig
    out = capsys.readouterr().out
    assert rc == 0
    assert "v0.6.0" in out
    assert "v0.7.0" in out
    assert "1" in out  # 1 open item


def test_roadmap_drift_missing_file(tmp_path, capsys):
    import mqlaunch.b2_tui.main as m
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        rc = cmd_roadmap_drift([], argparse.Namespace())
    finally:
        m._REPO_ROOT = orig
    assert rc == 1
