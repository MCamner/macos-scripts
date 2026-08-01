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

echo "[6/6] a repo argument that resolves to nothing fails instead of opening"
# gitlaunch takes a repo path, not a subcommand. `gitlaunch status` reads like
# one and is forwarded as a path — the registry's declared contract for git is
# unknown_subcommand: forward — so it printed "Path not found: status" and then
# dropped into the menu with no repo and exit status 0.
#
# That mattered once bin/gitlaunch put the command on PATH: a wrapper that
# always succeeds is worse than none for anything scripted. detect_repo did
# `set_repo "$REQUESTED_REPO" || REPO=""`, which turns an explicit argument the
# operator got wrong into a silent fall-through.
#
# Driven for real, in zsh, because this file is zsh and the failure is in
# control flow rather than in text.
out="$(cd /tmp && printf '2\n' | timeout 30 zsh "$MENU" /nonexistent/repo 2>&1)" && status=0 || status=$?
if [[ "$status" -eq 0 ]]; then
  printf '  a bad repo argument exited 0\n%s\n' "$out" >&2
  exit 1
fi
printf '%s' "$out" | grep -q 'not found' || {
  printf '  a bad repo argument did not say what was wrong:\n%s\n' "$out" >&2
  exit 1
}
printf '%s' "$out" | grep -qi 'repo path' || {
  printf '  the message does not say the argument is a repo path:\n%s\n' "$out" >&2
  exit 1
}
printf '%s' "$out" | grep -q '1\. Go to default repo' && {
  echo "  it opened the menu anyway after rejecting the argument" >&2
  exit 1
}
echo "  ok: it reports the argument and exits non-zero"

echo "PASS: gitlaunch menu surface"
