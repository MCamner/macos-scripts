#!/usr/bin/env python3
"""Write the command list `mqlaunch help` and `mqlaunch commands` print.

The list used to be typed next to the registry rather than taken from it, which
is two sources for one sentence. #126 removed the copy between help and the
index; this removes the copy between help and the registry.

The block is generated into `terminal/menus/mq-help-menu.sh` rather than read at
runtime on purpose. `doctor` reports `python3` as a check that can be missing,
and help is the one command that has to work on a machine where things are
missing — a help screen that needs a JSON parser to render is the wrong trade.
The generated block is therefore a build artifact, and
`tests/registry-consumer-parity-smoke.sh` regenerates it and requires the file
to be unchanged, so the registry stays the only place a description is written.

    tools/scripts/generate-help-list.py            # rewrite the block in place
    tools/scripts/generate-help-list.py --check    # exit 1 if it is out of date
    tools/scripts/generate-help-list.py --stdout   # print, touch nothing
"""
import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "mqlaunch" / "lib" / "command-registry.json"
HELP_MENU = ROOT / "terminal" / "menus" / "mq-help-menu.sh"

OPEN_MARK = "  cat <<'LIST'\n"
CLOSE_MARK = "LIST\n"

# The order groups appear in. Kept here rather than derived from the registry
# because it is an editorial decision — what an operator should meet first —
# and sorting alphabetically would open the screen on AGENT.
GROUP_ORDER = [
    "core", "menus", "checks", "ops", "ai",
    "agent", "obsidian", "srm", "skills", "repos", "hal",
    "utility",
]

# The one section that is a selection rather than a namespace. Every command
# here must also be public, so it appears under its own heading further down —
# tests/registry-consumer-parity-smoke.sh holds the section to that, so it can
# promote a command but never be the only place it is listed.
HIGHLIGHTS = ["doctor", "stack", "perf", "ask", "review"]

# `  mqlaunch ` plus a name column. 26 characters before the description, which
# is what SUMMARY_LIMIT in validate-command-registry.py is derived from.
NAME_COLUMN = 14


def render(commands) -> str:
    public = [c for c in commands if c["operator_surface"]]
    groups: dict[str, list] = {}
    for command in public:
        groups.setdefault(command["namespace"], []).append(command)

    unordered = sorted(set(groups) - set(GROUP_ORDER))
    if unordered:
        raise SystemExit(
            "namespaces with no place in GROUP_ORDER: " + " ".join(unordered))

    by_name = {c["name"]: c for c in public}
    missing = [h for h in HIGHLIGHTS if h not in by_name]
    if missing:
        raise SystemExit(
            "highlighted but not public entrypoints: " + " ".join(missing))

    lines = ["POPULAR FLOWS", "  mqlaunch"]
    lines += [f"  mqlaunch {name}" for name in HIGHLIGHTS]

    for group in GROUP_ORDER:
        if group not in groups:
            continue
        lines.append("")
        lines.append(group.upper())
        for command in sorted(groups[group], key=lambda c: c["name"]):
            lines.append(
                f"  mqlaunch {command['name']:<{NAME_COLUMN}} {command['summary']}")

    return "\n".join(lines) + "\n"


def splice(text: str, block: str) -> str:
    start = text.index(OPEN_MARK) + len(OPEN_MARK)
    end = text.index(CLOSE_MARK, start)
    return text[:start] + block + text[end:]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="exit 1 when the file is out of date")
    parser.add_argument("--stdout", action="store_true",
                        help="print the block and write nothing")
    args = parser.parse_args()

    commands = json.loads(REGISTRY.read_text(encoding="utf-8"))["commands"]
    block = render(commands)

    if args.stdout:
        sys.stdout.write(block)
        return 0

    current = HELP_MENU.read_text(encoding="utf-8")
    wanted = splice(current, block)

    if args.check:
        if current != wanted:
            print(f"FAIL: {HELP_MENU.relative_to(ROOT)} does not match the "
                  f"registry — run tools/scripts/generate-help-list.py",
                  file=sys.stderr)
            return 1
        rows = sum(1 for line in block.splitlines() if line.startswith("  mqlaunch "))
        print(f"  ok: {rows} rows generated from the registry, file is current")
        return 0

    HELP_MENU.write_text(wanted, encoding="utf-8")
    print(f"wrote {HELP_MENU.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
