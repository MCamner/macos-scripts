#!/usr/bin/env bash
set -euo pipefail

# #137 removed the "run anything you type" fallback from the HAL menu. The
# Performance menu kept it: `*) /bin/zsh -lc "$choice"`, so a typo at the
# Performance prompt was executed, and unlike HAL it was not even followed by
# `|| true`.
#
# The rule these checks pin is one sentence: input the menu does not recognise
# is reported, not executed. Shell stays reachable behind an explicit `!`, the
# same prefix the main prompt already advertises.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERF="$ROOT/terminal/menus/mq-performance-menu.sh"

echo "SMOKE: menu shell guard"

echo "[1/4] no menu runs an unrecognised choice through a shell"
# Static and repo-wide, so the next menu inherits the rule instead of repeating
# the defect. Comment lines are blanked first: mq-hal-menu.sh documents the
# fallback it removed by quoting it, and a gate that trips on its own
# explanation is one the next person deletes rather than reads.
#
# This matches the direct form only — `-lc "$choice"`, `-c "$choice"`,
# `eval "$choice"`. Copying the choice into another variable first would pass
# it, which is why step 2 drives the menu for real rather than trusting this.
offenders=""
for menu in "$ROOT"/terminal/menus/*.sh; do
  if sed 's/^[[:space:]]*#.*//' "$menu" \
    | grep -qE '(-lc?|eval)[[:space:]]+"\$\{?choice\}?"'; then
    offenders+=" ${menu##*/}"
  fi
done
if [[ -n "$offenders" ]]; then
  echo "FAIL: menu input reaches a shell verbatim in:$offenders" >&2
  exit 1
fi
echo "  ok: no menu executes what it failed to recognise"

echo "[2/4] a typo at the Performance prompt stays a typo"
# The menu is run, not read. `read_main_choice` is not defined when the file is
# executed on its own, so the loop takes its own `read` fallback — which is the
# branch that held the defect.
export MACOS_SCRIPTS_HOME="$ROOT"
probe="$(mktemp -u)"
printf 'touch %s\nb\n' "$probe" | timeout 60 bash "$PERF" >/dev/null 2>&1 || true
if [[ -e "$probe" ]]; then
  rm -f "$probe"
  echo "FAIL: unrecognised menu input was executed as a shell command" >&2
  exit 1
fi
echo "  ok: the command was reported, not run"

echo "[3/4] an explicit ! prefix still reaches the shell"
# The guard is only worth having while the deliberate route works, or the next
# person removes the prefix rather than the risk.
printf '! touch %s\nb\n' "$probe" | timeout 60 bash "$PERF" >/dev/null 2>&1 || true
if [[ ! -e "$probe" ]]; then
  echo "FAIL: '! <command>' did not run the command" >&2
  exit 1
fi
rm -f "$probe"
echo "  ok: ! runs what follows it"

echo "[4/4] the menu leaves when its input runs out"
# `read -r choice` without `|| return` meant EOF set choice to empty and looped:
# the panel redrew as fast as it could render, forever, with no way in to stop
# it.
#
# tests/menu-eof-smoke.sh already covers `mqlaunch perf` and passed, because on
# that path `read_main_choice` is defined and its call site does act on the EOF
# return. The defect was in the fallback the file takes when it is executed on
# its own — a supported entry point (the file ends by calling the menu when it
# is not sourced) that no test drove. Found by this test hanging, not by reading
# the code.
start="$(date +%s)"
printf '\n' | timeout 30 bash "$PERF" >/dev/null 2>&1 || true
elapsed=$(( $(date +%s) - start ))
if (( elapsed >= 30 )); then
  echo "FAIL: the menu spun for ${elapsed}s on end-of-input instead of leaving" >&2
  exit 1
fi
echo "  ok: end-of-input ends the menu (${elapsed}s)"

echo "OK: menu shell guard smoke test passed"
