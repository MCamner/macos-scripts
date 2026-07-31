#!/usr/bin/env bash
set -euo pipefail

# The registry is the source; help, the reference and the palette are consumers.
#
# command-registry-smoke.sh holds the registry against dispatch (#81) and
# output-mode-parity-smoke.sh holds its output claims against observed behaviour
# (#82). Neither looks at what the product *tells the user* exists. That gap is
# how `mqlaunch help` came to advertise `tools`, `login` and `shortcuts` — three
# commands that print "Unknown command" when typed, because they are words the
# palette's separate dispatcher knows and the typed one does not (#85).
#
# Three consumers, three contracts, because they make different promises:
#
#   docs/COMMANDS.md   "Complete command listing" — coverage required in both
#                      directions. Every command has a documented name or alias,
#                      and every documented word dispatches.
#   mqlaunch help      curated, but no longer by whoever last edited the text.
#                      The registry's `operator_surface` field decides what is
#                      advertised, so help must show exactly the public
#                      entrypoints — not a subset, not a superset — and print
#                      each one under a heading naming its namespace.
#   mqlaunch commands  the same curated list behind panel chrome, so it carries
#                      help's contract plus one of its own: the two must offer
#                      the same commands. They were two hand-maintained copies
#                      until this test arrived, and they had drifted — `chat`
#                      reached the index and never reached help.
#   the palette        a curated picker, same contract as help. Selecting an
#                      entry now runs dispatch_cli_command, so an entry the
#                      registry does not know fails in the user's hands rather
#                      than quietly resolving through a second vocabulary.
#
# All three are extracted from real output, real markdown and the real heredoc
# rather than grepped for remembered names: the gate this replaces was a list of
# eleven hand-picked commands, which only ever proved someone had remembered them.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"
DOCS="$ROOT/docs/COMMANDS.md"
LAUNCH="$ROOT/bin/mqlaunch"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"   # owns the palette heredoc

echo "SMOKE: registry consumers do not contradict the registry"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/7] files exist, and the palette is wired to the registry's dispatcher"
test -f "$REGISTRY"
test -f "$DOCS"
test -f "$LAUNCH"
test -f "$LAUNCHER"

# Checking the palette's entries against the registry only means something while
# selecting one actually goes through the registry's dispatcher. Driving fzf is
# not something a suite can do, so the wiring is asserted instead: the call, and
# the source line that puts the function in the palette's scope.
grep -q 'dispatch_cli_command \${=selected_cmd}' "$LAUNCHER" || {
  echo "FAIL: the palette no longer dispatches through dispatch_cli_command" >&2
  exit 1
}
grep -q 'source "\$BASE_DIR/terminal/launchers/mqlaunch-command-mode.sh"' "$LAUNCHER" || {
  echo "FAIL: command mode is not sourced — dispatch_cli_command is out of scope" >&2
  exit 1
}
echo "  ok: palette selections resolve through dispatch_cli_command"

# Extraction is a separate file so step 5 can run it against mutated input and
# show the comparison failing. Same discipline as command-registry-smoke.sh.
cat > "$run_dir/consumers.py" <<'PY'
"""Extract the command words each consumer advertises."""

# The one heading in help that is a selection rather than a namespace.
HIGHLIGHTS = "POPULAR FLOWS"
import json
import re
import sys


def documented_words(path):
    """Command words from runnable fenced blocks in the command reference.

    Prose is excluded by reading only fenced blocks — `mqlaunch owns no memory
    logic` is a sentence, not a command. Blocks that demonstrate a failure are
    excluded too: the reference documents `mqlaunch doctro` precisely because it
    is *not* a command, and a gate that could not tell the difference would
    force the example to be deleted to stay green.
    """
    words = set()
    body, lang = None, None
    for line in open(path, encoding="utf-8").read().splitlines():
        if line.startswith("```"):
            if body is None:
                body, lang = [], line[3:].strip()
            else:
                if lang in ("bash", "sh", "console", ""):
                    text = "\n".join(body)
                    if "Unknown command" not in text:
                        words |= set(re.findall(
                            r"^\s*(?:\$\s*)?mqlaunch\s+([a-z][a-z0-9-]*)",
                            text, re.M))
                body = None
            continue
        if body is not None:
            body.append(line)
    return words


