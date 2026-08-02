#!/usr/bin/env bash
# Smoke: the runtime authority freeze gate passes on the current tree — i.e. no
# shell file outside the documented lists references terminal/mqlaunch-v1/,
# which was deleted in Step 12.6. Local parity for the CI step.
#
# The gate used to scan three directories (terminal/, ui/, mqlaunch/), which is
# narrower than "live runtime shell": automation/ and tools/ hold live code too.
# Two edges sat outside the scan as a result — automation/login/mqlogin.sh
# preferred the frozen v1 launcher over the current one, and
# tools/scripts/create-debug-bundle.sh runs `bash v1/mqlaunch.sh help` from a
# live system-menu row. A gate that cannot see a directory cannot make a claim
# about it, so the steps below pin the scope as well as the result.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/scripts/check-runtime-authority.sh"

echo "SMOKE: runtime authority freeze"

echo "[1/4] the gate passes on a clean tree"
if ! out="$("$GATE" 2>&1)"; then
  printf '[FAIL] runtime authority freeze check failed on a clean tree:\n%s\n' "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '\[PASS\] Runtime authority freeze' || {
  printf '[FAIL] unexpected output from freeze check:\n%s\n' "$out" >&2
  exit 1
}

echo "[2/4] every reference to the v1 tree is classified"
# The property that makes the gate's PASS worth reading. `git ls-files` rather
# than `find`, so an untracked scratch copy of a menu cannot add or hide an
# edge. tests/ is out of scope by design: test tooling drives v1 on purpose.
python3 - "$ROOT" "$GATE" <<'PY'
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
gate_text = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")

listed = set()
for name in ("COMPAT_EDGES", "TOOLING"):
    # The empty form is matched first and on its own line. A single pattern
    # ending at `^\)` reads straight past `NAME=()` and stops at the *next*
    # block's closing paren, so once COMPAT_EDGES emptied, its "list" was
    # silently TOOLING's entries and this check stopped checking what it says.
    if re.search(rf"^{name}=\(\)\s*$", gate_text, re.M):
        continue
    block = re.search(rf"^{name}=\(\n(.*?)^\)", gate_text, re.S | re.M)
    if not block:
        sys.exit(f"FAIL: the gate no longer declares a {name} list")
    listed |= set(re.findall(r'"([^"]+)"', block.group(1)))

tracked = subprocess.run(
    ["git", "-C", str(root), "ls-files", "*.sh", "*.zsh"],
    capture_output=True, text=True, check=True).stdout.split()

unclassified = [
    path for path in tracked
    if not path.startswith(("terminal/mqlaunch-v1/", "tests/"))
    and "mqlaunch-v1" in (root / path).read_text(encoding="utf-8")
    and path not in listed
]
if unclassified:
    sys.exit("FAIL: unclassified reference(s) to mqlaunch-v1: " + ", ".join(unclassified))
PY
echo "  ok: no reference to v1 sits outside both lists"

echo "[3/4] the gate sees automation/ and tools/"
# Proven by planting an edge in each, because a widened scope that is never
# exercised is indistinguishable from the narrow one it replaced. The trap
# restores both files even when an assertion below exits.
plant_backup_dir="$(mktemp -d)"
plants=(
  "automation/login/mqlogin.sh"
  "tools/scripts/doctor.sh"
)
restore_plants() {
  local rel
  for rel in "${plants[@]}"; do
    [[ -f "$plant_backup_dir/$(basename "$rel")" ]] && cp "$plant_backup_dir/$(basename "$rel")" "$ROOT/$rel"
  done
  rm -rf "$plant_backup_dir"
}
trap restore_plants EXIT

for rel in "${plants[@]}"; do
  cp "$ROOT/$rel" "$plant_backup_dir/$(basename "$rel")"
done

# The plants go into tracked files that reference v1 nowhere and sit on neither
# list. An untracked probe would have to be staged for `git ls-files` to see it,
# and this repo can have a second writer in the tree — the test has no business
# touching the index to prove a point about a grep.
printf '\n# planted by %s\nbash "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh" help\n' \
  "$(basename "$0")" >>"$ROOT/tools/scripts/doctor.sh"
if "$GATE" >/dev/null 2>&1; then
  echo "FAIL: a tools/ script reaching v1 did not fail the gate" >&2
  exit 1
fi
cp "$plant_backup_dir/doctor.sh" "$ROOT/tools/scripts/doctor.sh"

# And the same for automation/, the directory that motivated the widening.
printf '\n# planted by %s\nbash "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh" help\n' \
  "$(basename "$0")" >>"$ROOT/automation/login/mqlogin.sh"
if "$GATE" >/dev/null 2>&1; then
  echo "FAIL: an automation/ file reaching v1 did not fail the gate" >&2
  exit 1
fi
cp "$plant_backup_dir/mqlogin.sh" "$ROOT/automation/login/mqlogin.sh"
echo "  ok: both directories are inside the scan"

echo "[4/4] mqlogin falls back to the current runtime, never to v1"
# detect_mqlaunch_base tried `command -v mqlaunch` first and the frozen v1
# launcher second, so a machine without mqlaunch on PATH booted its login flow
# into the compat tree ahead of terminal/launchers/. The first branch wins on a
# normal machine, which is why this went unseen — so drive it with PATH emptied.
fallback="$(
  PATH="/usr/bin:/bin" bash -c '
    set -euo pipefail
    PROJECT_ROOT="$1"
    eval "$(sed -n "/^detect_mqlaunch_base()/,/^}/p" "$PROJECT_ROOT/automation/login/mqlogin.sh")"
    detect_mqlaunch_base
  ' _ "$ROOT"
)"
case "$fallback" in
  *mqlaunch-v1*)
    echo "FAIL: mqlogin falls back to the frozen v1 launcher: $fallback" >&2
    exit 1
    ;;
  *bin/mqlaunch*) ;;
  *)
    echo "FAIL: mqlogin fallback is not the official entrypoint: $fallback" >&2
    exit 1
    ;;
esac
echo "  ok: the fallback is bin/mqlaunch"

printf '[PASS] runtime authority freeze smoke\n'
