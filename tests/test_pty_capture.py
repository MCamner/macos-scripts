"""Verify the PTY helper on Python versions without os.login_tty."""
import unittest
from unittest.mock import patch

from lib.pty_capture import run_pty


class PtyCaptureTests(unittest.TestCase):
    def test_controlling_terminal_without_login_tty(self):
        with patch("os.login_tty", None, create=True):
            status, output = run_pty(
                "test -t 0 && test -t 1 && test -t 2 && "
                "printf terminal-ready > /dev/tty"
            )
        self.assertEqual(status, 0)
        self.assertIn(b"terminal-ready", output)


if __name__ == "__main__":
    unittest.main()