def palette_words(path):
    """First words of every entry in the command palette's heredoc.

    Entries are tab-separated `command<TAB>description`, and a command may be
    several words (`workflows boot`). Only the first is the dispatch target;
    the rest are its arguments, and the registry models subcommands separately.
    """
    text = open(path, encoding="utf-8").read()
    # The heredoc opener carries the fzf invocation on the same line, so match
    # to the end of that line rather than expecting a newline after EOF'.
    block = re.search(r"run_command_palette\(\).*?cat <<'EOF'[^\n]*\n(.*?)\nEOF",
                      text, re.S)
    if block is None:
        raise SystemExit("could not find the palette heredoc in " + path)
    words = set()
    for line in block.group(1).splitlines():
        entry = line.split("\t", 1)[0].strip()
        if entry:
            words.add(entry.split()[0])
    return words


def advertised_words(path, indent=r" {2}"):
    """Command words from a captured help or index screen.

    Anchored to the leading indent entries use, so headings — which start at
    column 0 — and the description column cannot contribute words.

    The index is read with `indent=" {1,2}"` because it has not always used
    help's two spaces. Insisting on two would make a one-space index look like a
    screen advertising nothing, and the comparison would then report every
    command as missing instead of the one that actually drifted.
    """
    text = open(path, encoding="utf-8").read()
    # `[ \t]+` rather than `\s+`: the latter crosses newlines, so the bare
    # `mqlaunch` line under POPULAR FLOWS borrowed the next row's first word and
    # reported `mqlaunch` as advertised. Harmless while this only looked for
    # ghosts — `mqlaunch` is a real registry word — but the set is compared for
    # equality now, and a phantom member would fail every run.
    return set(re.findall(rf"^{indent}mqlaunch[ \t]+([a-z][a-z0-9-]*)", text, re.M))


def advertised_groups(path):
    """Map each heading in a help capture to the commands printed under it.

    Headings start at column 0 and entries are indented, which is the same
    shape both renderers in terminal/menus/mq-help-menu.sh depend on.
    """
    groups, heading = {}, None
    for line in open(path, encoding="utf-8").read().splitlines():
        if not line.strip():
            continue
        if not line[0].isspace():
            heading = line.strip()
            groups.setdefault(heading, set())
            continue
        if heading is None:
            continue
        found = re.match(r"^ {1,2}mqlaunch[ \t]+([a-z][a-z0-9-]*)", line)
        if found:
            groups[heading].add(found.group(1))
    return groups


