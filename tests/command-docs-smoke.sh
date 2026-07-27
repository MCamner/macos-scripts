#!/usr/bin/env bash
set -euo pipefail

# README is the fifth consumer of the command registry.
#
# tests/registry-consumer-parity-smoke.sh holds three — `mqlaunch help`,
# docs/COMMANDS.md and the command palette — and validate-command-registry.py
# holds dispatch itself. README was the gap: it is the first page anyone reads,
# it prints commands in runnable blocks, and nothing checked that those commands
# exist.
#
# This file used to check something else. It named eleven commands — palette,
# ghost, pulse, reap, guard, mc, nickname-set, theme-macos, theme-reset, bundle —
# and grepped for each in docs/COMMANDS.md and again in the dispatcher. Every one
# of those assertions is now strictly weaker than a gate that already runs:
# COMMANDS.md coverage is required in both directions for all 73 commands, and
# registry-versus-dispatch parity is exact. A hand-maintained list of remembered
# names proves only that someone remembered them, and it goes stale in the one
# direction that matters — the twelfth command nobody thought to add.
#
# README has the same contract as `mqlaunch help`: it is a curated introduction,
# so coverage is not required — forcing all 73 commands onto the front page would
# make it worse for the person it is written for. But every command it does show
# must work, and it must not promote a word the registry is retiring.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"

echo "SMOKE: README command contract"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/4] files exist, and README points readers at the full reference"
test -f "$README"
test -f "$REGISTRY"
# README is deliberately partial, so it has to say where the whole surface is.
# Without this, trimming README to nothing would satisfy every other check here.
grep -q 'docs/COMMANDS.md' "$README" || {
  echo "FAIL: README does not link docs/COMMANDS.md — a curated index that does" >&2
  echo "      not name the full reference is a dead end" >&2
  exit 1
}

# Extraction lives in its own file so step 3 can run it against mutated input and
# show the comparison failing. Same discipline as the other registry gates.
cat > "$run_dir/readme.py" <<'PY'
"""Check the command words README advertises against the registry."""
import json
import re
import sys


def advertised_words(path):
    """Command words from runnable fenced blocks in README.

    Fenced blocks only, because README is mostly prose and the product boundary
    is written as sentences: `mqlaunch shows the right workflow` would otherwise
    contribute a command called `shows`. Blocks demonstrating a failure are
    skipped for the same reason as in the command reference — showing what a
    rejected word looks like is documentation, not a claim that it dispatches.
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


def main():
    registry = json.load(open(sys.argv[1], encoding="utf-8"))
    commands = registry["commands"]

    active = {c["name"] for c in commands}
    active |= {a for c in commands for a in c.get("aliases", [])}
    deprecated = {
        d["name"]: d.get("replacement", c["name"])
        for c in commands
        for d in c.get("deprecated_aliases", [])
        if isinstance(d, dict) and "name" in d
    }

    advertised = advertised_words(sys.argv[2])
    failures = []

    ghosts = sorted(advertised - active - set(deprecated))
    if ghosts:
        failures.append(
            f"shown in README but not dispatchable ({len(ghosts)}): "
            + " ".join(ghosts))

    # Deprecated words still dispatch, so they are not ghosts — but README is the
    # front page. Promoting a word the registry is retiring teaches the spelling
    # that is going away. Same rule help and the palette follow.
    promoted = sorted(advertised & set(deprecated))
    if promoted:
        failures.append(
            f"deprecated but shown in README ({len(promoted)}): "
            + " ".join(f"{w} (use {deprecated[w]})" for w in promoted))

    if failures:
        for line in failures:
            print("  " + line, file=sys.stderr)
        sys.exit(1)

    print(f"  ok: {len(advertised)} commands shown in README, all dispatchable")


if __name__ == "__main__":
    main()
PY

echo "[2/4] every command README shows is one that dispatches"
python3 "$run_dir/readme.py" "$REGISTRY" "$README"

echo "[3/4] the check rejects a README that drifts"
# A gate that has never failed is a comment. Both directions the rule covers: a
# word nothing dispatches, and a word the registry is retiring.
python3 - "$REGISTRY" "$README" "$run_dir" <<'PY'
import json
import pathlib
import re
import subprocess
import sys

registry_path, readme_path = sys.argv[1], sys.argv[2]
run_dir = pathlib.Path(sys.argv[3])
readme = pathlib.Path(readme_path).read_text(encoding="utf-8")

# 1. A command README shows that nothing dispatches.
ghost_readme = run_dir / "readme-ghost.md"
ghost_readme.write_text(
    readme + "\n```bash\nmqlaunch not-a-real-command\n```\n", encoding="utf-8")

# 2. A word the registry is retiring while README still shows it. README today
# shows only canonical names, so both sides are mutated: a shown command gains a
# retired spelling, and README gains a block that teaches it. Anchored to a
# command README really shows, so the fixture raises rather than testing nothing
# if README stops showing commands at all.
shown = set()
body, lang = None, None
for line in readme.splitlines():
    if line.startswith("```"):
        if body is None:
            body, lang = [], line[3:].strip()
        else:
            if lang in ("bash", "sh", "console", ""):
                shown |= set(re.findall(
                    r"^\s*(?:\$\s*)?mqlaunch\s+([a-z][a-z0-9-]*)",
                    "\n".join(body), re.M))
            body = None
        continue
    if body is not None:
        body.append(line)

registry = json.load(open(registry_path, encoding="utf-8"))
retired = dict(registry)
retired["commands"] = [dict(c) for c in registry["commands"]]
target = next((c for c in retired["commands"] if c["name"] in shown), None)
if target is None:
    sys.exit("README shows no registry command — fixture 2 cannot run")
old_spelling = target["name"] + "-old"
target["deprecated_aliases"] = [
    {"name": old_spelling, "replacement": target["name"]}]
retired_registry = run_dir / "registry-retired.json"
retired_registry.write_text(json.dumps(retired), encoding="utf-8")

retired_readme = run_dir / "readme-retired.md"
retired_readme.write_text(
    readme + f"\n```bash\nmqlaunch {old_spelling}\n```\n", encoding="utf-8")

checker = str(run_dir / "readme.py")

for label, args, reason in (
    ("a command README shows that nothing dispatches",
     [checker, registry_path, str(ghost_readme)],
     "shown in README but not dispatchable"),
    ("a deprecated command README still shows",
     [checker, str(retired_registry), str(retired_readme)],
     "deprecated but shown in README"),
):
    result = subprocess.run([sys.executable, *args], capture_output=True)
    if result.returncode == 0:
        sys.exit(f"{label} was not detected")
    # Exit status alone is not proof: a crashed checker is also non-zero.
    if reason not in result.stderr.decode():
        sys.exit(f"{label} failed for the wrong reason:\n"
                 + result.stderr.decode())
print("  ok: both drifts are detected for their own reason")
PY

echo "[4/4] shell syntax"
bash -n "$0"

echo "OK: README shows only commands that dispatch"
