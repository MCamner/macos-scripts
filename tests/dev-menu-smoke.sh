#!/usr/bin/env bash
set -euo pipefail

# The Dev menu carried sixteen numbered choices in five sections, three of which
# were doors to other menus (Network, Themes, Tools) sitting between actions.
#
# These checks pin behaviour rather than layout: that every action is still
# reachable, that the numbers a panel prints are the numbers the case arms
# answer, and that the front menu stays within the ROADMAP P2 limit. Option
# numbers and section names are free to change; what a menu can do is not.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-dev-menu.sh"

echo "SMOKE: dev menu"

echo "[1/6] the menu file exists and parses"
test -f "$MENU"
bash -n "$MENU"

echo "[2/6] every action reachable before the regrouping still has a route"
# Listed as the handler or script each choice must reach, not as menu text.
# Anything dropped from the front menu has to reappear in a submenu; this is the
# check that a regrouping did not quietly become a deletion.
# Matched on a word boundary, in code only — a function named in a comment is
# not a route to it, and a plain substring match passes when a handler is
# renamed to something that still contains the old name.
missing=""
menu_code="$(sed 's/^[[:space:]]*#.*//' "$MENU")"
while read -r target; do
  [[ -z "$target" ]] && continue
  printf '%s\n' "$menu_code" | grep -qE "(^|[^A-Za-z0-9_])${target//./\\.}([^A-Za-z0-9_]|$)" \
    || missing+=" $target"
done <<'TARGETS'
open_ai_prompts_folder
show_prompt_files
edit_mqlaunch
backup_prompts
backup_mqlaunch
open_base_dir
open_launcher_folder
hal-terminal-guide.sh
net_menu_loop
open_themes_menu
open_tools_menu
mq-create-repo.sh
mq-repo-signal-folder-check.sh
env-snap.sh
docfunc
excalidraw.sh
b2_tui
TARGETS
if [[ -n "$missing" ]]; then
  echo "FAIL: no route left to:$missing" >&2
  exit 1
fi
echo "  ok: all 17 original actions still reachable"

echo "[3/6] the numbers printed are the numbers answered"
# Compares the two lists, so it fails on a gap, a duplicate, or an option with
# no arm.
#
# Shell expansions are stripped from the panel before the numbers are read. One
# row was written `"${C_WARN}13. Repo Signal Folder Check${C_RESET}"`, and a
# pattern anchored to the opening quote skipped it — which is how a survey of
# this menu came to report 13 as an option that existed in code and was never
# printed. The menu was fine; the measurement was anchored to the wrong thing.
python3 - "$MENU" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
panel = text.split("print_dev_menu() {")[1].split("\n}")[0]
panel = re.sub(r'\$\{[^}]*\}', '', panel)
body = text.split("handle_dev_menu_choice() {")[1].split("\n}")[0]

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
# Counted from the numbered rows the panel prints, which is what the ROADMAP
# limit is about — what an operator is asked to choose between on one screen.
count="$(python3 - "$MENU" <<'PY'
import re, sys
panel = open(sys.argv[1], encoding="utf-8").read()
panel = panel.split("print_dev_menu() {")[1].split("\n}")[0]
panel = re.sub(r'\$\{[^}]*\}', '', panel)
print(len(re.findall(r'"(\d+)\.\s', panel)))
PY
)"
if [[ -z "$count" || "$count" == "0" ]]; then
  echo "FAIL: no numbered rows found in the panel" >&2
  exit 1
fi
if (( count > 10 )); then
  echo "FAIL: the dev menu offers $count operator choices, limit is 10" >&2
  exit 1
fi
echo "  ok: $count numbered choices on the front menu"

echo "[5/6] each submenu answers every row it prints"
python3 - "$MENU" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
failed = False
for name in ("dev_prompts_menu_loop", "dev_folders_menu_loop", "dev_menus_menu_loop"):
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
routes="$(timeout 60 bash -c '
  export MACOS_SCRIPTS_HOME="'"$ROOT"'" BASE_DIR="'"$ROOT"'" MQ_NO_TUI=1
  source "'"$ROOT"'/terminal/launchers/mqlaunch.sh" >/dev/null 2>&1 || true
  read_menu_choice() { IFS= read -r REPLY || return 1; return 0; }
  read_main_choice() { IFS= read -r choice || return 1; return 0; }
  print_header() { :; }
  pause_enter() { :; }
  for choice in 1 4 10; do
    printf "%s\nb\nb\n" "$choice" \
      | open_dev_menu 2>/dev/null \
      | sed "s/\x1b\[[0-9;]*m//g" \
      | grep -oE "^┌─ [A-Za-z]+" | sed -n 2p
  done
' </dev/null || true)"
for expected in Prompts Folders Menus; do
  printf '%s\n' "$routes" | grep -q "┌─ $expected" || {
    echo "FAIL: no row opened the $expected submenu" >&2
    printf 'saw:\n%s\n' "$routes" >&2
    exit 1
  }
done
echo "  ok: Prompts, Folders and Menus all open"

echo "OK: dev menu smoke test passed"
