#!/usr/bin/env bash
# Golden snapshot of the nine command_perf_* screens.
#
# docs/plans/step-12-v1-removal.md called for this fixture *before* the
# performance data layer was migrated out of the frozen v1 tree (12.3, gating
# 12.4). It was never written, and the migration shipped verified only by
# looking at the rendered panel — which proves the panel, not the nine screens
# behind it. R1 in that plan's risk table is unnoticed output drift, and the
# mitigation for R1 was the step that got skipped.
#
# The snapshot was reconstructed afterwards from a worktree of the commit before
# the migration and compared screen by screen: stdout, stderr and exit code
# matched on all nine. The golden below is that agreed output, so it pins the
# behaviour the migration was supposed to preserve rather than whatever happens
# to be true today.
#
# All nine are live: rows 1-9 of terminal/menus/mq-performance-menu.sh call them
# directly.
#
# The system commands are stubbed (tests/fixtures/perf-stubs) so the fixture is
# a rendering snapshot rather than a photograph of one laptop. The first version
# captured this machine's battery, load and process list and failed on CI, which
# runs Linux and has no pmset. Stubbing also makes the comparison sharper: with
# the inputs fixed, almost nothing needs masking.
#
# THE GOLDEN PINS FOUR DEFECTS. It records what these screens do, which is not
# the same as what they should do, and reconstructing it is what found all four.
# Every one predates the migration and renders identically on both sides:
#
#   1. `print_section: command not found`, 11 times. Seven of the nine screens
#      call print_section, and one also calls print_kv. Both live only in the
#      v1 tree's lib/ui.sh, which the live path never sourced — the menu sources
#      mq-ui.sh and the data layer, nothing else. Rows 3 to 9 have been printing
#      that error instead of a heading for as long as this path has existed.
#   2. `Load (1m)` renders as one run of concatenated decimals ("1.501.251.10").
#      perf_load_1m splits `uptime` on ", " while macOS separates the three load
#      averages with spaces, so it keeps all three and `tr -d ' '` glues them.
#   3. command_perf_quick_watch cannot exit on its own; it refreshes forever and
#      is bounded here, so its exit status in the golden is the timeout's 124.
#   4. `awk -v load=...` in perf_health_score — fixed, because it is what kept
#      this test from being a CI gate at all. `load` is a gawk builtin, so gawk
#      rejects it and the whole health score fails on any system with GNU awk.
#      BSD awk on macOS accepts it, which is why it went unseen. The variable is
#      renamed; the golden is unchanged on macOS, which is the proof the rename
#      is behaviour-preserving here.
#
# Fixing the other three changes this output, and the golden must be regenerated
# in the same commit with the reason written down. Do not regenerate it to make
# an unexplained diff go away — that is the failure mode a golden exists to
# catch.
#
# Verified as a chain, not a claim: the pre-migration implementation extracted
# from 94d0eba renders byte-identical to this golden, the current one does too,
# and a one-character label change is reported.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERF="$ROOT/mqlaunch/lib/performance.sh"
NORMALIZE="$ROOT/tools/scripts/normalize-performance-screen.py"
GOLDEN="$ROOT/tests/fixtures/performance-screens.golden"

SCREENS=(
  command_perf_health_score
  command_perf_overview
  command_perf_cpu_top
  command_perf_mem_top
  command_perf_disk_usage
  command_perf_network
  command_perf_battery
  command_perf_snapshot
  command_perf_quick_watch
)

echo "SMOKE: performance screens golden"

echo "[1/4] the data layer, the normalizer and the golden are all present"
test -f "$PERF"
test -f "$NORMALIZE"
test -f "$GOLDEN"

