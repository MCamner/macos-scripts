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

# Menu loops that live outside terminal/menus/. Each is a panel an operator
# reads and answers, so leaving them out made the per-loop numbers describe a
# subset of the product rather than the product.
#
# gitlaunch.sh is the clearest case: `mqlaunch git` opens it, not
# mq-git-menu.sh. The git surface the roadmap measured was not the git surface
# anyone reaches by typing the git command, and nothing would have reported it
# crossing ten.
#
# tools/scripts/mqlaunch_desktop.sh used to be excluded here on the grounds that
# it was a separate live entrypoint needing its own measurement. It was not an
# entrypoint at all — nothing started it — and it has been deleted. Excluding it
# was still the right call: its 63 arms were a second dispatcher's, and counting
# them here would have mixed two products in one total.
EXTRA_MENUS = (
    ROOT / "terminal" / "launchers" / "gitlaunch.sh",
    ROOT / "terminal" / "themes" / "mq-zsh-theme-switcher.sh",
    ROOT / "automation" / "workflows" / "workspace.sh",
    ROOT / "ui" / "dashboards" / "mq-dashboard.sh",
)


def menu_files() -> list[Path]:
    """Every file holding an operator-facing menu loop, in a stable order."""
    return sorted(MENUS.glob("*.sh")) + [p for p in EXTRA_MENUS if p.is_file()]


SCHEMA = "mq-command-discovery-inventory.v1"

# A dispatch arm in a menu's case statement. Both key styles count: `  3) ... ;;`
# and `  r|R) ... ;;`. Restricting this to digits was wrong — the menus route most
# of their command invocations through letter keys, so a numeric-only scan saw 4
# dispatcher calls where there are dozens. Two leading spaces keeps it to indented
# case arms rather than any line that happens to start with a word.
# One case key: a number or a single letter, or several of those joined by `|`.
# The alternatives used to be "all digits" or "all letters", which missed the
# mixed form. `9|p|P` and `7|m|M` — a numbered row that also answers the letter
# it used to be bound to — counted as nothing at all, so a menu lost a choice
# from its total by keeping an old key working.
KEY = r"(?:[0-9]+|[A-Za-z])(?:\|(?:[0-9]+|[A-Za-z]))*"

ARM = re.compile(r"^\s{2,}(" + KEY + r")\)\s*(.+?)\s*;;\s*$")

# A case arm whose key sits alone on its line, with the body following until
# `;;`. gitlaunch.sh and ui/dashboards/mq-dashboard.sh are written entirely this
# way, so a one-line-only scan saw nothing in either — including the menu that
# `mqlaunch git` actually opens. The key had to be on the same line as its body
# to be counted, which is a fact about shell formatting, not about how many
# choices a panel offers.
ARM_OPEN = re.compile(r"^\s{2,}(" + KEY + r")\)\s*$")
ARM_CLOSE = re.compile(r"^\s*;;\s*$")

# How far to read for an arm's `;;`. An arm longer than this is not a dispatch
# line, and stopping keeps a malformed case from swallowing the rest of a file.
ARM_BODY_LINES = 40

# ARM_OPEN, ARM_CLOSE and ARM_BODY_LINES were each defined a second time here,
# and in Python the second definition is the one that runs. That copy predated
# KEY and accepted all-digits or all-letters but not the mixed form, so widening
# the key pattern above had no effect on multi-line arms: `7|m|M)` and `8|p|P)`
# in gitlaunch.sh matched nothing, and the loop an operator sees as ten was
# measured as eight — under a gate whose subject is how many choices a loop
# offers. Held by step 9 of tests/command-discovery-inventory-smoke.sh.

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
# were all attributed to it: they are 9 to 15 lines long and shared a file with a
# neighbour that runs it.
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


# Back and quit are not operator choices — ROADMAP P2 counts what a menu offers
# to do, not the two ways out of it. They were half-counted before: `b|B|back)`
# never matched ARM because of the multi-letter alternative, while `x|X)` did, so
# whether an exit row showed up in the total depended on how the arm happened to
# be spelled.
EXIT_TOKENS = {"b", "back", "x", "q", "quit", "exit", "0"}