def main():
    registry = json.load(open(sys.argv[1], encoding="utf-8"))
    commands = registry["commands"]
    # Two surfaces, because a deprecated alias is dispatchable but is not part of
    # what a consumer may promote. `surface` drives coverage — a command counts
    # as documented only under a name it is not retiring — while `known` is every
    # word that resolves, so documenting a deprecation is not read as a ghost.
    surface = {c["name"]: {c["name"], *c.get("aliases", [])} for c in commands}
    deprecated = {
        d["name"]: d.get("replacement", c["name"])
        for c in commands
        for d in c.get("deprecated_aliases", [])
        if isinstance(d, dict) and "name" in d
    }
    known = set().union(*surface.values()) | set(deprecated)

    docs = documented_words(sys.argv[2])
    help_out = advertised_words(sys.argv[3])
    palette = palette_words(sys.argv[4])
    index = advertised_words(sys.argv[5], indent=r" {1,2}")

    failures = []

    # Same list, two renderings. Set difference rather than a text diff: the
    # index adds a banner and a footer, so the two captures are not meant to be
    # byte-identical — only to advertise the same commands.
    if help_out != index:
        detail = []
        if help_out - index:
            detail.append("only in help: " + " ".join(sorted(help_out - index)))
        if index - help_out:
            detail.append("only in the index: "
                          + " ".join(sorted(index - help_out)))
        failures.append(
            "`mqlaunch help` and `mqlaunch commands` advertise different "
            "commands — " + "; ".join(detail))

    # `main` is the interactive loop the palette was opened from, not a command,
    # and the palette special-cases it before dispatch ever sees it.
    palette_ghosts = sorted(palette - known - {"main"})
    if palette_ghosts:
        failures.append(
            f"offered by the command palette but not dispatchable "
            f"({len(palette_ghosts)}): " + " ".join(palette_ghosts))

    undocumented = sorted(n for n, words in surface.items() if not (words & docs))
    if undocumented:
        failures.append(
            "commands with neither name nor alias in docs/COMMANDS.md "
            f"({len(undocumented)}): " + " ".join(undocumented))

    ghosts = sorted(docs - known)
    if ghosts:
        failures.append(
            f"documented but not dispatchable ({len(ghosts)}): " + " ".join(ghosts))

    public = {c["name"] for c in commands if c["operator_surface"]}
    if help_out != public:
        detail = []
        if public - help_out:
            detail.append("public but unadvertised: "
                          + " ".join(sorted(public - help_out)))
        if help_out - public:
            detail.append("advertised but not a public entrypoint: "
                          + " ".join(sorted(help_out - public)))
        failures.append(
            "`mqlaunch help` does not match the registry's operator surface — "
            + "; ".join(detail))

    # Grouping is part of the contract, not decoration: a command printed under
    # someone else's heading is as wrong as one that is missing, and only a
    # reader would notice.
    grouped = advertised_groups(sys.argv[3])
    namespace_of = {c["name"]: c["namespace"] for c in commands}

    # POPULAR FLOWS is a highlight reel, not a namespace, so it is exempt from
    # the heading rule. The exemption is bounded rather than open: every command
    # it highlights must also appear under its own namespace, so the section can
    # promote a command but never be the only place it is listed.
    highlights = grouped.get(HIGHLIGHTS, set())
    if HIGHLIGHTS not in grouped:
        failures.append(
            f"help has no {HIGHLIGHTS} section — the exemption below is unused "
            f"and should be removed rather than left to widen quietly")
    hidden_in_highlights = sorted(
        name for name in highlights
        if namespace_of.get(name)
        and name not in grouped.get(namespace_of[name].upper(), set()))
    if hidden_in_highlights:
        failures.append(
            f"only listed under {HIGHLIGHTS}, not under their own namespace "
            f"({len(hidden_in_highlights)}): " + " ".join(hidden_in_highlights))

    misfiled = sorted(
        f"{name} under {heading} (namespace {namespace_of[name]})"
        for heading, names in grouped.items()
        if heading != HIGHLIGHTS
        for name in names
        if name in namespace_of
        and namespace_of[name] is not None
        and namespace_of[name].upper() != heading
    )
    if misfiled:
        failures.append(
            f"advertised under the wrong heading ({len(misfiled)}): "
            + "; ".join(misfiled))

    for label, offered in (("`mqlaunch help`", help_out),
                           ("`mqlaunch commands`", index)):
        advertised_ghosts = sorted(offered - known)
        if advertised_ghosts:
            failures.append(
                f"advertised by {label} but not dispatchable "
                f"({len(advertised_ghosts)}): " + " ".join(advertised_ghosts))

    # Deprecating a word and then advertising it is the contradiction the field
    # exists to prevent. The registry says stop using this; help and the palette
    # would be telling the user it is the way in. Both must offer the
    # replacement instead — the word keeps working either way.
    for label, offered in (("`mqlaunch help`", help_out),
                           ("`mqlaunch commands`", index),
                           ("the command palette", palette)):
        promoted = sorted(offered & set(deprecated))
        if promoted:
            failures.append(
                f"deprecated but advertised by {label} ({len(promoted)}): "
                + " ".join(f"{w} (use {deprecated[w]})" for w in promoted))

    if failures:
        for line in failures:
            print("  " + line, file=sys.stderr)
        sys.exit(1)

    print(f"  ok: {len(commands)} commands, {len(docs)} documented words, "
          f"{len(help_out)} advertised words in help and the index, "
          f"{len(palette)} palette entries, no contradictions")


if __name__ == "__main__":
    main()
PY

echo "[2/7] the help list is generated from the registry, not typed beside it"
# The descriptions used to be written next to the registry rather than taken
# from it — two sources for one sentence, the same shape as the `chat` drift
# #126 fixed between help and the index. The block in mq-help-menu.sh is a
# build artifact now, so this asks the generator whether the file is current.
#
# It is generated rather than read at runtime because `doctor` reports python3
# as a check that can be missing, and help is the command that has to work on a
# machine where things are missing.
GENERATOR="$ROOT/tools/scripts/generate-help-list.py"
test -x "$GENERATOR"
python3 "$GENERATOR" --check

echo "[3/7] capture what help advertises"
# Piped, so this also exercises the plain-output contract (#67): if the banner
# came back the extraction would still work, but the capture would be 5 KB of
# box drawing around it.
BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
  timeout 30 bash "$LAUNCH" help >"$run_dir/help.txt" 2>/dev/null
test -s "$run_dir/help.txt"
if grep -q $'\033' "$run_dir/help.txt"; then
  echo "FAIL: help emitted ANSI into a pipe — see plain-output-contract-smoke.sh" >&2
  exit 1
