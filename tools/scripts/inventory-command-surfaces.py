#!/usr/bin/env python3
"""Inventory of how mqlaunch commands are discovered.

The registry already has gates for the surfaces that are machine-readable:
docs/COMMANDS.md, the README, `--help` output and the palette are all compared
against mqlaunch/lib/command-registry.json, and the registry itself is compared
against the dispatcher. The interactive menus were the one discovery surface
with no such comparison, and they are where an operator actually looks.

This tool answers, for every dispatch arm in terminal/menus/*.sh — numbered and
letter-key alike, since the menus use both:

    via-dispatcher     invokes `mqlaunch <command>` — the single authority
    outside-registry   invokes a word the registry does not declare
    navigation         opens another menu or launcher, not a command
    dispatcher-bypass  runs a script directly that the dispatcher also routes,
                       so the same capability has two entry points
    menu-only-tool     runs a script the dispatcher does not route at all
    menu-local         local UI or shell logic with no command equivalent

and, for every registry command, whether any menu reaches it.

The classification is heuristic: it reads shell source with regexes and follows
a menu action one level into the function it names. It is deliberately not a
shell interpreter. What it guarantees is that every option lands in exactly one
class and nothing is silently uncounted — the property that made the test
manifest useful. Treat individual rows as a lead to verify, not a verdict.

Exit status is 0 for a clean inventory. --fail-on-unclassified is what the smoke
test uses; --max-bypass pins today's count so the number cannot quietly grow
while the duplicated paths are worked through.
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "mqlaunch" / "lib" / "command-registry.json"
DISPATCH = ROOT / "terminal" / "launchers" / "mqlaunch-command-mode.sh"
MENUS = ROOT / "terminal" / "menus"
LAUNCHERS = ROOT / "terminal" / "launchers"

SCHEMA = "mq-command-discovery-inventory.v1"

# A dispatch arm in a menu's case statement. Both key styles count: `  3) ... ;;`
# and `  r|R) ... ;;`. Restricting this to digits was wrong — the menus route most
# of their command invocations through letter keys, so a numeric-only scan saw 4
# dispatcher calls where there are dozens. Two leading spaces keeps it to indented
# case arms rather than any line that happens to start with a word.
ARM = re.compile(r"^\s{2,}([0-9]+|[A-Za-z](?:\|[A-Za-z])*)\)\s*(.+?)\s*;;\s*$")

# A shell function definition, in either accepted form.
FUNC_DEF = re.compile(r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")

# `mqlaunch <word>` or `bin/mqlaunch <word>`, however it is quoted.
INVOKE = re.compile(r"(?:bin/)?mqlaunch\"?\s+([a-z][a-z0-9-]*)")

# A script under one of the repo's executable trees, reached through a base
# variable: "$BASE_DIR/tools/scripts/doctor.sh".
SCRIPT = re.compile(
    r"\$(?:BASE_DIR|ROOT|MACOS_SCRIPTS_HOME)[^\s\"]*/"
    r"(?:tools/scripts|mqlaunch/commands|terminal/[a-z]+)/([A-Za-z0-9_.-]+)"
)

# Safety cap on how far to read for a function's closing brace. Reaching it means
# the body could not be delimited, and the excerpt stops rather than running on.
FUNC_BODY_LINES = 120

# A function's closing brace at column zero. Bodies are cut here instead of after
# a fixed line count, which was reading past the end of a short handler and into
# whichever function came next in the file. That is how `ping_test`,
# `show_dns_gateway` and `open_network_settings` — none of which touch pulse.sh —
# were all attributed to it: they are 9 to 15 lines long and share
# tools/scripts/mqlaunch_desktop.sh with a neighbour that runs it.
FUNC_END = re.compile(r"^\}")

# A handler that opens a submenu rather than running anything: open_system_menu,
# mq_obsidian_menu_main, document_functions_menu_loop.
#
# Matched on the name, before the body is read, and that ordering is the point. A
# submenu opener's body is that submenu's own case statement, so reading into it
# returned whatever the first 60 lines of the child menu happened to invoke — and
# the label changed when the child menu was edited. `2) open_system_menu` was
# reported as dispatcher-bypass because the system menu ran network-ghost.sh
# nearby, then flipped to via-dispatcher when an unrelated row in that menu was
# rerouted. Neither was true: the arm opens a menu.
MENU_OPENER = re.compile(r"^(?:open_.*_menu|.*_menu(?:_main|_loop)?)$")

KINDS = (
    "via-dispatcher",
    "outside-registry",
    "navigation",
    "dispatcher-bypass",
    "menu-only-tool",
    "menu-local",
)


# The help screen's command list is generated text, not menu code. Its rows read
# `  mqlaunch doctor  Check the environment`, which INVOKE matches exactly like a
# call, so the list made `mq-help-menu.sh` look like a menu that reaches half the
# registry — and every command it lists looked duplicated with the menu that
# really offers it. Printing a command's name is not a way in.
LIST_OPEN = re.compile(r"^\s*cat <<'LIST'\s*$")
LIST_CLOSE = re.compile(r"^LIST$")


def menu_code_lines(path):
    """Lines of a menu file with generated list blocks left out."""
    inside = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if inside:
            if LIST_CLOSE.match(line):
                inside = False
            continue
        if LIST_OPEN.match(line):
            inside = True
            continue
        yield line


def strip_comment(line: str) -> str:
    """Drop a trailing `#` comment.

    Necessary, not tidiness: the menus discuss themselves in prose — "mqlaunch
    owns …", "mqlaunch may …" — and an invocation regex reads those sentences as
    command calls. Naive, in that it does not know about `#` inside a string, but
    it errs toward dropping text rather than inventing an invocation.
    """
    return line.split("#", 1)[0]


def shell_sources() -> list[Path]:
    """Every tracked shell file that can define a menu handler, tests excluded.

    The list comes from git, not from walking the filesystem. Walking was wrong
    in a way that only CI could see: a local gitignored backups/scripts/ tree
    holds old copies of the menus and launchers, and because a handler name can
    be defined in several files, resolution sometimes landed in a backup. The
    inventory then reported 9 dispatcher-bypass options on a developer machine
    and 12 on a clean checkout. Tracked files are the same set everywhere.
    """
    listing = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "-z", "*.sh"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    out = []
    for rel in listing.split("\0"):
        if not rel or rel.startswith("tests/"):
            continue
        path = ROOT / rel
        if path.is_file():
            out.append(path)
    return sorted(out)


def index_function_bodies(paths: list[Path]) -> dict[Path, dict[str, str]]:
    """Function bodies per file, so a name can be resolved locally first.

    Resolution order matters and is not cosmetic: several handler names are
    defined in more than one file, so picking a winner globally makes the whole
    inventory depend on filesystem order. A menu's own definition is the one that
    menu runs, so callers resolve against that file before the shared tree.
    """
    per_file: dict[Path, dict[str, str]] = {}
    for path in paths:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        bodies: dict[str, str] = {}
        for index, line in enumerate(lines):
            match = FUNC_DEF.match(line)
            if match and match.group(1) not in bodies:
                end = index + 1
                limit = min(len(lines), index + FUNC_BODY_LINES)
                while end < limit and not FUNC_END.match(lines[end]):
                    end += 1
                bodies[match.group(1)] = "\n".join(lines[index : end + 1])
        per_file[path] = bodies
    return per_file


def resolve_body(name: str, menu: Path, per_file: dict[Path, dict[str, str]]) -> str | None:
    """The menu's own definition wins; otherwise the first one in the tree."""
    own = per_file.get(menu, {})
    if name in own:
        return own[name]
    for path, bodies in per_file.items():
        if path != menu and name in bodies:
            return bodies[name]
    return None


