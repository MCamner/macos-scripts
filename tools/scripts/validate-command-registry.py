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

# A deprecated alias still dispatches — that is the point of deprecating rather
# than deleting — so it must say what to use instead. Without `replacement` the
# registry records that a word is on its way out and leaves the person who typed
# it with nowhere to go.
DEPRECATED_ALIAS_FIELDS = {
    "name": str,
    "replacement": str,
}

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
    # Whether the command is a public operator entrypoint. `mqlaunch help` shows
    # the true ones and stays silent about the rest, so this is the field that
    # decides what the product advertises about itself.
    "operator_surface": bool,
}

# Branch patterns in the dispatcher's top-level case that are not commands.
NON_COMMAND_PATTERNS = {"*", '""|menu'}

# A script this repo owns, invoked from a dispatch branch.
BRANCH_SCRIPT = re.compile(
    r"\$BASE_DIR/((?:tools/scripts|mqlaunch/commands|terminal/[a-z]+)/[A-Za-z0-9_./-]+)"
)

# `sudo` in command position, rather than `sudo` inside a message.
#
# The distinction is the whole check. tools/scripts/scan.sh contains the line
# `echo "- Restart audio if glitching: sudo killall coreaudiod"` — a suggestion
# printed for the operator, not an escalation — and `scan` is correctly
# read-only. A plain substring search would have relabelled it. Command position
# means the start of a line or right after a separator, which is where an
# executed `sudo` appears and where a quoted one does not.
EXEC_SUDO = re.compile(r"(?:^|[;&|(]|\b(?:then|do|else)\s)\s*sudo\s")

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


def script_execs_sudo(rel: str) -> bool:
    """True when a repo script actually escalates, rather than mentioning sudo."""
    path = ROOT / rel
    if not path.is_file():
        return False
    for line in path.read_text(errors="replace").splitlines():
        code = line.split("#", 1)[0]
        if EXEC_SUDO.search(code):
            return True
    return False


# `mqlaunch help` prints one row per public command as
# `  mqlaunch <name padded to 14>  <summary>`, a 26-character prefix, and
# ui/terminal-ui/terminal-width.sh clamps the surface to 92 columns. 92 - 26 is
# what a summary may occupy before the row wraps, which is where this number
# comes from rather than from taste.
SUMMARY_LIMIT = 66


def check_summaries(commands) -> None:
    """Keep every summary to one printable line.

    Help takes its descriptions from this field now — there is no second copy to
    trim — so a summary that does not fit is a wrapped row on the help screen
    rather than a lint opinion. The rule covers unadvertised commands too: the
    field has one register, and a command promoted to the surface later should
    not need rewriting to be printable.

    An empty summary is already reported by the required-field pass, so this
    only adds the two shape rules that pass does not cover.
    """
    for command in commands:
        summary = command["summary"]
        name = command["name"]
        if "\n" in summary:
            err(f"{name}: summary spans more than one line")
        if len(summary) > SUMMARY_LIMIT:
            err(f"{name}: summary is {len(summary)} characters, over the "
                f"{SUMMARY_LIMIT} a help row has room for")


def check_operator_surface(commands) -> None:
    """Hold the advertised surface to the rule that defines it.

    `mqlaunch help` is curated, and the curation now lives here rather than in
    whoever last edited the help text. Two things follow from that and are
    checked, because both are ways the field could quietly stop meaning
    anything:

    A compatibility-only command is never a public entrypoint. It exists so an
    old spelling keeps working, and advertising it would invite new callers to
    depend on the thing being retired.

    A public command must say which group it belongs to. Help is grouped by
    namespace, so a public command without one has nowhere to be printed, and
    the omission would show up as a missing row rather than as an error.
    """
    for command in commands:
        name = command["name"]
        public = command["operator_surface"]
        if public and command["compat_only"]:
            err(f"{name}: compat_only commands are not public entrypoints")
        if public and command["namespace"] is None:
            err(f"{name}: operator_surface is true but namespace is null — "
                f"help has no group to print it under")


