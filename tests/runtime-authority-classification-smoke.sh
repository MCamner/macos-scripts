#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$ROOT/docs/AUTHORITY_MAP.md"
PLAN="$ROOT/docs/plans/P1-runtime-authority.md"
FREEZE="$ROOT/scripts/check-runtime-authority.sh"

echo "SMOKE: runtime authority classification"

echo "[1/6] authority files exist"
[[ -f "$MAP" && -f "$PLAN" && -x "$FREEZE" ]]

echo "[2/6] official entrypoint and coordinator are declared"
grep -q '`bin/mqlaunch`.*Official entrypoint' "$MAP"
grep -q '`terminal/launchers/mqlaunch.sh`.*Current runtime coordinator' "$MAP"

echo "[3/6] every authority class is defined"
for class in LIVE COMPAT DEPRECATED TEST-ONLY; do
  grep -q "\*\*$class\*\*" "$MAP"
done

echo "[4/6] UI and dashboard authorities are explicit"
grep -q '`ui/terminal-ui/mq-ui.sh`.*UI authority' "$MAP"
grep -q '`ui/ascii/mqlaunch-dashboard-v7.1.sh`.*Dashboard authority' "$MAP"

echo "[5/6] performance compat exception and forbidden direction are explicit"
grep -q '`terminal/menus/mq-performance-menu.sh`.*COMPAT' "$MAP"
grep -q 'live menus or launchers depending directly on `terminal/mqlaunch-v1/\*`' "$MAP"

echo "[6/7] freeze gate agrees with the documented boundary"
"$FREEZE"

echo "[7/7] every declared entry point is one something can enter through"
# The map called tools/scripts/mqlaunch_desktop.sh an "alternate live entry" for
# months while nothing in the repo, on PATH, in a shell rc or in a LaunchAgent
# started it — and it was the sole declared reason mq-git-menu.sh counted as
# live. A classification nobody checks drifts into a wish.
#
# Reachable means one of two things: the file sits in bin/, which install.sh
# links onto PATH wholesale, or a tracked file outside docs and tests names it.
# Naming it in prose is not entering through it.
python3 - "$ROOT" "$MAP" <<'PY'
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
text = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")

section = re.search(r"^## Entry points — LIVE\s*$(.*?)^## ", text, re.S | re.M)
if not section:
    sys.exit("FAIL: the map no longer has an 'Entry points — LIVE' section")

declared = []
for line in section.group(1).splitlines():
    if not line.startswith("|") or line.startswith("| ---"):
        continue
    cell = line.split("|")[1]
    match = re.search(r"`([^`]+)`", cell)
    if match and "/" in match.group(1):
        declared.append(match.group(1))
if not declared:
    sys.exit("FAIL: the entry point table lists no paths")

tracked = subprocess.run(
    ["git", "-C", str(root), "ls-files"],
    capture_output=True, text=True, check=True).stdout.split()

unreachable = []
for path in declared:
    if not (root / path).exists():
        unreachable.append(f"{path} (missing)")
        continue
    if path.startswith("bin/"):
        continue
    name = pathlib.Path(path).name
    callers = []
    for other in tracked:
        if other == path or other.startswith(("docs/", "tests/")):
            continue
        if other.endswith((".md", ".mmd")) or not (root / other).is_file():
            continue
        # Comment lines are dropped first. Both places that named the desktop
        # script were comments explaining why it is *not* part of the live
        # surface — the first version of this check read those as callers, which
        # is the failure it was written to catch, one level up.
        body = "\n".join(
            line for line in
            (root / other).read_text(encoding="utf-8", errors="replace").splitlines()
            if not line.lstrip().startswith("#"))
        if name in body:
            callers.append(other)
    if not callers:
        unreachable.append(f"{path} (nothing invokes it)")

if unreachable:
    sys.exit(
        "FAIL: declared entry point(s) nothing can enter through:\n  "
        + "\n  ".join(unreachable))
PY
echo "  ok: every entry point in the map is reachable"

bash -n "$0"
echo "OK: runtime authority is documented and enforced"
