from __future__ import annotations

import argparse
from pathlib import Path
from unittest.mock import MagicMock, call, patch

from mqlaunch.b2_tui.main import cmd_route_pipeline
from mqlaunch.b2_tui.models import Prompt


def _args(**kwargs) -> argparse.Namespace:
    defaults = {
        "task": "design blueprint for new API",
        "compose": True,
        "review": False,
        "architecture": False,
        "security": False,
    }
    defaults.update(kwargs)
    return argparse.Namespace(**defaults)


def _fake_prompt(id: str, name: str) -> Prompt:
    return Prompt(id=id, name=name, category="arch", path=Path("/dev/null"), mq_stack=None)


def test_pipeline_routes_and_composes(capsys):
    fake_prompt = _fake_prompt("02.11", "Blueprint Composer")
    with patch("mqlaunch.b2_tui.main.find_prompt", return_value=fake_prompt):
        with patch("mqlaunch.b2_tui.core.router.route", return_value=("architecture", [], ["design", "blueprint"])):
            with patch("mqlaunch.b2_tui.main.cmd_compose", return_value=0) as mock_compose:
                rc = cmd_route_pipeline([fake_prompt], _args())
    assert rc == 0
    mock_compose.assert_called_once()
    compose_args = mock_compose.call_args[0][1]
    assert compose_args.id == "02.11"
    assert compose_args.task == "design blueprint for new API"


def test_pipeline_passes_review_flag(capsys):
    fake_prompt = _fake_prompt("02.11", "Blueprint Composer")
    with patch("mqlaunch.b2_tui.main.find_prompt", return_value=fake_prompt):
        with patch("mqlaunch.b2_tui.core.router.route", return_value=("architecture", [], [])):
            with patch("mqlaunch.b2_tui.main.cmd_compose", return_value=0) as mock_compose:
                rc = cmd_route_pipeline([fake_prompt], _args(review=True))
    assert rc == 0
    compose_args = mock_compose.call_args[0][1]
    assert compose_args.review is True


def test_pipeline_passes_architecture_flag():
    fake_prompt = _fake_prompt("02.11", "Blueprint Composer")
    with patch("mqlaunch.b2_tui.main.find_prompt", return_value=fake_prompt):
        with patch("mqlaunch.b2_tui.core.router.route", return_value=("architecture", [], [])):
            with patch("mqlaunch.b2_tui.main.cmd_compose", return_value=0) as mock_compose:
                rc = cmd_route_pipeline([fake_prompt], _args(architecture=True))
    assert rc == 0
    compose_args = mock_compose.call_args[0][1]
    assert compose_args.architecture is True


def test_pipeline_passes_security_flag():
    fake_prompt = _fake_prompt("02.11", "Blueprint Composer")
    with patch("mqlaunch.b2_tui.main.find_prompt", return_value=fake_prompt):
        with patch("mqlaunch.b2_tui.core.router.route", return_value=("architecture", [], [])):
            with patch("mqlaunch.b2_tui.main.cmd_compose", return_value=0) as mock_compose:
                rc = cmd_route_pipeline([fake_prompt], _args(security=True))
    assert rc == 0
    compose_args = mock_compose.call_args[0][1]
    assert compose_args.security is True


def test_pipeline_propagates_compose_error():
    fake_prompt = _fake_prompt("02.11", "Blueprint Composer")
    with patch("mqlaunch.b2_tui.main.find_prompt", return_value=fake_prompt):
        with patch("mqlaunch.b2_tui.core.router.route", return_value=("architecture", [], [])):
            with patch("mqlaunch.b2_tui.main.cmd_compose", return_value=1):
                rc = cmd_route_pipeline([fake_prompt], _args())
    assert rc == 1
