#!/usr/bin/env bash
set -euo pipefail

# The Release menu carried twelve numbered choices and printed two of them out
# of position: 12 sat inside CHECKS between 4 and 5, and 11 sat inside SHIP
# between 6 and 7. Anyone picking by position rather than by label got the wrong
# command, and on this menu the wrong command ships a release.
#
# These checks pin behaviour rather than layout: that every action is still
# reachable, that the numbers a panel prints are the numbers the case arms
# answer, and that the front menu stays within the ROADMAP P2 limit. Option
# numbers and section names are free to change; what a menu can do is not.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-release-menu.sh"

echo "SMOKE: release menu"

echo "[1/6] the menu file exists and parses"
test -f "$MENU"
bash -n "$MENU"

echo "[2/6] every action reachable before the regrouping still has a route"
# Listed as the handler each choice must reach, not as menu text. Anything
# dropped from the front menu has to reappear in a submenu; this is the check
# that a regrouping did not quietly become a deletion.
#
# Searched inside the menu loops only. Every one of these handlers is *defined*
# in this same file, so a whole-file match finds `init_release_files() {` and
# reports the action reachable after its last case arm has been deleted — which
# is exactly what happened when this step was first written that way. A
# definition is not a route; only a call from a loop is.
missing=""
menu_code="$(python3 - "$MENU" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for name in ("release_menu_loop", "release_changelog_menu_loop",
             "release_setup_menu_loop"):
    if f"{name}()" in text:
        block = text.split(f"{name}()")[1].split("\n}")[0]
        print(re.sub(r'(?m)^\s*#.*$', '', block))
PY
)"
while read -r target; do
  [[ -z "$target" ]] && continue
  printf '%s\n' "$menu_code" | grep -qE "(^|[^A-Za-z0-9_])${target//./\\.}([^A-Za-z0-9_]|$)" \
    || missing+=" $target"
done <<'TARGETS'
show_release_status
choose_release_repo
init_release_files
run_release_dry
run_release_live
create_github_release_only
show_changelog
show_tags
open_changelog_in_editor
open_release_script_in_editor
auto_release
run_repo_signal_check
TARGETS
if [[ -n "$missing" ]]; then
  echo "FAIL: no route left to:$missing" >&2
  exit 1
fi
echo "  ok: all 12 original actions still reachable"

echo "[3/6] the numbers printed are the numbers answered"
# Compares the two lists, so it fails on a gap, a duplicate, an option with no
# arm, or a row printed out of order — which is the defect this slice fixes.
#
# Shell expansions are stripped first. `"${C_WARN}12. Repo Signal Check${C_RESET}"`
# is a row like any other, and a pattern anchored to the opening quote skips it.
python3 - "$MENU" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
panel = re.sub(r'\$\{[^}]*\}', '', text.split("print_release_menu() {")[1].split("\n}")[0])
body = text.split("release_menu_loop() {")[1].split("\n}")[0]

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

echo "[4/6] the front menu is within the operator-choice limit"
count="$(python3 - "$MENU" <<'PY'
import re, sys
panel = open(sys.argv[1], encoding="utf-8").read()
panel = re.sub(r'\$\{[^}]*\}', '', panel.split("print_release_menu() {")[1].split("\n}")[0])
print(len(re.findall(r'"(\d+)\.\s', panel)))
PY
)"
if [[ -z "$count" || "$count" == "0" ]]; then
  echo "FAIL: no numbered rows found in the panel" >&2
  exit 1
fi
if (( count > 10 )); then
  echo "FAIL: the release menu offers $count operator choices, limit is 10" >&2
  exit 1
fi
echo "  ok: $count numbered choices on the front menu"

echo "[5/6] each submenu answers every row it prints"
python3 - "$MENU" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
failed = False
for name in ("release_changelog_menu_loop", "release_setup_menu_loop"):
    if f"{name}()" not in text:
        print(f"FAIL: {name} is missing", file=sys.stderr)
        failed = True
        continue
    block = re.sub(r'\$\{[^}]*\}', '', text.split(f"{name}()")[1].split("\n}")[0])
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

echo "[6/6] each grouped row actually opens its submenu"
# Steps 2-5 read the file. This runs the menu, because a case arm that names a
# function proves nothing about whether the function opens.
#
# read_menu_choice is stubbed to read stdin: it returns early without reading
# when there is no interactive tty, so a piped menu draws once and exits — which
# looks exactly like a broken route when it is a broken test. The stub replaces
# input handling only; the routing under test is the real one.
# Bounded and reading from /dev/null once the piped keystrokes run out: a menu
# that reaches the end of its input goes back to waiting, and nothing is left to
# tell it to leave.
#
# Only the two navigation rows are driven. Every other arm on this menu either
# ships a release, writes to a repo, or opens an editor.
routes="$(timeout 60 bash -c '
  export MACOS_SCRIPTS_HOME="'"$ROOT"'" BASE_DIR="'"$ROOT"'" MQ_NO_TUI=1
  source "'"$ROOT"'/terminal/launchers/mqlaunch.sh" >/dev/null 2>&1 || true
  read_menu_choice() { IFS= read -r REPLY || return 1; return 0; }
  print_header() { :; }
  pause_enter() { :; }
  for choice in 8 9; do
    printf "%s\nb\nb\n" "$choice" \
      | release_menu_loop 2>/dev/null \
      | sed "s/\x1b\[[0-9;]*m//g" \
      | grep -oE "^┌─ [A-Za-z]+" | sed -n 2p
  done
' </dev/null || true)"
for expected in Changelog Setup; do
  printf '%s\n' "$routes" | grep -q "┌─ $expected" || {
    echo "FAIL: no row opened the $expected submenu" >&2
    printf 'saw:\n%s\n' "$routes" >&2
    exit 1
  }
done
echo "  ok: Changelog and Setup both open"

echo "OK: release menu smoke test passed"
