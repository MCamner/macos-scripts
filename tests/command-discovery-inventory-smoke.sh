#!/usr/bin/env bash
# Guards tools/scripts/inventory-command-surfaces.py, the inventory of how
# mqlaunch commands are discovered.
#
# The registry already has gates for every machine-readable discovery surface:
# docs/COMMANDS.md, the README, --help and the palette are compared against
# mqlaunch/lib/command-registry.json, and the registry against the dispatcher.
# The interactive menus had none, which is why twelve menu options turned out to
# run a script the dispatcher also routes — two ways into one capability.
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
MAX_BYPASS=12

echo "SMOKE: command discovery inventory"

echo "[1/7] tool exists and compiles"
test -x "$TOOL"
test -f "$REGISTRY"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/mqlaunch-pycache" python3 -m py_compile "$TOOL"

echo "[2/7] the inventory runs and reports"
"$TOOL" >/dev/null

echo "[3/7] --json is a single valid document with the expected schema"
"$TOOL" --json | python3 -c '
import sys, json
data = json.load(sys.stdin)
assert data["schema"] == "mq-command-discovery-inventory.v1", data["schema"]
for key in ("options", "counts", "unclassified", "registry"):
    assert key in data, f"missing key: {key}"
assert data["options"], "inventory found no menu options at all"
'

echo "[4/7] every option is classified and counted"
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

echo "[5/7] the output does not depend on filesystem order"
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

echo "[6/7] untracked files in the checkout do not change the answer"
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
run_network_ghost() { "$BASE_DIR/bin/mqlaunch" ghost; }
PROBE
with_untracked="$("$TOOL" --json)"
[[ "$with_untracked" == "$first" ]] || {
  echo "FAIL: an untracked .sh file changed the inventory; the source list is not from git" >&2
  exit 1
}
rm -rf "$probe_dir"
echo "  ok: untracked shell files are outside the inventory"

echo "[7/7] the bypass ratchet holds, and fires when it should"
"$TOOL" --max-bypass "$MAX_BYPASS" >/dev/null || {
  echo "FAIL: dispatcher-bypass count rose above the pinned $MAX_BYPASS" >&2
  exit 1
}
# Prove the ratchet is not vacuous: one lower must fail. Without this the pin
# could be set above any real count and never fire.
if "$TOOL" --max-bypass "$((MAX_BYPASS - 1))" >/dev/null 2>&1; then
  echo "FAIL: --max-bypass $((MAX_BYPASS - 1)) passed, so the ratchet proves nothing" >&2
  exit 1
fi
echo "  ok: $MAX_BYPASS pinned, one lower rejected"

echo "OK: command discovery inventory smoke test passed"
