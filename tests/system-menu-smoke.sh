#!/usr/bin/env bash
set -euo pipefail

# The System menu carried sixteen operator choices, two of which duplicated the
# network menu it could not otherwise reach, and its numbering ran 1-13, 16, 17,
# 14, 15 because MAINTENANCE was printed above NAVIGATION.
#
# These checks pin behaviour rather than layout: that every action is still
# reachable, that the numbers a panel prints are the numbers the case arms
# answer, and that the front menu stays within the ROADMAP P2 limit. Option
# numbers and section names are free to change; what a menu can do is not.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-system-menu.sh"

echo "SMOKE: system menu"

echo "[1/7] the menu file exists and parses"
test -f "$MENU"
bash -n "$MENU"

echo "[2/7] every action reachable before the regrouping still has a route"
# Listed as the handler or command each choice must reach, not as menu text.
# Anything dropped from the front menu has to reappear in a submenu; this is the
# check that a regrouping did not quietly become a deletion.
# Matched on a word boundary, in code only. A plain `grep -F` passed when
# lock_screen was renamed to _gone_lock_screen, because the old name survived as
# a substring of the new one — the check reported every action reachable while
# one of them had no handler at all. Comments are blanked for the same reason: a
# function named in a comment is not a route to it.
missing=""
menu_code="$(sed 's/^[[:space:]]*#.*//' "$MENU")"
while read -r target; do
  [[ -z "$target" ]] && continue
  printf '%s\n' "$menu_code" | grep -qE "(^|[^A-Za-z0-9_])${target//./\\.}([^A-Za-z0-9_]|$)" \
    || missing+=" $target"
done <<'TARGETS'
open_performance_menu
open_net_menu
mqlaunch" reap
mqlaunch" doctor
mqlaunch" self-check
run_debug_bundle
system_check
vault-scan.sh
brew-check.sh
cleanup.sh
lock_screen
sleep_display
restart_finder
show_date_time
open_base_dir
open_repo_browser
TARGETS
if [[ -n "$missing" ]]; then
  echo "FAIL: no route left to:$missing" >&2
  exit 1
fi
echo "  ok: all 16 original actions still reachable"

echo "[3/7] the network row opens the network menu instead of copying it"
# show_network_info and the ghost route are options 1 and 8 of the network menu.
# Duplicating them here meant two ways to reach two functions and no way to
# reach the other seven.
if grep -qE '^\s+[0-9]+\) show_network_info' "$MENU"; then
  echo "FAIL: the system menu still copies show_network_info" >&2
  exit 1
fi
grep -q "open_net_menu" "$MENU" || {
  echo "FAIL: the system menu cannot reach the network menu" >&2
  exit 1
}
echo "  ok: one row, and it leads to all nine network choices"

echo "[4/7] the numbers printed are the numbers answered"
# The old panel printed 16 and 17 above 14 and 15. A reader picking by position
# rather than by label got the wrong command. This compares the two lists, so it
# fails on a gap, a duplicate, or an option with no arm.
python3 - "$MENU" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
# Both blocks are bounded to their own function. Splitting the file at
# open_system_menu() swept the submenus' rows into the front panel, because they
# are defined above it — the numbers were fine and the check was wrong.
panel = text.split("render_system_panel() {")[1].split("\n}")[0]
body = text.split("open_system_menu() {")[1].split("\n}")[0]

printed = [int(n) for n in re.findall(r'"(\d+)\.\s', panel)]
answered = sorted({int(n) for n in re.findall(r'^\s+(\d+)\)', body, re.M)})

if printed != sorted(printed):
    print(f"FAIL: the panel prints its numbers out of order: {printed}", file=sys.stderr)
    sys.exit(1)
if len(set(printed)) != len(printed):
    print(f"FAIL: a number is printed twice: {printed}", file=sys.stderr)
    sys.exit(1)
if printed != list(range(1, len(printed) + 1)):
    print(f"FAIL: the numbering has a gap: {printed}", file=sys.stderr)
    sys.exit(1)
if sorted(printed) != answered:
    print(f"FAIL: printed {printed} but the case answers {answered}", file=sys.stderr)
    sys.exit(1)
print(f"  ok: 1-{len(printed)}, in order, each with an arm")
PY