def check_namespace_owner(commands) -> None:
    """A namespace must not mix owner repos.

    `mqlaunch help` prints the owner on the group heading rather than on each
    row — a row is already 26 columns of prefix plus a 66-character summary,
    which is the whole 92-column width, so a per-row owner would have to come
    out of the description. That works only while a namespace has one owner.

    Every namespace has one today. Without this rule the first command added
    under someone else's namespace would not fail anything: help would keep
    printing the old heading, and the label would silently start describing
    some of the rows beneath it instead of all of them. A wrong owner is worse
    than no owner, because an operator has no reason to doubt it.
    """
    owners: dict[str, dict[str, list[str]]] = {}
    for command in commands:
        namespace = command["namespace"]
        if namespace is None:
            continue
        owners.setdefault(namespace, {}).setdefault(
            command.get("owner"), []).append(command["name"])

    for namespace, by_owner in sorted(owners.items()):
        if len(by_owner) > 1:
            detail = "; ".join(
                f"{owner}: {' '.join(sorted(names))}"
                for owner, names in sorted(by_owner.items(), key=lambda kv: str(kv[0]))
            )
            err(f"namespace '{namespace}' mixes owners, so help cannot label "
                f"the group — {detail}")


def check_privilege_safety(
    commands: list[dict],
    seen_names: dict[str, str],
    branches: list[tuple[int, str]],
) -> None:
    """A command whose script escalates privilege must not claim to be read-only.

    `safety` exists so a consumer can decide what is safe to run, and `read-only`
    is the value that invites running something unattended. `ghost` carried it
    while tools/scripts/network-ghost.sh ran `sudo ifconfig ... ether ...` to
    spoof the machine's MAC address and flushed the DNS cache with sudo — a false
    label with a security consequence rather than a cosmetic one.

    The check is deliberately one-directional. It says read-only is wrong when the
    script escalates; it does not try to decide between local-write and
    destructive, which is a judgement about blast radius that a regex has no
    standing to make.
    """
    safety_of = {entry.get("name"): entry.get("safety") for entry in commands}

    lines = DISPATCH.read_text().splitlines()
    ordered = sorted(branches)
    for index, (line_no, pattern) in enumerate(ordered):
        if pattern in NON_COMMAND_PATTERNS:
            continue
        end = ordered[index + 1][0] - 1 if index + 1 < len(ordered) else len(lines)
        body = "\n".join(lines[line_no - 1 : end])

        first = pattern.split("|")[0].strip('"')
        command = seen_names.get(first)
        if command is None or safety_of.get(command) != "read-only":
            continue

        for rel in sorted(set(BRANCH_SCRIPT.findall(body))):
            if script_execs_sudo(rel):
                err(
                    f"{command}: safety is 'read-only' but {rel} runs sudo — "
                    f"use 'local-write' or 'destructive' so a consumer is not "
                    f"told it is safe to run unattended"
                )


