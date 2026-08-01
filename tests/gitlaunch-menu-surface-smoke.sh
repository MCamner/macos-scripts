#!/usr/bin/env bash
set -euo pipefail

# gitlaunch.sh is the menu `mqlaunch git` actually opens — not mq-git-menu.sh.
# It carried eleven operator choices and nothing reported it, because the
# inventory read only terminal/menus/*.sh and only single-line case arms, and
# this file is outside that directory and written in the multi-line form.
#
# Open repo, Dev mode and Switch repo moved behind "9. Repo and workspace".
# None of them touches git state, which is what the other rows are for.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/launchers/gitlaunch.sh"

echo "SMOKE: gitlaunch menu surface"

echo "[1/5] syntax check"
bash -n "$MENU"

drawn="$(sed -n '/^function render_menu()/,/^}/p' "$MENU" |
  grep -oE '"[0-9]+\. [^"]+"' | grep -oE '^"[0-9]+' | tr -d '"' | sort -n -u)"
count="$(echo "$drawn" | wc -l | tr -d ' ')"

echo "[2/5] the front panel stays within ten choices"
[[ "$count" -le 10 ]] || {
  echo "  $count choices, target 10" >&2
  exit 1
}

echo "[3/5] the numbering is contiguous"
[[ "$(echo "$drawn" | tr '\n' ' ')" == "$(seq 1 "$count" | tr '\n' ' ')" ]] || {
  echo "  drawn: $(echo "$drawn" | tr '\n' ' ')" >&2
  exit 1
}

echo "[4/5] every drawn choice has an arm in the main loop"
arms="$(sed -n '/^  case \$choice in/,/^  esac/p' "$MENU" |
  grep -oE '^[[:space:]]+[0-9]+(\|[A-Za-z])*\)' | grep -oE '[0-9]+' | sort -n -u)"
[[ "$drawn" == "$arms" ]] || {
  echo "  drawn: $(echo "$drawn" | tr '\n' ' ')" >&2
  echo "  arms:  $(echo "$arms" | tr '\n' ' ')" >&2
  exit 1
}

echo "[5/5] m and p still reach merge, and the prompt still says so"
# Both predate the numbers. An operator who has typed `m` for a year should not
# discover it stopped working because the row grew a digit.
sed -n '/^  case \$choice in/,/^  esac/p' "$MENU" | grep -qE '^[[:space:]]+[0-9]+\|m\|M\)' || {
  echo "  m is no longer bound to safe merge" >&2
  exit 1
}
sed -n '/^  case \$choice in/,/^  esac/p' "$MENU" | grep -qE '^[[:space:]]+[0-9]+\|p\|P\)' || {
  echo "  p is no longer bound to PR merge" >&2
  exit 1
}
grep -q 'press 1-9, m, p or b' "$MENU" || {
  echo "  the prompt hint no longer matches the keys the menu accepts" >&2
  exit 1
}

echo "PASS: gitlaunch menu surface"
