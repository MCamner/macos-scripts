#!/usr/bin/env python3
"""Assert the local release gate and CI check the same things.

`release-check.sh` is the gate a human runs before cutting a release;
`.github/workflows/quality.yml` is the gate a PR runs. Nothing kept the two in
step, and they had drifted badly: the Python tests and markdownlint ran in CI
only, and the local gate's shell syntax check covered five files where CI's
covered 261. A green local gate was silent about those, not clean.

Every CI step must be declared here, mapped to the local gate check it
corresponds to or to the reason it cannot have one. A step added to the
workflow without a declaration fails this check, so a gate cannot arrive
unnoticed. Local checks work the same way in reverse.

Unlike mq-agent's equivalent, this compares declared steps rather than parsed
commands. quality.yml's steps are multi-line shell, where command parsing
produces noise rather than check identities; the checks themselves are script
invocations whose scope lives inside the shared script, so scope drift between
the two gates is caught by the script being shared, not by comparing arguments.

Read-only. Run standalone or from release-check.sh.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
GATE = ROOT / "release-check.sh"
WORKFLOWS = ROOT / ".github" / "workflows"

SETUP = "__setup__"


class CiOnly(str):
    """A reason a step has no local counterpart, not a gate label.

    Explicit rather than inferred. Guessing from the text -- "does it contain a
    space?" -- silently classified the label `pytest b2_tui` as a reason, so
    deleting that check from release-check.sh passed parity.
    """


# Which workflows carry repo-local checks the local gate should mirror.
# A workflow mapped to False is out of scope, and the reason says why.
WORKFLOW_SCOPE: dict[str, object] = {
    "quality.yml": True,
}

# Every named step in an in-scope workflow, mapped to:
#   - the release-check.sh label it corresponds to,
#   - SETUP, if it prepares the environment rather than checking anything, or
#   - a string reason, if it is deliberately CI-only.
STEPS: dict[str, object] = {
    "Install zsh": SETUP,
    "Install ShellCheck (pinned)": SETUP,
    "Install test dependencies": SETUP,
    "Skills are consistent (frontmatter, cross-refs, paths, SKILLS.md)": "skills consistent",
    "Runtime authority freeze (no new live -> mqlaunch-v1 edges)": "runtime authority freeze",
    "Shell syntax (all .sh, routed by shebang)": "check-shell-syntax.sh",
    "mqlaunch smoke suite": "test-all.sh",
    "markdownlint all .md (no auto-fix)": "markdownlint",
    "Run B2 TUI tests": "pytest b2_tui",
    "Local gate and CI check the same things": "check-gate-parity.py",
    "ShellCheck (warning severity, enforced)": CiOnly(
        "CI-only: tools/scripts/lint.sh runs locally inside test-all.sh, but it "
        "exits 0 when shellcheck is absent so a developer without the binary can "
        "still run the suite. Only CI installs a pinned shellcheck and asserts "
        "its presence, so only CI can fail on lint findings."
    ),
}

# Local checks with no CI counterpart, and why.
LOCAL_ONLY: dict[str, str] = {}


def workflow_steps() -> dict[str, list[str]]:
    """Named steps of every in-scope workflow, keyed by step name."""
    found: dict[str, list[str]] = {}
    undeclared = sorted(
        p.name for p in WORKFLOWS.glob("*.yml") if p.name not in WORKFLOW_SCOPE
    )
    if undeclared:
        for name in undeclared:
            print(f"FAIL: {name} is not listed in WORKFLOW_SCOPE in {Path(__file__).name}")
        raise SystemExit(1)

    for name, in_scope in WORKFLOW_SCOPE.items():
        if not in_scope:
            continue
        path = WORKFLOWS / name
        if not path.exists():
            print(f"FAIL: WORKFLOW_SCOPE lists {name}, which does not exist")
            raise SystemExit(1)
        data = yaml.safe_load(path.read_text()) or {}
        for job_id, job in (data.get("jobs") or {}).items():
            for step in job.get("steps") or []:
                if step.get("uses") and not step.get("name"):
                    continue  # actions/checkout, setup-node, ... : not checks
                step_name = step.get("name")
                if not step_name:
                    print(f"FAIL: {name}:{job_id} has an unnamed run step; name it so it can be declared")
                    raise SystemExit(1)
                found.setdefault(step_name, []).append(f"{name}:{job_id}")
    return found


def gate_labels() -> set[str]:
    """Labels of every check release-check.sh runs through run()."""
    pattern = re.compile(r'^\s*run\s+"([^"]+)"')
    return {
        m.group(1)
        for m in (pattern.match(line) for line in GATE.read_text().splitlines())
        if m
    }


def main() -> int:
    steps = workflow_steps()
    labels = gate_labels()
    failed = False

    for name in sorted(set(steps) - set(STEPS)):
        where = ", ".join(steps[name])
        print(f"FAIL: workflow step '{name}' ({where}) is not declared in STEPS")
        failed = True

    for name in sorted(set(STEPS) - set(steps)):
        print(f"FAIL: STEPS declares '{name}', which no in-scope workflow runs")
        failed = True

    mapped: set[str] = set()
    for name, target in sorted(STEPS.items()):
        if target == SETUP or name not in steps:
            continue
        if isinstance(target, CiOnly):
            print(f"SKIP: '{name}' is CI-only -- {target}")
            continue
        if target in labels:
            mapped.add(target)
            continue
        print(f"FAIL: workflow step '{name}' maps to release-check.sh label '{target}', which it does not run")
        failed = True

    for label in sorted(labels - mapped):
        if label in LOCAL_ONLY:
            print(f"SKIP: '{label}' is local-only -- {LOCAL_ONLY[label]}")
            continue
        print(f"FAIL: release-check.sh runs '{label}' and no in-scope workflow step declares it")
        failed = True

    if failed:
        print("check-gate-parity: FAILED")
        return 1
    print(f"PASS: local gate and CI agree on {len(mapped)} checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