fi
printf '  ok: %s bytes\n' "$(wc -c <"$run_dir/help.txt" | tr -d ' ')"

echo "[4/7] capture what the command index advertises"
# The index ends in pause_enter, so stdin is closed rather than left on the
# terminal — a suite that hangs here would look like a slow test, not a bug.
BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
  timeout 30 bash "$LAUNCH" commands >"$run_dir/index.txt" 2>/dev/null </dev/null
test -s "$run_dir/index.txt"
if grep -q $'\033' "$run_dir/index.txt"; then
  echo "FAIL: the command index emitted ANSI into a pipe" >&2
  exit 1
fi
printf '  ok: %s bytes\n' "$(wc -c <"$run_dir/index.txt" | tr -d ' ')"

echo "[5/7] every command is documented, nothing documented is a ghost, and the two curated surfaces agree"
python3 "$run_dir/consumers.py" "$REGISTRY" "$DOCS" "$run_dir/help.txt" \
  "$LAUNCHER" "$run_dir/index.txt"

echo "[6/7] the failure demo in the reference is still a failure demo"
# Step 3 skips blocks containing "Unknown command". That exemption is only sound
# while such a block exists and still shows a word the registry rejects — the
# moment it does not, the skip is silently widening what the gate ignores.
python3 - "$REGISTRY" "$DOCS" <<'PY'
import json
import sys

registry = json.load(open(sys.argv[1], encoding="utf-8"))
known = {c["name"] for c in registry["commands"]}
known |= {a for c in registry["commands"] for a in c.get("aliases", [])}

blocks, body = [], None
for line in open(sys.argv[2], encoding="utf-8").read().splitlines():
    if line.startswith("```"):
        if body is None:
            body = []
        else:
            blocks.append("\n".join(body))
            body = None
        continue
    if body is not None:
        body.append(line)

demos = [b for b in blocks if "Unknown command" in b]
if not demos:
    sys.exit("no failure-demo block found — the exemption in step 3 is unused "
             "and should be removed rather than left to widen quietly")

import re
for demo in demos:
    words = set(re.findall(r"^\s*mqlaunch\s+([a-z][a-z0-9-]*)", demo, re.M))
    if words - known:
        print(f"  ok: {len(demos)} failure demo(s), "
              f"showing {' '.join(sorted(words - known))}")
        break
else:
    sys.exit("a failure-demo block no longer demonstrates a rejected word")
PY

echo "[7/7] the comparison rejects a consumer that drifts"
# A gate that has never failed is a comment. One fixture per consumer — a command
# the docs do not mention, a documented word nothing dispatches, a palette entry
# the registry does not know, an index that has drifted from help — plus one for
# the rule that spans them: a word the registry retires while a consumer still
# advertises it.
python3 - "$REGISTRY" "$DOCS" "$LAUNCHER" "$run_dir" <<'PY'
import json
import pathlib
import re
import subprocess
import sys

registry_path, docs_path, launcher_path = sys.argv[1], sys.argv[2], sys.argv[3]
run_dir = pathlib.Path(sys.argv[4])
registry = json.load(open(registry_path, encoding="utf-8"))

# 1. A command nobody documented.
mutated = dict(registry)
mutated["commands"] = registry["commands"] + [{
    "name": "never-written-down", "aliases": [], "namespace": None,
    "summary": "fixture", "owner": "macos-scripts", "safety": "read-only",
    "output_modes": ["human"], "json": False, "interactive": False,
    "compat_only": False, "delegates_to": None,
    # Not a public entrypoint: this fixture is about documentation coverage, and
    # making it advertisable would fail the surface rule instead.
    "operator_surface": False,
}]
fixture_registry = run_dir / "registry-plus-one.json"
fixture_registry.write_text(json.dumps(mutated), encoding="utf-8")

# 2. A documented word nothing dispatches.
fixture_docs = run_dir / "docs-plus-one.md"
fixture_docs.write_text(
    pathlib.Path(docs_path).read_text(encoding="utf-8")
    + "\n```bash\nmqlaunch not-a-real-command\n```\n", encoding="utf-8")

# 3. A palette entry nothing dispatches.
launcher_text = pathlib.Path(launcher_path).read_text(encoding="utf-8")
fixture_launcher = run_dir / "launcher-plus-one.sh"
marker = "main\tOpen main menu"
if marker not in launcher_text:
    sys.exit("palette heredoc no longer starts with the main entry")
