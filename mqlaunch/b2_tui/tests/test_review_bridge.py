from __future__ import annotations

import argparse
from pathlib import Path
from unittest.mock import MagicMock, patch

from mqlaunch.b2_tui.main import cmd_review_last


def _args(**kwargs) -> argparse.Namespace:
    defaults = {"architecture": False, "security": False}
    defaults.update(kwargs)
    return argparse.Namespace(**defaults)


def test_review_last_no_runs(tmp_path, capsys):
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=None):
        rc = cmd_review_last([], _args())
    assert rc == 1
    assert "compose" in capsys.readouterr().err


def test_review_last_mq_agent_not_found(tmp_path, capsys):
    fake_path = tmp_path / "2026-06-09-b2-test.md"
    fake_path.write_text("# B2 Prompt Run\n")
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value=None):
            rc = cmd_review_last([], _args())
    assert rc == 1
    assert "mq-agent" in capsys.readouterr().err


def _ok_result(returncode: int = 0) -> MagicMock:
    r = MagicMock()
    r.returncode = returncode
    r.stdout = '{"findings": []}'
    r.stderr = ""
    return r


def test_review_last_calls_mq_agent(tmp_path):
    fake_path = tmp_path / "2026-06-09-b2-test.md"
    fake_path.write_text("# B2 Prompt Run\n")
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value="/usr/local/bin/mq-agent"):
            with patch("subprocess.run", return_value=_ok_result()) as mock_run:
                rc = cmd_review_last([], _args())
    assert rc == 0
    called_cmd = mock_run.call_args[0][0]
    assert called_cmd[0] == "mq-agent"
    assert called_cmd[1] == "review"
    assert called_cmd[2] == "file"
    assert called_cmd[3] == str(fake_path)


def test_review_last_passes_architecture_flag(tmp_path):
    fake_path = tmp_path / "2026-06-09-b2-test.md"
    fake_path.write_text("# B2 Prompt Run\n")
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value="/usr/local/bin/mq-agent"):
            with patch("subprocess.run", return_value=_ok_result()) as mock_run:
                rc = cmd_review_last([], _args(architecture=True))
    assert rc == 0
    assert "--architecture" in mock_run.call_args[0][0]


def test_review_last_passes_security_flag(tmp_path):
    fake_path = tmp_path / "2026-06-09-b2-test.md"
    fake_path.write_text("# B2 Prompt Run\n")
    with patch("mqlaunch.b2_tui.main.last_run_path", return_value=fake_path):
        with patch("shutil.which", return_value="/usr/local/bin/mq-agent"):
            with patch("subprocess.run", return_value=_ok_result()) as mock_run:
                rc = cmd_review_last([], _args(security=True))
    assert rc == 0
    assert "--security" in mock_run.call_args[0][0]