echo "[5/7] the front menu is within the operator-choice limit"
# Counted from the numbered rows the panel prints, which is what the ROADMAP
# limit is about — what an operator is asked to choose between on one screen.
#
# Not taken from inventory-command-surfaces.py: its MENU_OPENER pattern is
# `^(?:open_.*_menu|.*_menu(?:_main|_loop)?)$`, so a submenu opener counts as
# navigation when its function happens to be called *_menu_loop and as a choice
# when it is not. `system_checks_menu_loop` matches, `hal_menu_memory_loop` does
# not, and the same menu shape scores differently depending on a function name.
# Reported separately; this step reads the panel instead.
count="$(python3 - "$MENU" <<'PY'
import re, sys
panel = open(sys.argv[1], encoding="utf-8").read()
panel = panel.split("render_system_panel() {")[1].split("\n}")[0]
print(len(re.findall(r'"(\d+)\.\s', panel)))
PY
)"
if [[ -z "$count" || "$count" == "0" ]]; then
  echo "FAIL: no numbered rows found in the panel" >&2
  exit 1
fi
if (( count > 10 )); then
  echo "FAIL: the system menu offers $count operator choices, limit is 10" >&2
  exit 1
fi
echo "  ok: $count numbered choices on the front menu"

echo "[6/7] each submenu answers every row it prints"
python3 - "$MENU" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
failed = False
for name in ("system_checks_menu_loop", "system_maintenance_menu_loop",
             "system_desktop_menu_loop"):
    if f"{name}()" not in text:
        print(f"FAIL: {name} is missing", file=sys.stderr)
        failed = True
        continue
    block = text.split(f"{name}()")[1].split("\n}")[0]
    printed = sorted({int(n) for n in re.findall(r'"(\d+)\.\s', block)})
    answered = sorted({int(n) for n in re.findall(r'^\s+(\d+)\)', block, re.M)})
    if printed != answered:
        print(f"FAIL: {name} prints {printed} but answers {answered}", file=sys.stderr)
        failed = True
    elif printed != list(range(1, len(printed) + 1)):
        print(f"FAIL: {name} numbering has a gap: {printed}", file=sys.stderr)
        failed = True
sys.exit(1 if failed else 0)
PY
echo "  ok: submenu rows and arms agree"

echo "[7/7] each grouped row actually opens its submenu"
# Steps 2-6 read the file. This runs the menu, because a case arm that names a
# function proves nothing about whether the function opens.
#
# read_menu_choice is stubbed to read stdin: it returns early without reading
# when there is no interactive tty (mq_has_interactive_tty), so a piped menu
# draws once and exits — which looked exactly like a broken route when it was a
# broken test. The stub replaces input handling only; the routing under test is
# the real one.
# Each run is bounded and reads from /dev/null once the script's own input runs
# out. Without both, this step hung the whole suite: a menu that reaches the end
# of the piped keystrokes goes back to waiting, and there is nothing left to
# tell it to leave. It passed in 1.8s when run by hand — with a terminal still
# attached — and blocked forever under test-all.sh, which is the difference
# between "the test works" and "the test works where it runs".
routes="$(timeout 60 bash -c '
  export MACOS_SCRIPTS_HOME="'"$ROOT"'" BASE_DIR="'"$ROOT"'" MQ_NO_TUI=1
  source "'"$ROOT"'/terminal/launchers/mqlaunch.sh" >/dev/null 2>&1 || true
# Reads menu choice from user input or stdin.
  read_menu_choice() { IFS= read -r REPLY || return 1; return 0; }
# Prints header.
  print_header() { :; }
# Pauses until Enter is pressed.
  pause_enter() { :; }
  for choice in 2 5 7 8; do
    printf "%s\nb\nb\n" "$choice" \
      | open_system_menu 2>/dev/null \
      | sed "s/\x1b\[[0-9;]*m//g" \
      | grep -oE "^┌─ [A-Za-z]+" | sed -n 2p
  done
' </dev/null || true)"
for expected in Network Checks Maintenance Desktop; do
  printf '%s\n' "$routes" | grep -q "┌─ $expected" || {
    echo "FAIL: no row opened the $expected submenu" >&2
    printf 'saw:\n%s\n' "$routes" >&2
    exit 1
  }
done
echo "  ok: Network, Checks, Maintenance and Desktop all open"

echo "OK: system menu smoke test passed"
