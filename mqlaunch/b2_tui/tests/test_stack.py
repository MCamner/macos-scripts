from __future__ import annotations

import argparse
from pathlib import Path
from unittest.mock import patch

import mqlaunch.b2_tui.main as m
from mqlaunch.b2_tui.main import cmd_stack
from mqlaunch.b2_tui.models import Prompt


def _args() -> argparse.Namespace:
    return argparse.Namespace()


def _fake_prompt(id: str, name: str, exists: bool = True, tmp_path: Path | None = None) -> Prompt:
    if tmp_path and exists:
        p = tmp_path / f"{id}.md"
        p.write_text(f"# {name}\n" * 10)
        path = p
    else:
        path = Path("/dev/null") if exists else Path("/nonexistent/missing.md")
    return Prompt(id=id, name=name, category="arch", path=path, mq_stack=None)


def _repo_data():
    return {
        "repo": {"name": "macos-scripts"},
        "git": {"branch": "main", "clean": True, "change_count": 0},
        "public_readiness": {"available": True, "score": 16, "total": 16, "status": "ok"},
        "issues": [],
    }


def test_stack_shows_repo_name(tmp_path, capsys):
    prompts = [_fake_prompt("02.11", "Blueprint")]
    roadmap = tmp_path / "ROADMAP.md"
    roadmap.write_text("## v0.6.0 — done\n\n* [x] item\n")
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        with patch("mqlaunch.b2_tui.main.call_inspect", return_value=_repo_data()):
            with patch("mqlaunch.b2_tui.main.last_run_path", return_value=None):
                rc = cmd_stack(prompts, _args())
    finally:
        m._REPO_ROOT = orig
    out = capsys.readouterr().out
    assert rc == 0
    assert "macos-scripts" in out


def test_stack_shows_prompt_count(tmp_path, capsys):
    prompts = [
        _fake_prompt("02.11", "Blueprint"),
        _fake_prompt("02.03", "Impl"),
        _fake_prompt("04.02", "Research"),
    ]
    roadmap = tmp_path / "ROADMAP.md"
    roadmap.write_text("")
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        with patch("mqlaunch.b2_tui.main.call_inspect", return_value=_repo_data()):
            with patch("mqlaunch.b2_tui.main.last_run_path", return_value=None):
                rc = cmd_stack(prompts, _args())
    finally:
        m._REPO_ROOT = orig
    out = capsys.readouterr().out
    assert "3 total" in out


def test_stack_shows_roadmap_drift(tmp_path, capsys):
    prompts = [_fake_prompt("02.11", "Blueprint")]
    roadmap = tmp_path / "ROADMAP.md"
    roadmap.write_text("## v1.0.0 — stack\n\n* [x] done item\n* [ ] open item\n")
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        with patch("mqlaunch.b2_tui.main.call_inspect", return_value=_repo_data()):
            with patch("mqlaunch.b2_tui.main.last_run_path", return_value=None):
                rc = cmd_stack(prompts, _args())
    finally:
        m._REPO_ROOT = orig
    out = capsys.readouterr().out
    assert "v1.0.0" in out
    assert "open" in out


def test_stack_shows_last_run(tmp_path, capsys):
    prompts = [_fake_prompt("02.11", "Blueprint")]
    roadmap = tmp_path / "ROADMAP.md"
    roadmap.write_text("")
    fake_run = tmp_path / "2026-06-10-b2-test.md"
    fake_run.write_text("# run\n")
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        with patch("mqlaunch.b2_tui.main.call_inspect", return_value=_repo_data()):
            with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_run):
                rc = cmd_stack(prompts, _args())
    finally:
        m._REPO_ROOT = orig
    out = capsys.readouterr().out
    assert "2026-06-10-b2-test.md" in out


def test_stack_shows_validation_errors(tmp_path, capsys):
    prompts = [
        _fake_prompt("02.11", "Blueprint", exists=True, tmp_path=tmp_path),
        _fake_prompt("02.03", "Missing", exists=False),
    ]
    roadmap = tmp_path / "ROADMAP.md"
    roadmap.write_text("")
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        with patch("mqlaunch.b2_tui.main.call_inspect", return_value=_repo_data()):
            with patch("mqlaunch.b2_tui.main.last_run_path", return_value=None):
                rc = cmd_stack(prompts, _args())
    finally:
        m._REPO_ROOT = orig
    out = capsys.readouterr().out
    assert "1 errors" in out


def test_stack_repo_signal_unavailable(tmp_path, capsys):
    prompts = [_fake_prompt("02.11", "Blueprint")]
    roadmap = tmp_path / "ROADMAP.md"
    roadmap.write_text("")
    orig = m._REPO_ROOT
    m._REPO_ROOT = tmp_path
    try:
        with patch("mqlaunch.b2_tui.main.call_inspect", return_value={"_error": "not found"}):
            with patch("mqlaunch.b2_tui.main.last_run_path", return_value=None):
                rc = cmd_stack(prompts, _args())
    finally:
        m._REPO_ROOT = orig
    assert rc == 0
    assert "unavailable" in capsys.readouterr().out