# Renders one screen in the context the live path uses: mq-ui.sh, which owns
# surface_*, then the data layer. Nothing else — mq-performance-menu.sh sources
# exactly these two, which is why print_section is missing below rather than
# being an artefact of this harness.
render_screen() {
  local perf_file="$1" fn="$2" out="$3" err="$4"
  local rc=0
  # quick_watch refreshes every two seconds by design, so it is bounded. The
  # timeout's own status (124) is part of the golden.
  # The system commands are stubbed with fixed output. Without that the golden
  # is a photograph of one machine: it captured this laptop's battery, load and
  # process list, and CI runs Linux, where pmset and memory_pressure do not
  # exist and gawk rejects `load` as a variable name. Stubbing makes the fixture
  # portable and, more to the point, makes it measure the thing it is for —
  # drift in *rendering*, not whether `df` still works.
  timeout 6 env \
    PATH="$ROOT/tests/fixtures/perf-stubs:$PATH" \
    BASE_DIR="$ROOT" PROJECT_ROOT="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
    NO_COLOR=1 TERM=dumb COLUMNS=92 \
    bash -c '
      set -uo pipefail
      # shellcheck source=/dev/null
      source "$1/ui/terminal-ui/mq-ui.sh" 2>/dev/null || true
      # shellcheck source=/dev/null
      source "$2"
      "$3" </dev/null
    ' _ "$ROOT" "$perf_file" "$fn" >"$out" 2>"$err" || rc=$?
  return "$rc"
}

capture_all() {
  local perf_file="$1" dest="$2" fn rc so se
  : >"$dest"
  for fn in "${SCREENS[@]}"; do
    so="$(mktemp)"; se="$(mktemp)"
    rc=0
    render_screen "$perf_file" "$fn" "$so" "$se" || rc=$?
    {
      printf '===== %s =====\n' "$fn"
      printf '%s\n' "--- exit: $rc"
      printf '%s\n' '--- stdout:'
      MQ_NORMALIZE_ROOT="$ROOT" python3 "$NORMALIZE" <"$so"
      printf '%s\n' '--- stderr:'
      MQ_NORMALIZE_ROOT="$ROOT" python3 "$NORMALIZE" <"$se"
    } >>"$dest"
    rm -f "$so" "$se"
  done
}

echo "[2/4] every screen still matches the golden"
actual="$(mktemp)"
trap 'rm -f "$actual"' EXIT
capture_all "$PERF" "$actual"
if ! diff -u "$GOLDEN" "$actual"; then
  echo "" >&2
  echo "FAIL: a performance screen's output drifted from tests/fixtures/performance-screens.golden" >&2
  echo "If the change is intended, regenerate the golden and say why in the commit." >&2
  exit 1
fi
echo "  ok: ${#SCREENS[@]} screens match on stdout, stderr and exit code"

echo "[3/4] the golden still pins content, not just shape"
# A normalizer can be tightened until everything masks to the same thing and the
# comparison passes vacuously. These are labels the screens are *for*; if the
# golden stops carrying them, it has stopped being a golden.
for token in "Performance Health Score" "Performance Overview" "SIGNALS" \
             "SYSTEM STATE" "CPU cores" "Memory:" "Network" "Battery"; do
  grep -qF "$token" "$GOLDEN" || {
    echo "FAIL: the golden no longer carries '$token'; the normalizer is masking too much" >&2
    exit 1
  }
done
echo "  ok: the golden carries the labels the screens render"

echo "[4/4] planted output drift is detected"
# Proven by rendering against a copy of the data layer with one label changed.
# A golden that cannot fail is a file, not a gate.
drifted="$(mktemp -d)"
sed 's/Performance Overview/Performance Overviev/' "$PERF" >"$drifted/performance.sh"
planted="$(mktemp)"
capture_all "$drifted/performance.sh" "$planted"
if diff -q "$GOLDEN" "$planted" >/dev/null; then
  echo "FAIL: a planted label change did not show up against the golden" >&2
  rm -rf "$drifted" "$planted"
  exit 1
fi
rm -rf "$drifted" "$planted"
echo "  ok: a one-character label change is reported"

echo "OK: performance screens golden smoke test passed"
