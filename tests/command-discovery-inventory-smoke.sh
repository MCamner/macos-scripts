#!/usr/bin/env bash
# Guards tools/scripts/inventory-command-surfaces.py, the inventory of how
# mqlaunch commands are discovered.
#
# The registry already has gates for every machine-readable discovery surface:
# docs/COMMANDS.md, the README, --help and the palette are compared against
# mqlaunch/lib/command-registry.json, and the registry against the dispatcher.
# The interactive menus had none, which is why twelve menu options turned out to
# run a script the dispatcher also routes — two ways into one capability. Three are
# left. The doctor and network rows have been rerouted, and four of the original
# twelve were misclassifications the inventory has since corrected.
#
# This does not assert the inventory's individual rows. The classification reads
# shell with regexes and follows a menu action one function deep, so a row is a
# lead. What is asserted is the part that has to hold for the inventory to be
# worth reading at all: every option is classified, nothing is silently dropped,
# the output does not depend on filesystem order, and the count of duplicated
# paths cannot grow while they are worked through.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/scripts/inventory-command-surfaces.py"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"

# Today's count of menu options that bypass the dispatcher. Lower it as the
# duplicated paths are removed; a rise means a menu gained a second way into a
# command the dispatcher already routes.

echo "SMOKE: command discovery inventory"

echo "[1/9] tool exists and compiles"
test -x "$TOOL"
test -f "$REGISTRY"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/mqlaunch-pycache" python3 -m py_compile "$TOOL"

echo "[2/9] the inventory runs and reports"
"$TOOL" >/dev/null

echo "[3/9] --json is a single valid document with the expected schema"
"$TOOL" --json | python3 -c '
import sys, json
data = json.load(sys.stdin)
assert data["schema"] == "mq-command-discovery-inventory.v1", data["schema"]
for key in ("options", "counts", "unclassified", "registry"):
    assert key in data, f"missing key: {key}"
assert data["options"], "inventory found no menu options at all"
'

echo "[4/9] every option is classified and counted"
# The property that made tests/manifest.tsv useful: nothing invisible. A row that
# fell outside the known classes, or a class that stopped being counted, would
# make every headline number in the report quietly wrong.
inventory_json="$(mktemp)"
trap 'rm -f "$inventory_json"' EXIT
"$TOOL" --json >"$inventory_json"
python3 - "$inventory_json" <<'PY'
import sys, json

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
unclassified = data["unclassified"]
if unclassified:
    sys.exit(f"FAIL: {len(unclassified)} unclassified option(s)")
counted = sum(data["counts"].values())
if counted != len(data["options"]):
    sys.exit(f"FAIL: counts sum to {counted}, but there are {len(data['options'])} options")
PY
"$TOOL" --fail-on-unclassified >/dev/null

echo "[5/9] the output does not depend on filesystem order"
# Handler names are defined in more than one file. An earlier revision picked a
# winner globally, so the whole inventory shifted with directory order — 4
# dispatcher calls one run, 17 the next. Resolution is now menu-local first, and
# this pins that it stays deterministic.
first="$("$TOOL" --json)"
second="$("$TOOL" --json)"
[[ "$first" == "$second" ]] || {
  echo "FAIL: two runs of the inventory disagree" >&2
  exit 1
}

echo "[6/9] untracked files in the checkout do not change the answer"
# The defect this pins was invisible locally and only CI could see it. A
# gitignored backups/scripts/ tree holds old copies of the menus and launchers,
# and since a handler name can be defined in several files, resolution sometimes
# landed in a backup — 9 bypass options on a developer machine, 12 on a clean
# runner. The source list now comes from `git ls-files`. An untracked file that
# defines a colliding handler must therefore be ignored entirely.
probe_dir="$ROOT/.inventory-untracked-probe.$$"
mkdir -p "$probe_dir"
trap 'rm -f "$inventory_json"; rm -rf "$probe_dir"' EXIT
cat >"$probe_dir/collide.sh" <<'PROBE'
#!/usr/bin/env bash
# Same handler names the real menus use, wired to the dispatcher instead.
open_system_menu() { "$BASE_DIR/bin/mqlaunch" system; }
# Runs network ghost.
run_network_ghost() { "$BASE_DIR/bin/mqlaunch" ghost; }
PROBE
with_untracked="$("$TOOL" --json)"
[[ "$with_untracked" == "$first" ]] || {
  echo "FAIL: an untracked .sh file changed the inventory; the source list is not from git" >&2
  exit 1
}
rm -rf "$probe_dir"
echo "  ok: untracked shell files are outside the inventory"

echo "[7/9] no menu option bypasses the dispatcher"
# The pin was a ratchet at three while the count came down. It is zero now, so
# the ratchet's own proof — "one lower must fail" — has nowhere to go: there is
# no -1. The gate is proven by planting a bypass instead, which is a stronger
# claim than an off-by-one anyway.
"$TOOL" --max-bypass 0 >/dev/null || {
  echo "FAIL: a menu option runs a script the dispatcher also routes" >&2
  "$TOOL" | sed -n '/DISPATCHER BYPASS/,/^$/p' >&2
  exit 1
}

