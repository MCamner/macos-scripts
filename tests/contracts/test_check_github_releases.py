"""scripts/check-github-releases.sh: the release-publication gate.

A stub `gh` answers `release view` from a fixed list and records every call, so
the verdicts and the network reached can both be asserted without GitHub.
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "scripts" / "check-github-releases.sh"
GATE = ROOT / "release-check.sh"

STUB = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$GH_CALLS"
if [[ "${1:-}" == "auth" ]]; then
  [[ "${GH_AUTHED:-1}" == "1" ]] && exit 0 || exit 1
fi
if [[ "${1:-}" == "release" && "${2:-}" == "view" ]]; then
  for v in ${PUBLISHED:-}; do
    [[ "$v" == "${3:-}" ]] && exit 0
  done
  exit 1
fi
exit 0
"""

CHANGELOG = """# Changelog

## [Unreleased]

## [2.5.0] - 2026-09-10

## [v2.4.0] — 2026-09-09

## [2.3.0] - 2026-08-23
"""


class CheckGithubReleasesTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.work = Path(self._tmp.name)
        (self.work / "bin").mkdir()
        gh = self.work / "bin" / "gh"
        gh.write_text(STUB)
        gh.chmod(0o755)
        self.changelog = self.work / "CHANGELOG.md"
        self.changelog.write_text(CHANGELOG)
        self.calls = self.work / "calls.log"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_tool(self, published: str, version: str, authed: bool = True) -> subprocess.CompletedProcess:
        self.calls.write_text("")
        env = {
            **os.environ,
            "PATH": f"{self.work / 'bin'}{os.pathsep}{os.environ['PATH']}",
            "GH_CALLS": str(self.calls),
            "PUBLISHED": published,
            "GH_AUTHED": "1" if authed else "0",
        }
        return subprocess.run(
            ["bash", str(TOOL), "--version", version, "--changelog", str(self.changelog)],
            env=env, capture_output=True, text=True, timeout=30, check=False,
        )

    def test_unpublished_version_with_published_predecessor_passes(self) -> None:
        result = self.run_tool("v2.4.0", "2.5.0")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("OK: v2.5.0 is not yet published", result.stdout)
        # The predecessor heading is `[v2.4.0]`; the leading v must not hide it.
        self.assertIn("OK: predecessor v2.4.0 is published", result.stdout)
        self.assertNotIn("Unreleased", result.stdout)

    def test_already_published_version_fails(self) -> None:
        result = self.run_tool("v2.5.0 v2.4.0", "2.5.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL: v2.5.0 is already published", result.stdout)

    def test_unpublished_predecessor_fails(self) -> None:
        result = self.run_tool("v2.3.0", "2.5.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL: predecessor v2.4.0", result.stdout)

    def test_edges_skip(self) -> None:
        self.assertIn("SKIP: v2.3.0 is the oldest declared version", self.run_tool("", "2.3.0").stdout)
        self.assertIn("SKIP: 9.9.9 is not declared", self.run_tool("", "9.9.9").stdout)
        result = self.run_tool("", "2.5.0", authed=False)
        self.assertEqual(result.returncode, 0)
        self.assertIn("SKIP: gh is not authenticated", result.stdout)
        self.assertNotIn("release view", self.calls.read_text())

    def test_predecessor_comes_from_changelog_not_tags(self) -> None:
        self.assertIsNone(re.search(r"git (tag|for-each-ref|describe|rev-list)", TOOL.read_text()))

    def test_gate_call_is_behind_dry_run_json_and_ci(self) -> None:
        # Structural: running release-check.sh from its own test suite would
        # recurse. The one call must sit in the branch none of the three take.
        lines = GATE.read_text().splitlines()
        calls = [i for i, line in enumerate(lines)
                 if "check-github-releases.sh" in line and not line.strip().startswith("#")]
        self.assertEqual(len(calls), 1, calls)
        guard = max(i for i in range(calls[0]) if lines[i].lstrip().startswith("if "))
        self.assertIn('"$DRY_RUN" -eq 1', lines[guard])
        self.assertIn('"$JSON" -eq 1', lines[guard])
        self.assertIn('"${CI:-}"', lines[guard])
        self.assertTrue(any(line.strip() == "else" for line in lines[guard:calls[0]]))


if __name__ == "__main__":
    unittest.main()