fixture_launcher.write_text(
    launcher_text.replace(marker, marker + "\nnot-in-the-registry\tfixture", 1),
    encoding="utf-8")

checker = str(run_dir / "consumers.py")
help_txt = str(run_dir / "help.txt")
index_txt = str(run_dir / "index.txt")

# 3b. An index that advertises a command help does not. This is the drift the
# single list was introduced to make impossible, so the fixture reintroduces it
# by hand rather than trusting that it can no longer occur.
#
# The extra word has to be one that dispatches, or the ghost rule would fire
# first and this would prove the wrong thing. It is picked from the registry at
# runtime instead of hard-coded: if help ever advertises every command, the two
# captures become equal and the loop below reports that the fixture stopped
# failing, rather than passing quietly.
help_only = set(re.findall(r"^ {2}mqlaunch\s+([a-z][a-z0-9-]*)",
                           pathlib.Path(help_txt).read_text(encoding="utf-8"),
                           re.M))
unadvertised = sorted({c["name"] for c in registry["commands"]} - help_only)
if not unadvertised:
    sys.exit("help advertises every command — nothing left to drift in fixture 3b")
fixture_index = run_dir / "index-plus-one.txt"
fixture_index.write_text(
    pathlib.Path(index_txt).read_text(encoding="utf-8")
    + f"  mqlaunch {unadvertised[0]}  only in the index\n", encoding="utf-8")

# 4. A word the registry retires while help still offers it.
#
# Help lists canonical names now, never aliases, so the fixture has to build
# both halves: retire an alias in the registry, and add the row that advertises
# it. Taking the alias from a command help actually prints keeps the fixture
# anchored to the real screen rather than to an invented word.
help_text = pathlib.Path(help_txt).read_text(encoding="utf-8")
help_words = set(re.findall(r"^ {2}mqlaunch[ \t]+([a-z][a-z0-9-]*)", help_text, re.M))
retired = dict(registry)
retired["commands"] = [dict(c) for c in registry["commands"]]
for command in retired["commands"]:
    if command["name"] in help_words and command.get("aliases"):
        hit = command["aliases"][0]
        command["aliases"] = [a for a in command["aliases"] if a != hit]
        command["deprecated_aliases"] = [
            {"name": hit, "replacement": command["name"]}]
        break
else:
    sys.exit("no advertised command carries an alias — nothing to retire in fixture 4")
fixture_deprecated = run_dir / "registry-deprecated.json"
fixture_deprecated.write_text(json.dumps(retired), encoding="utf-8")

fixture_help_deprecated = run_dir / "help-deprecated.txt"
fixture_help_deprecated.write_text(
    help_text + f"\n  mqlaunch {hit}  the retired spelling\n", encoding="utf-8")

for label, args, reason in (
    ("an undocumented command",
     [checker, str(fixture_registry), docs_path, help_txt, launcher_path, index_txt],
     "neither name nor alias in docs/COMMANDS.md"),
    ("a documented ghost",
     [checker, registry_path, str(fixture_docs), help_txt, launcher_path, index_txt],
     "documented but not dispatchable"),
    ("a palette entry nothing dispatches",
     [checker, registry_path, docs_path, help_txt, str(fixture_launcher), index_txt],
     "offered by the command palette but not dispatchable"),
    ("an index that has drifted from help",
     [checker, registry_path, docs_path, help_txt, launcher_path, str(fixture_index)],
     "advertise different commands"),
    # Retiring the alias also leaves its command documented under a word that is
    # no longer active, so this fixture reports two problems. The reason check is
    # what makes it prove the deprecation rule rather than the coverage one.
    ("a deprecated word help still advertises",
     [checker, str(fixture_deprecated), docs_path, str(fixture_help_deprecated),
      launcher_path, index_txt],
     "deprecated but advertised by `mqlaunch help`"),
):
    result = subprocess.run([sys.executable, *args], capture_output=True)
    if result.returncode == 0:
        sys.exit(f"{label} did not fail the comparison")
    # Exit status alone is not proof: a crashed checker is also non-zero.
    if reason not in result.stderr.decode():
        sys.exit(f"{label} failed for the wrong reason:\n"
                 + result.stderr.decode())
print("  ok: all four consumers are checked, and each of the five drifts "
      "is detected for its own reason")
PY

bash -n "$0"
echo "OK: help, the command index, the command reference and the palette agree with the registry"
