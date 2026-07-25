#!/usr/bin/env python3
"""Validate the mqlaunch command registry against itself and against dispatch.

The registry (mqlaunch/lib/command-registry.json) is the canonical inventory of
top-level mqlaunch commands. This validator is the gate that keeps it canonical:
it rejects internally inconsistent registries, and it fails when the registry and
the dispatcher disagree about which commands exist.

Run standalone or through tests/command-registry-smoke.sh.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "mqlaunch" / "lib" / "command-registry.json"
DISPATCH = ROOT / "terminal" / "launchers" / "mqlaunch-command-mode.sh"

SCHEMA = "mq-command-registry.v1"

# Repos allowed as an owner. A command delegating anywhere else is a boundary
# violation the runtime authority document forbids.
OWNERS = {"macos-scripts", "mq-agent", "mq-mcp", "mqobsidian", "mq-hal", "repo-signal"}
SAFETY = {"read-only", "local-write", "delegating", "destructive"}
OUTPUT_MODES = {"human", "json", "interactive"}

REQUIRED_FIELDS = {
    "name": str,
    "aliases": list,
    "namespace": (str, type(None)),
    "summary": str,
    "owner": str,
    "safety": str,
    "output_modes": list,
    "json": bool,
    "interactive": bool,
    "compat_only": bool,
    "delegates_to": (str, type(None)),
}

# Branch patterns in the dispatcher's top-level case that are not commands.
NON_COMMAND_PATTERNS = {"*", '""|menu'}

BRANCH = re.compile(
    r'^\s*((?:"[^"]*"|[A-Za-z0-9_*/.\-])+(?:\|(?:"[^"]*"|[A-Za-z0-9_*/.\-])+)*)\)'
    r"(\s*$|\s+\S.*;;\s*$)"
)


def dispatch_branches() -> list[tuple[int, str]]:
    """Return (line, pattern) for each branch of the dispatcher's main case.

    The dispatcher opens several case statements; the authoritative one switches
    on "$area". Nested cases handle subcommands and are out of scope for the
    top-level registry, so the walk tracks case/esac depth rather than matching
    on indentation, which is not consistent in the source.
    """
    lines = DISPATCH.read_text().splitlines()
    try:
        start = next(
            i for i, l in enumerate(lines) if l.startswith("dispatch_cli_command()")
        )
    except StopIteration:
        fail("dispatch_cli_command() not found — the authority path moved")

    stack: list[int] = []
    groups: dict[int, list[tuple[int, str]]] = {}
    headers: dict[int, str] = {}
    next_id = 0

    for i in range(start, len(lines)):
        line = lines[i]
        if line.startswith("}"):
            break
        if re.match(r"^\s*case\s+", line):
            stack.append(next_id)
            groups[next_id] = []
            headers[next_id] = line.strip()
            next_id += 1
            continue
        if re.match(r"^\s*esac\b", line):
            if stack:
                stack.pop()
            continue
        if not stack:
            continue
        m = BRANCH.match(line)
        if m:
            groups[stack[-1]].append((i + 1, m.group(1)))

    main = [gid for gid, h in headers.items() if h == 'case "$area" in']
    if len(main) != 1:
        fail(f'expected exactly one `case "$area" in` in dispatch, found {len(main)}')
    return groups[main[0]]


errors: list[str] = []


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def err(msg: str) -> None:
    errors.append(msg)


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    # An explicit path lets the smoke test point the validator at a deliberately
    # broken registry and assert that the gate actually fires.
    registry = Path(argv[0]) if argv else REGISTRY

    if not registry.exists():
        fail(f"registry not found: {registry}")

    try:
        data = json.loads(registry.read_text())
    except json.JSONDecodeError as exc:
        fail(f"registry is not valid JSON: {exc}")

    errors.clear()

    if data.get("schema") != SCHEMA:
        err(f"schema must be {SCHEMA!r}, got {data.get('schema')!r}")

    commands = data.get("commands")
    if not isinstance(commands, list) or not commands:
        fail("registry has no commands array")

    seen_names: dict[str, str] = {}

    for entry in commands:
        name = entry.get("name", "<unnamed>")

        for field, expected in REQUIRED_FIELDS.items():
            if field not in entry:
                err(f"{name}: missing required field {field!r}")
            elif not isinstance(entry[field], expected):
                err(f"{name}: field {field!r} has wrong type")

        if not entry.get("summary", "").strip():
            err(f"{name}: summary is empty")

        owner = entry.get("owner")
        if owner not in OWNERS:
            err(f"{name}: unknown owner {owner!r}")

        safety = entry.get("safety")
        if safety not in SAFETY:
            err(f"{name}: unknown safety mode {safety!r}")

        modes = entry.get("output_modes", [])
        for mode in modes:
            if mode not in OUTPUT_MODES:
                err(f"{name}: unknown output mode {mode!r}")

        # A command claiming JSON must actually offer it as an output mode.
        # Otherwise the registry advertises a contract nothing honours.
        if entry.get("json") and "json" not in modes:
            err(f"{name}: json is true but 'json' is not in output_modes")
        if not entry.get("json") and "json" in modes:
            err(f"{name}: 'json' in output_modes but json is false")

        # Delegation must name where it goes, and only non-local owners delegate.
        delegates = entry.get("delegates_to")
        if owner != "macos-scripts" and not delegates:
            err(f"{name}: owned by {owner} but delegates_to is empty")
        if safety == "delegating" and not delegates:
            err(f"{name}: safety is 'delegating' but delegates_to is empty")

        for candidate in [name, *entry.get("aliases", [])]:
            if candidate in seen_names:
                err(
                    f"duplicate command name {candidate!r}: "
                    f"claimed by both {seen_names[candidate]!r} and {name!r}"
                )
            else:
                seen_names[candidate] = name

    # --- parity with the dispatcher -------------------------------------------
    branches = dispatch_branches()
    dispatch_names: dict[str, int] = {}
    for line, pattern in branches:
        if pattern in NON_COMMAND_PATTERNS:
            continue
        for token in pattern.split("|"):
            token = token.strip('"')
            if not token or token == "*":
                continue
            if token in dispatch_names:
                err(
                    f"dispatch defines {token!r} twice (lines "
                    f"{dispatch_names[token]} and {line}) — the later branch is "
                    f"unreachable"
                )
            else:
                dispatch_names[token] = line

    missing = sorted(set(dispatch_names) - set(seen_names))
    extra = sorted(set(seen_names) - set(dispatch_names))

    for token in missing:
        err(f"dispatch handles {token!r} (line {dispatch_names[token]}) but the registry does not list it")
    for token in extra:
        err(f"registry lists {token!r} but dispatch does not handle it")

    if errors:
        print(f"FAIL: {len(errors)} registry problem(s)", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(
        f"OK: {len(commands)} commands, {len(seen_names)} names, "
        f"registry and dispatch agree"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
