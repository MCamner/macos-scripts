#!/usr/bin/env python3
"""Validate the mqlaunch command registry against itself and against dispatch.

The registry (mqlaunch/lib/command-registry.json) is the canonical inventory of
mqlaunch's command surface: top-level commands, and the subcommands mqlaunch
itself routes. This validator is the gate that keeps it canonical: it rejects
internally inconsistent registries, and it fails when the registry and the
dispatcher disagree about which commands or subcommands exist.

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
# What the namespace does with a word it does not recognise. `system` prints an
# error and exits 2, so its declared list is the whole surface. `repos` hands the
# word to mq-repos.py, so the list is only what mqlaunch itself routes — the
# distinction a consumer needs before publishing the list as complete.
UNKNOWN_SUBCOMMAND = {"reject", "forward"}

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


def parse_dispatch() -> tuple[list[tuple[int, str]], dict[str, dict]]:
    """Return the dispatcher's top-level branches and its subcommand cases.

    The dispatcher opens several case statements; the authoritative one switches
    on "$area". The walk tracks case/esac depth rather than matching on
    indentation, which is not consistent in the source.

    The second return value maps each top-level branch pattern that opens a
    nested `case "$sub" in` to that namespace's subcommand set. Only "$sub" is
    a subcommand switch: `release-check` switches on "${1:-}" to separate two
    output modes, and flags are not subcommands.
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
    parents: dict[int, tuple[int | None, str | None]] = {}
    open_branch: dict[int, str] = {}
    next_id = 0

    for i in range(start, len(lines)):
        line = lines[i]
        if line.startswith("}"):
            break
        if re.match(r"^\s*case\s+", line):
            enclosing = stack[-1] if stack else None
            parents[next_id] = (enclosing, open_branch.get(enclosing))
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
            open_branch[stack[-1]] = m.group(1)

    main = [gid for gid, h in headers.items() if h == 'case "$area" in']
    if len(main) != 1:
        fail(f'expected exactly one `case "$area" in` in dispatch, found {len(main)}')
    main_id = main[0]

    subcases: dict[str, dict] = {}
    for gid, header in headers.items():
        enclosing, branch = parents.get(gid, (None, None))
        if enclosing != main_id or header != 'case "$sub" in' or branch is None:
            continue
        tokens: dict[str, int] = {}
        fallback_line = None
        for line_no, pattern in groups[gid]:
            if pattern == "*":
                fallback_line = line_no
                continue
            for token in pattern.split("|"):
                token = token.strip('"')
                if token:
                    tokens.setdefault(token, line_no)
        subcases[branch] = {
            "tokens": tokens,
            "line": min([ln for ln, _ in groups[gid]], default=0),
            # An unrecognised word is rejected only when the fallback says so.
            # If it forwards instead — or there is no fallback and the code falls
            # through to a delegate — the listed set is not the whole surface,
            # and a consumer must not present it as exhaustive.
            "unknown": "reject"
            if fallback_line is not None and _branch_rejects(lines, fallback_line)
            else "forward",
        }

    return groups[main_id], subcases


def _branch_rejects(lines: list[str], branch_line: int) -> bool:
    """True when the case branch starting at branch_line exits non-zero."""
    for line in lines[branch_line:]:
        if re.match(r"^\s*;;\s*$", line):
            return False
        if re.search(r"\breturn\s+2\b", line):
            return True
    return False


errors: list[str] = []


def check_output_modes(label: str, entry: dict) -> None:
    """Hold `json` and `output_modes` to each other.

    Agreement between the two fields is the most a static check can prove — they
    are wrong together as easily as they are right together, which is how #78
    happened. tests/output-mode-parity-smoke.sh runs the command and compares
    the declaration to what actually comes out.
    """
    modes = entry.get("output_modes", [])
    for mode in modes:
        if mode not in OUTPUT_MODES:
            err(f"{label}: unknown output mode {mode!r}")

    if entry.get("json") and "json" not in modes:
        err(f"{label}: json is true but 'json' is not in output_modes")
    if not entry.get("json") and "json" in modes:
        err(f"{label}: 'json' in output_modes but json is false")


