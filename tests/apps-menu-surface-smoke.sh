#!/usr/bin/env bash
set -euo pipefail

# The apps menu carried fifteen choices in one loop. It was already grouped
# visually — APPS, FOLDERS, QUICK ACTIONS — but headings do not shorten a menu;
# an operator still reads fifteen rows before choosing.
#
# The four folders and the two external shortcuts moved behind
# "10. Folders and shortcuts". They group because none of them opens an app:
# each takes you somewhere rather than launching something on this machine.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-apps-menu.sh"

echo "SMOKE: apps menu surface"

echo "[1/4] syntax check"
bash -n "$MENU"

check_loop() {
  local label="$1" panel="$2" loop="$3" limit="$4"

  local drawn dispatched
  drawn="$(sed -n "/^${panel}()/,/^}/p" "$MENU" |
    grep -oE '"[0-9]+\. [^"]+"' | grep -oE '^"[0-9]+' | tr -d '"' | sort -u)"
  dispatched="$(sed -n "/^${loop}()/,/^}/p" "$MENU" |
    grep -oE '^[[:space:]]+[0-9]+[|)]' | grep -oE '[0-9]+' | sort -u)"

  [[ "$drawn" == "$dispatched" ]] || {
    echo "  $label: panel and loop disagree" >&2
    echo "    drawn:      $(echo "$drawn" | sort -n | tr '\n' ' ')" >&2
    echo "    dispatched: $(echo "$dispatched" | sort -n | tr '\n' ' ')" >&2
    return 1
  }

  local count
  count="$(echo "$drawn" | wc -l | tr -d ' ')"
  [[ "$count" -le "$limit" ]] || {
    echo "  $label: $count choices, target $limit" >&2
    return 1
  }

  # Contiguous 1..N — a hole means a row was removed without its arm, or vice
  # versa, which is how the git menu ended up answering a 9 it never drew.
  [[ "$(echo "$drawn" | sort -n | tr '\n' ' ')" == "$(seq 1 "$count" | tr '\n' ' ')" ]] || {
    echo "  $label: numbering is not contiguous" >&2
    return 1
  }
}

echo "[2/4] front panel: drawn == dispatched, within ten, contiguous"
check_loop "front panel" render_apps_panel open_apps_menu 10

echo "[3/4] submenu: drawn == dispatched, within ten, contiguous"
check_loop "submenu" render_apps_more_panel open_apps_more_menu 10

echo "[4/4] the submenu is reachable from the front panel"
sed -n '/^open_apps_menu()/,/^}/p' "$MENU" | grep -q 'open_apps_more_menu' || {
  echo "  nothing on the front panel opens the submenu" >&2
  exit 1
}

echo "PASS: apps menu surface"
