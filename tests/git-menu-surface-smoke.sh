#!/usr/bin/env bash
set -euo pipefail

# The git menu dispatched a choice it never drew. d8ba588 removed option 9
# ("Recent git log") from the panel and said "b/9 both map to Back", but only
# the panel row went — `9) show_log` stayed in the loop. So the menu showed
# 1-8, p, 10-12 and quietly answered 9, and the numbering carried a hole for
# anyone reading it.
#
# The general rule is what this test holds: every numbered choice the panel
# draws must dispatch, and every numbered arm the loop dispatches must be
# drawn. A menu that answers what it does not advertise is the same class of
# defect as one that advertises what it cannot run.
#
# show_log itself is not dead. `mq-git-menu.sh log` reaches it and usage()
# documents it; only the menu arm was meant to go.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-git-menu.sh"

echo "SMOKE: git menu surface"

echo "[1/6] syntax check"
bash -n "$MENU"

# Numbers the panel draws, from the surface rows only.
drawn="$(sed -n '/^print_git_menu()/,/^}/p' "$MENU" |
  grep -oE '"[0-9]+\. [^"]+"' | grep -oE '^"[0-9]+' | tr -d '"' | sort -n -u)"

# Numbers the loop answers, from the case arms only. The trailing class covers
# `10)` and `9|p|P)` alike — a number that shares its arm with a letter is still
# a number the menu answers.
dispatched="$(sed -n '/^git_menu_loop()/,/^}/p' "$MENU" |
  grep -oE '^[[:space:]]+[0-9]+[|)]' | grep -oE '[0-9]+' | sort -n -u)"

# comm compares as text, so both sides need lexicographic order — a numeric
# sort makes it read 10 as smaller than 2 and report differences that are not
# there. Kept separate from the numeric lists above, which the messages and the
# contiguity check below want in human order.
drawn_lex="$(echo "$drawn" | sort -u)"
dispatched_lex="$(echo "$dispatched" | sort -u)"

echo "[2/6] every drawn choice dispatches"
missing_arm="$(comm -23 <(echo "$drawn_lex") <(echo "$dispatched_lex") | tr '\n' ' ')"
[[ -z "${missing_arm// /}" ]] || {
  echo "  drawn but not dispatched: $missing_arm" >&2
  exit 1
}

echo "[3/6] every dispatched choice is drawn"
missing_row="$(comm -13 <(echo "$drawn_lex") <(echo "$dispatched_lex") | tr '\n' ' ')"
[[ -z "${missing_row// /}" ]] || {
  echo "  dispatched but never drawn: $missing_row" >&2
  echo "  a menu must not answer a choice it does not advertise" >&2
  exit 1
}

echo "[4/6] the numbering has no holes"
# A hole is how the old bug looked to a reader: the panel jumped 8 -> 10.
expected="$(seq 1 "$(echo "$drawn" | tail -1)")"
[[ "$drawn" == "$expected" ]] || {
  echo "  drawn: $(echo "$drawn" | tr '\n' ' ')" >&2
  echo "  expected a contiguous 1..N" >&2
  exit 1
}

echo "[5/6] the top level stays within ten operator choices"
# Back and quit are excluded, as the roadmap target says. `p` is counted: it is
# a choice an operator makes, whatever character it is bound to.
count="$(echo "$drawn" | wc -l | tr -d ' ')"
letters="$(sed -n '/^print_git_menu()/,/^}/p' "$MENU" |
  grep -oE '"[a-z]\. [^"]+"' | grep -vcE '"[bx]\.' || true)"
total=$(( count + letters ))
[[ "$total" -le 10 ]] || {
  echo "  $total operator choices ($count numbered, $letters lettered), target 10" >&2
  exit 1
}

echo "[6/6] merge keeps its p binding as well as its number"
# `p|P` predates this change. Rebinding a Class C mutating action would break
# muscle memory for no gain, so it stays reachable both ways.
sed -n '/^git_menu_loop()/,/^}/p' "$MENU" | grep -q 'p|P)' || {
  echo "  p is no longer bound to merge_pull_request" >&2
  exit 1
}

echo "PASS: git menu surface"