def check_subcommand_output(label: str, sub: dict) -> None:
    """Validate a subcommand's optional output-mode declaration.

    P1 kept subcommand entries at name/aliases/summary because a field no gate
    can check is a field that drifts. Output mode earns its place now that
    tests/output-mode-parity-smoke.sh executes the command: `system` is
    human-only while `mqlaunch system doctor --json` emits a real machine
    document, and a consumer reading only the parent would hide that.

    Both fields are optional and must arrive together. Declaring `json` without
    `output_modes` — or the reverse — is a half-stated contract, and a consumer
    would have to guess which half to trust. Omitting both means the subcommand
    claims nothing, and the parity gate holds it to producing nothing.
    """
    has_json = "json" in sub
    has_modes = "output_modes" in sub

    if has_json != has_modes:
        present, absent = ("json", "output_modes") if has_json else ("output_modes", "json")
        err(f"{label}: declares {present!r} without {absent!r}")
        return
    if not has_json:
        return

    if not isinstance(sub["json"], bool):
        err(f"{label}: field 'json' has wrong type")
        return
    if not isinstance(sub["output_modes"], list):
        err(f"{label}: field 'output_modes' has wrong type")
        return

    check_output_modes(label, sub)


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def err(msg: str) -> None:
    errors.append(msg)


def check_subcommands(
    commands: list[dict],
    seen_names: dict[str, str],
    subcases: dict[str, dict],
) -> None:
    """Hold the registry's subcommand sets in parity with the dispatcher.

    The gate runs both ways. A namespace that dispatches subcommands must
    declare them, and a declared subcommand must be dispatched — drift by
    omission is as wrong as drift by invention, and only the first is silent.
    """
    # Which registry command owns each nested case, resolved through the same
    # name/alias map the top-level parity check builds.
    owner_of: dict[str, str] = {}
    for branch, info in subcases.items():
        first = branch.split("|")[0].strip('"')
        command = seen_names.get(first)
        if command is None:
            err(f"dispatch nests subcommands under unknown branch {branch!r}")
            continue
        owner_of[command] = branch

    for entry in commands:
        name = entry.get("name", "<unnamed>")
        subs = entry.get("subcommands")
        unknown = entry.get("unknown_subcommand")

        if subs is None:
            if unknown is not None:
                err(f"{name}: unknown_subcommand without a subcommands array")
            if name in owner_of:
                err(
                    f"{name}: dispatch handles subcommands "
                    f"(line {subcases[owner_of[name]]['line']}) "
                    f"but the registry declares none"
                )
            continue

        if not isinstance(subs, list):
            err(f"{name}: subcommands must be an array")
            continue
        if unknown not in UNKNOWN_SUBCOMMAND:
            err(
                f"{name}: unknown_subcommand must be one of "
                f"{sorted(UNKNOWN_SUBCOMMAND)}"
            )

        if name not in owner_of:
            err(f"{name}: declares subcommands but dispatch has no case for them")
            continue

        info = subcases[owner_of[name]]

        registry_words: dict[str, str] = {}
        for sub in subs:
            if not isinstance(sub, dict):
                err(f"{name}: subcommand entries must be objects")
                continue
            sub_name = sub.get("name")
            if not isinstance(sub_name, str) or not sub_name:
                err(f"{name}: subcommand is missing a name")
                continue
            if not isinstance(sub.get("aliases"), list):
                err(f"{name}.{sub_name}: aliases must be an array")
            if not str(sub.get("summary", "")).strip():
                err(f"{name}.{sub_name}: summary is empty")
            check_subcommand_output(f"{name} {sub_name}", sub)
            for word in [sub_name, *sub.get("aliases", [])]:
                if word in registry_words:
                    err(
                        f"{name}: duplicate subcommand word {word!r}: claimed by "
                        f"both {registry_words[word]!r} and {sub_name!r}"
                    )
                else:
                    registry_words[word] = sub_name

        for word in sorted(set(info["tokens"]) - set(registry_words)):
            err(
                f"{name}: dispatch handles subcommand {word!r} "
                f"(line {info['tokens'][word]}) but the registry does not list it"
            )
        for word in sorted(set(registry_words) - set(info["tokens"])):
            err(f"{name}: registry lists subcommand {word!r} but dispatch does not")

        # A forwarding namespace accepts words the registry cannot enumerate.
        # Saying so is the only honest way to publish a partial list.
        if unknown in UNKNOWN_SUBCOMMAND and unknown != info["unknown"]:
            err(
                f"{name}: unknown_subcommand is {unknown!r} but dispatch is "
                f"{info['unknown']!r}"
            )


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

        # A command claiming JSON must actually offer it as an output mode.
        # Otherwise the registry advertises a contract nothing honours.
        check_output_modes(name, entry)

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
    branches, subcases = parse_dispatch()
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

    check_subcommands(commands, seen_names, subcases)

    if errors:
        print(f"FAIL: {len(errors)} registry problem(s)", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    subcommand_count = sum(len(c.get("subcommands", [])) for c in commands)
    print(
        f"OK: {len(commands)} commands, {len(seen_names)} names, "
        f"{subcommand_count} subcommands in {len(subcases)} namespaces, "
        f"registry and dispatch agree"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