def registry_words() -> tuple[dict[str, str], list[str]]:
    """Map every command word, including aliases, to its canonical name."""
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    words: dict[str, str] = {}
    for entry in data["commands"]:
        words[entry["name"]] = entry["name"]
        for alias in entry.get("aliases") or []:
            words[alias] = entry["name"]
    return words, sorted({entry["name"] for entry in data["commands"]})


def classify(action: str, menu: Path, per_file: dict, context: dict) -> tuple[str, str | None]:
    """Return (kind, target) for one menu option's action."""
    text = action
    token = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\b", action)
    if token and MENU_OPENER.match(token.group(1)):
        return "navigation", token.group(1)
    if token:
        body = resolve_body(token.group(1), menu, per_file)
        if body:
            text = f"{action}\n{body}"

    code = "\n".join(strip_comment(line) for line in text.splitlines())

    invoked = INVOKE.search(code)
    if invoked:
        word = invoked.group(1)
        if word in context["words"]:
            return "via-dispatcher", context["words"][word]
        # Routed somewhere, but not a word the registry declares. `repl` is the
        # standing example: it reaches terminal/launchers/mqlaunch-repl.sh without
        # passing through dispatch_cli_command, which is what the registry scopes
        # itself to. Reported rather than dropped — a menu offers it, so an
        # operator can find it, and no registry or docs gate covers it.
        return "outside-registry", word

    script = SCRIPT.search(code)
    if not script:
        return "menu-local", None

    target = script.group(1)
    if target in context["menu_files"] or target in context["launcher_files"]:
        return "navigation", target
    if target in context["dispatch_text"]:
        return "dispatcher-bypass", target
    return "menu-only-tool", target