def check_deprecated_aliases(name: str, entry: dict) -> list[dict]:
    """Validate an entry's `deprecated_aliases` and return the well-formed ones.

    The field is optional and modelled per alias, not per command: retiring an
    old spelling says nothing about the command it points at. A flag on the
    command would say the opposite, and there is no way to write `tools-menu is
    going away but tools is not` with one.

    Malformed entries are dropped from the returned list so the caller does not
    have to re-check them. They have already been reported.
    """
    raw = entry.get("deprecated_aliases", [])
    if not isinstance(raw, list):
        err(f"{name}: field 'deprecated_aliases' must be an array")
        return []

    valid = []
    for dep in raw:
        if not isinstance(dep, dict):
            err(f"{name}: each deprecated alias must be an object, got {type(dep).__name__}")
            continue

        label = dep.get("name")
        label = f"deprecated alias {label!r}" if isinstance(label, str) else "a deprecated alias"

        broken = False
        for field, expected in DEPRECATED_ALIAS_FIELDS.items():
            if field not in dep:
                err(f"{name}: {label}: missing required field {field!r}")
                broken = True
            elif not isinstance(dep[field], expected):
                err(f"{name}: {label}: field {field!r} has wrong type")
                broken = True
            elif not dep[field].strip():
                err(f"{name}: {label}: field {field!r} is empty")
                broken = True
        if broken:
            continue

        if dep["replacement"] == dep["name"]:
            err(f"{name}: {label}: replacement is the deprecated word itself")
            continue

        valid.append(dep)

    return valid


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
    # Every word that dispatches is in seen_names. These two split it by whether
    # a consumer may advertise the word: `active_words` is the surface help and
    # the palette publish, `deprecated_words` is what still works but must not be
    # offered. Replacements are resolved against the active set once every entry
    # has been read, so a deprecation may point forward to a command declared
    # later in the file.
    active_words: set[str] = set()
    deprecated_words: dict[str, str] = {}
    replacements: list[tuple[str, str, str]] = []

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

        # And it must go to the repo that owns it. `delegates_to` is the whole
        # delegated command — "mq-agent review", not "mq-agent" — so this checks
        # the first word. Without it, a command could declare mq-agent as owner
        # while routing to mq-mcp, which is the boundary violation
        # docs/RUNTIME_AUTHORITY.md forbids and the one an entry can state
        # plainly enough for a gate to see.
        if owner != "macos-scripts" and delegates:
            target = str(delegates).split()[0]
            if target != owner:
                err(
                    f"{name}: owned by {owner!r} but delegates_to names "
                    f"{target!r} — a command must delegate to the repo that "
                    f"owns it"
                )

        deprecated = check_deprecated_aliases(name, entry)

        for candidate in [name, *entry.get("aliases", [])]:
            active_words.add(candidate)
            if candidate in seen_names:
                err(
                    f"duplicate command name {candidate!r}: "
                    f"claimed by both {seen_names[candidate]!r} and {name!r}"
                )
            else:
                seen_names[candidate] = name

        for dep in deprecated:
            word = dep["name"]
            # Checked against this entry's own aliases before the global map, so
            # the contradiction gets named for what it is. The duplicate-name
            # error below would fire too, but it describes a collision between
            # two commands, which is a different mistake.
            if word in entry.get("aliases", []):
                err(
                    f"{name}: {word!r} is listed as both an active alias and a "
                    f"deprecated one — a consumer cannot tell whether to "
                    f"advertise it"
                )
            if word in seen_names:
                err(
                    f"duplicate command name {word!r}: "
                    f"claimed by both {seen_names[word]!r} and {name!r}"
                )
            else:
                seen_names[word] = name
            deprecated_words[word] = name
            replacements.append((name, word, dep["replacement"]))

    # Resolved after the loop so a deprecation can point at a command declared
    # further down the file. The replacement must be a word a consumer is
    # allowed to advertise: pointing at another deprecated alias would hand the
    # user a second word that is also on its way out.
    for owner_name, word, replacement in replacements:
        if replacement in deprecated_words:
            err(
                f"{owner_name}: deprecated alias {word!r}: replacement "
                f"{replacement!r} is itself deprecated"
            )
        elif replacement not in active_words:
            err(
                f"{owner_name}: deprecated alias {word!r}: replacement "
                f"{replacement!r} is not an active command name or alias"
            )

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
    check_privilege_safety(commands, seen_names, branches)
    check_operator_surface(commands)
    check_namespace_owner(commands)
    check_summaries(commands)

    if errors:
        print(f"FAIL: {len(errors)} registry problem(s)", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    subcommand_count = sum(len(c.get("subcommands", [])) for c in commands)
    deprecated_note = (
        f", {len(deprecated_words)} deprecated" if deprecated_words else ""
    )
    print(
        f"OK: {len(commands)} commands, {len(seen_names)} names"
        f"{deprecated_note}, {subcommand_count} subcommands in "
        f"{len(subcases)} namespaces, registry and dispatch agree"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