def is_exit_option(option: str) -> bool:
    parts = [part.strip().lower() for part in option.split("|")]
    return bool(parts) and all(part in EXIT_TOKENS for part in parts)


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


# Bypasses that are the shell's fault, not the menu's. Each entry names the file,
# the script, and why routing it through the dispatcher would break it.
#
# #132 deliberately shipped no allow-list: "nothing needs a documented exception
# yet, and building the mechanism first would have made the target reachable by
# writing prose." That held while the bypass count was already zero. Reading
# multi-line case arms surfaced one that had been invisible, and it has a real
# reason rather than a prose one, so the mechanism is built now — for one entry,
# with the reason next to it.
BYPASS_EXCEPTIONS = {
    # The guide writes a directory to ~/.hal_nav and the menu cd's there
    # afterwards. `mqlaunch guide` runs in a subprocess, so the cd would apply to
    # a shell that exits immediately. The bypass is what makes the feature work.
    ("mq-main-menu.sh", "hal-terminal-guide.sh"): "cd must happen in this shell",
}


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
        if (menu.name, target) in BYPASS_EXCEPTIONS:
            return "menu-local", target
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
    for menu in menu_files():
        lines = menu.read_text(encoding="utf-8", errors="replace").splitlines()
        # A file is not a menu. mq-tools-menu.sh holds five loops, so counting
        # options per file said "23 choices" for a menu showing ten, and
        # splitting a long menu into submenus — the fix ROADMAP P2 asks for —
        # could never improve the number. Each arm is attributed to the loop
        # that contains it instead, which is what an operator actually faces.
        loop = None
        for number, line in enumerate(lines, 1):
            defined = FUNC_DEF.match(line)
            if defined:
                loop = defined.group(1)

            match = ARM.match(line)
            if match:
                option, action = match.group(1), match.group(2)
            else:
                # The key alone on its line: collect the body up to `;;` and
                # classify the joined text, so a multi-line arm is read the same
                # way as the single-line form.
                opened = ARM_OPEN.match(line)
                if not opened:
                    continue
                body = []
                for ahead in lines[number : number + ARM_BODY_LINES]:
                    if ARM_CLOSE.match(ahead):
                        break
                    body.append(strip_comment(ahead).strip())
                else:
                    # No `;;` within reach — not a dispatch arm.
                    continue
                option = opened.group(1)
                action = " ".join(part for part in body if part)
                if not action:
                    continue

            kind, target = classify(action, menu, per_file, context)
            if is_exit_option(option):
                kind, target = "navigation", None
            options.append(
                {
                    "menu": menu.name,
                    "loop": loop,
                    "line": number,
                    "option": option,
                    "action": action,
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
    parser.add_argument(
        "--max-loop",
        type=int,
        default=None,
        help="exit non-zero if any single menu loop offers more choices than this",
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
    if args.max_loop is not None:
        # Per loop, not per file, and excluding back/quit — the same definition
        # ROADMAP P2 is sized by. A file can hold several loops; what an operator
        # faces is one panel at a time.
        #
        # This is the target that went unenforced longest. The roadmap measured
        # it on demand and nothing failed when it slipped, which is how four
        # menus drifted past ten and how gitlaunch.sh sat at eleven unremarked
        # until the scan was widened to see it at all.
        per_loop: dict[tuple[str, str], int] = collections.Counter()
        for option in data["options"]:
            if option["kind"] == "navigation":
                continue
            per_loop[(option["menu"], option["loop"])] += 1
        over = sorted(
            ((count, menu, loop) for (menu, loop), count in per_loop.items()
             if count > args.max_loop),
            reverse=True,
        )
        if over:
            print(
                f"FAIL: {len(over)} menu loop(s) offer more than {args.max_loop} "
                "choices. Group the extras into a submenu rather than deleting them.",
                file=sys.stderr,
            )
            for count, menu, loop in over:
                print(f"  {count:3}  {menu}  {loop}", file=sys.stderr)
            status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