def build() -> dict:
    words, canonical = registry_words()
    sources = shell_sources()
    context = {
        "words": words,
        "dispatch_text": DISPATCH.read_text(encoding="utf-8", errors="replace"),
        "menu_files": {p.name for p in MENUS.glob("*.sh")},
        "launcher_files": {p.name for p in LAUNCHERS.glob("*.sh")},
    }
    per_file = index_function_bodies(sources)

    options = []
    reached: dict[str, set[str]] = collections.defaultdict(set)
    for menu in sorted(MENUS.glob("*.sh")):
        lines = menu.read_text(encoding="utf-8", errors="replace").splitlines()
        for number, line in enumerate(lines, 1):
            match = ARM.match(line)
            if not match:
                continue
            kind, target = classify(match.group(2), menu, per_file, context)
            options.append(
                {
                    "menu": menu.name,
                    "line": number,
                    "option": match.group(1),
                    "action": match.group(2),
                    "kind": kind,
                    "target": target,
                }
            )
            if kind == "via-dispatcher" and target:
                reached[target].add(menu.name)

    # A second, deliberately coarser measure. The option-level pass above follows
    # an arm one function deep, and most menu invocations sit further away than
    # that — an arm calls a renderer which calls a helper which calls mqlaunch.
    # Counting registry reach from the option pass therefore said "3 of 74", which
    # is an artifact of the window, not a fact about the menus. This scans whole
    # menu files with comments stripped: it cannot say which option reaches a
    # command, only that some menu code does.
    invoked_in_menu_code: dict[str, set[str]] = collections.defaultdict(set)
    for menu in sorted(MENUS.glob("*.sh")):
        for line in menu_code_lines(menu):
            for match in INVOKE.finditer(strip_comment(line)):
                word = match.group(1)
                if word in words:
                    invoked_in_menu_code[words[word]].add(menu.name)

    counts = collections.Counter(option["kind"] for option in options)
    duplicated = {
        command: sorted(menus)
        for command, menus in invoked_in_menu_code.items()
        if len(menus) > 1
    }
    return {
        "schema": SCHEMA,
        "options": options,
        "counts": {kind: counts.get(kind, 0) for kind in KINDS},
        "unclassified": [o for o in options if o["kind"] not in KINDS],
        "registry": {
            "total": len(canonical),
            "invoked_from_an_option": sorted(reached),
            "invoked_in_menu_code": sorted(invoked_in_menu_code),
            "absent_from_menu_code": [
                c for c in canonical if c not in invoked_in_menu_code
            ],
            "exposed_in_several_menus": duplicated,
        },
    }


def report(data: dict) -> None:
    counts = data["counts"]
    total = sum(counts.values())
    print(f"MENU OPTIONS ({total} across {len({o['menu'] for o in data['options']})} menus)")
    for kind in KINDS:
        print(f"  {kind:<18} {counts[kind]}")

    bypass = [o for o in data["options"] if o["kind"] == "dispatcher-bypass"]
    if bypass:
        print(f"\nDISPATCHER BYPASS ({len(bypass)})")
        print("  the dispatcher routes these scripts too, so there are two ways in")
        for option in bypass:
            print(f"  {option['menu']}:{option['line']} option {option['option']:>2} -> {option['target']}")

    only = [o for o in data["options"] if o["kind"] == "menu-only-tool"]
    if only:
        print(f"\nMENU-ONLY TOOLS ({len(only)})")
        print("  no dispatcher route: reachable from a menu and nowhere else")
        for option in only:
            print(f"  {option['menu']}:{option['line']} option {option['option']:>2} -> {option['target']}")

    reg = data["registry"]
    print(f"\nREGISTRY ({reg['total']} commands)")
    print(f"  invoked somewhere in menu code   {len(reg['invoked_in_menu_code'])}")
    print(f"  absent from menu code (cli-only) {len(reg['absent_from_menu_code'])}")
    print(f"  traceable to a specific option   {len(reg['invoked_from_an_option'])}")
    print("  the last figure is smaller by construction: an option is followed one")
    print("  function deep, and most menus reach a command further away than that.")
    if reg["absent_from_menu_code"]:
        print("\n  cli-only commands:")
        for command in reg["absent_from_menu_code"]:
            print(f"    {command}")
    if reg["exposed_in_several_menus"]:
        print("\n  exposed in several menus:")
        for command, menus in sorted(reg["exposed_in_several_menus"].items()):
            print(f"    {command}: {', '.join(menus)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="emit the inventory as JSON")
    parser.add_argument(
        "--fail-on-unclassified",
        action="store_true",
        help="exit non-zero if any menu option lands outside the known classes",
    )
    parser.add_argument(
        "--max-bypass",
        type=int,
        default=None,
        help="exit non-zero if dispatcher-bypass options exceed this count",
    )
    args = parser.parse_args(argv)

    data = build()
    if args.json:
        json.dump(data, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        report(data)

    status = 0
    if args.fail_on_unclassified and data["unclassified"]:
        print(
            f"FAIL: {len(data['unclassified'])} menu option(s) are unclassified",
            file=sys.stderr,
        )
        status = 1
    if args.max_bypass is not None:
        bypass = data["counts"]["dispatcher-bypass"]
        if bypass > args.max_bypass:
            print(
                f"FAIL: {bypass} dispatcher-bypass options, above the pinned {args.max_bypass}. "
                "A menu gained a second way into a command the dispatcher already routes.",
                file=sys.stderr,
            )
            status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