echo "[8/9] no menu loop offers more than ten choices"
# ROADMAP P2's per-loop target, enforced rather than measured on demand. It went
# unenforced longest of the three, which is exactly why four menus drifted past
# ten and gitlaunch.sh sat at eleven until the scan was widened to see it.
#
# Ten menus were brought under the limit to make this gate landable: #132, #136,
# #137, #141, #142, #143, #144, #146, #147, #148, #149. Adding it earlier would
# have failed the suite on arrival, which is the only reason it comes last.
"$TOOL" --max-loop 10 >/dev/null || {
  echo "FAIL: a menu loop grew past ten operator choices" >&2
  "$TOOL" --max-loop 10 2>&1 >/dev/null | head -6 >&2
  exit 1
}

# And the gate must be able to fail. Three loops sit exactly at ten, so a limit
# of nine has to report them — an off-by-one that costs nothing to check and
# proves the comparison is live rather than a flag that always returns 0.
if "$TOOL" --max-loop 9 >/dev/null 2>&1; then
  echo "FAIL: --max-loop 9 passed; the per-loop gate is not comparing anything" >&2
  exit 1
fi
echo "  ok: no loop over ten, and the limit is enforced rather than recorded"

echo "[9/10] a mixed number-and-letter key counts as a choice"
# `7|m|M)` and `8|p|P)` — a numbered row that also answers the letter it was
# bound to before it had a number. Two regexes named ARM_OPEN were defined in
# the tool, and the second one won: it accepted all-digits or all-letters, never
# the mixed form. Both of gitlaunch.sh's merge rows were therefore invisible,
# and the loop the operator sees as ten was measured as eight — under a gate
# whose whole subject is how many choices a loop offers.
#
# Asserted through the tool's own output rather than by re-reading the file, and
# on a menu that is written entirely in the multi-line arm style the bug needed.
"$TOOL" --json | python3 -c '
import re
import sys, json

options = json.load(sys.stdin)["options"]
keys = {str(o["option"]) for o in options if o["menu"] == "gitlaunch.sh"}
mixed = re.compile(r"^[0-9]+(\|[A-Za-z])+$")
found = sorted(k for k in keys if mixed.match(k))
if len(found) < 2:
    sys.exit(
        "FAIL: gitlaunch.sh should offer two mixed-key rows (safe merge, PR "
        "merge); the inventory sees " + str(len(found)) + ". Seen: "
        + ", ".join(sorted(keys)))
'
echo "  ok: mixed keys are counted"

echo "[10/10] the inventory still notices a bypass and a duplication"
# Both gates are at zero, so nothing in the repo exercises them. Each is proven
# by reintroducing the defect in a tracked menu and taking it out again. The
# trap restores the file even when an assertion below exits.
PLANT_MENU="$ROOT/terminal/menus/mq-net-menu.sh"
PLANT_BACKUP="$(mktemp)"
cp "$PLANT_MENU" "$PLANT_BACKUP"
# Restores plant from saved script state.
restore_plant() { cp "$PLANT_BACKUP" "$PLANT_MENU"; rm -f "$PLANT_BACKUP"; }
trap restore_plant EXIT

# A bypass: a script the dispatcher also routes, run directly from a menu
# option. It has to be a case arm — the classifier reads menu options, and a
# loose function would be scanned for invocations but never classified, which is
# how the first version of this fixture passed while proving nothing.
python3 - "$PLANT_MENU" <<'PLANT'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
anchor = "    9) open_network_settings ;;\n"
if anchor not in text:
    sys.exit(f"{path.name} no longer has the arm this fixture inserts after")
path.write_text(
    text.replace(anchor, anchor + '    99) "$BASE_DIR/tools/scripts/overseer.sh" ;;\n', 1),
    encoding="utf-8")
PLANT
if "$TOOL" --max-bypass 0 >/dev/null 2>&1; then
  echo "FAIL: a planted dispatcher bypass was not reported" >&2
  exit 1
fi
cp "$PLANT_BACKUP" "$PLANT_MENU"

# A duplication: a command another menu already offers.
printf '\n# planted by %s\nplanted_duplicate() { "$BASE_DIR/bin/mqlaunch" doctor; }\n' \
  "$(basename "$0")" >>"$PLANT_MENU"
if ! "$TOOL" | grep -q "exposed in several menus"; then
  echo "FAIL: a planted cross-menu duplication was not reported" >&2
  exit 1
fi
cp "$PLANT_BACKUP" "$PLANT_MENU"

# And with both taken out, the repo reports neither.
if "$TOOL" | grep -q "exposed in several menus"; then
  echo "FAIL: a command is offered by more than one menu" >&2
  "$TOOL" | sed -n '/exposed in several menus/,$p' >&2
  exit 1
fi
echo "  ok: both defects are detected when planted, and neither is present"

echo "OK: command discovery inventory smoke test passed"
