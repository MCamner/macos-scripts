#!/usr/bin/env bash
# Proves terminal/themes/mq-theme-manager.sh runs from a checkout that is not
# $HOME/macos-scripts.
#
# It read `${HOME}/macos-scripts` outright, where tools/scripts/doctor.sh and
# tools/scripts/scan.sh both read `${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}`.
# mq-zsh-theme-switcher.sh had the identical line and was fixed in #172; this is
# the sibling that was left, deliberately, as its own change.
#
# Measured before the fix, with HOME pointed away from the checkout:
#
#   list      exit 0
#   current   exit 0
#   reset     exit 0
#   preview   exit 1   line 140: /tmp/nohome/macos-scripts/ui/terminal-ui/mq-ui.sh
#
# Only `preview` reads BASE_DIR, through UI_LIB, which is why the defect stayed
# invisible: four of the five verbs work anywhere, and on a developer machine
# $HOME/macos-scripts exists so the fifth does too.
#
# THEME_FILE is not part of this. `${HOME}/.mq-theme` is user state, the same
# class as ~/.zshrc, and belongs in $HOME wherever the checkout lives.
#
# Every run below is given its own HOME. The script writes and deletes
# ~/.mq-theme, and the suite must not touch the theme of the machine running it
# — a probe against a real HOME already applied a theme once during this work.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANAGER="$ROOT/terminal/themes/mq-theme-manager.sh"

echo "SMOKE: mq-theme-manager.sh runs outside \$HOME/macos-scripts"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A checkout somewhere the default would never look. Only `ui/` is needed: it is
# all BASE_DIR resolves to in this script.
TREE="$WORK/elsewhere"
mkdir -p "$TREE"
ln -s "$ROOT/ui" "$TREE/ui"

# Records the real theme file so the last step can prove it was not touched.
REAL_THEME="$HOME/.mq-theme"
real_before="(absent)"
[[ -f "$REAL_THEME" ]] && real_before="$(shasum "$REAL_THEME" | cut -d' ' -f1)"

echo "[1/5] files exist"
test -f "$MANAGER"
test -d "$TREE/ui"

# Runs the manager with an isolated HOME. $2 is the HOME to use; the checkout
# location is passed separately so a step can leave it unset on purpose.
run_manager() {
  local home="$1" base="$2"
  shift 2
  local st=0
  if [[ -n "$base" ]]; then
    HOME="$home" MACOS_SCRIPTS_HOME="$base" \
      timeout 30 bash "$MANAGER" "$@" >"$WORK/out" 2>"$WORK/err" || st=$?
  else
    env -u MACOS_SCRIPTS_HOME HOME="$home" \
      timeout 30 bash "$MANAGER" "$@" >"$WORK/out" 2>"$WORK/err" || st=$?
  fi
  return "$st"
}

echo "[2/5] preview renders from a checkout the default would never find"
# The one verb that reads BASE_DIR. Before the fix this died sourcing a UI
# library under $HOME/macos-scripts.
home_a="$WORK/home-a"
mkdir -p "$home_a"
st=0
run_manager "$home_a" "$TREE" preview green || st=$?
if [[ "$st" -ne 0 ]]; then
  echo "FAIL: preview exited $st from a non-default checkout" >&2
  cat "$WORK/err" >&2
  exit 1
fi
# Rendered, not merely silent: the preview panel names the theme it drew.
grep -qF 'Theme: green' "$WORK/out"
grep -qF 'THEME PREVIEW' "$WORK/out"
echo "  ok: preview runs and draws its panel"

echo "[3/5] the other four verbs work there too, and write only inside their HOME"
home_b="$WORK/home-b"
mkdir -p "$home_b"
for verb in list current; do
  st=0
  run_manager "$home_b" "$TREE" "$verb" || st=$?
  [[ "$st" -eq 0 ]] || { echo "FAIL: $verb exited $st" >&2; cat "$WORK/err" >&2; exit 1; }
done
run_manager "$home_b" "$TREE" apply amber
if [[ ! -f "$home_b/.mq-theme" ]]; then
  echo "FAIL: apply did not write .mq-theme inside the isolated HOME" >&2
  exit 1
fi
grep -qF 'amber' "$home_b/.mq-theme"
run_manager "$home_b" "$TREE" current
grep -qF 'amber' "$WORK/out"
run_manager "$home_b" "$TREE" reset
if [[ -f "$home_b/.mq-theme" ]]; then
  echo "FAIL: reset left .mq-theme behind" >&2
  exit 1
fi
echo "  ok: list, current, apply and reset all act inside the isolated HOME"

echo "[4/5] the gate can fail — without the override, the default is still used"
# The before-state, reproduced rather than remembered. With MACOS_SCRIPTS_HOME
# unset and a HOME holding no macos-scripts, preview must fail: that is exactly
# what every checkout outside the default path saw.
home_c="$WORK/home-c"
mkdir -p "$home_c"
st=0
run_manager "$home_c" "" preview green || st=$?
if [[ "$st" -eq 0 ]]; then
  echo "FAIL: preview succeeded with no UI library anywhere — the step proves nothing" >&2
  exit 1
fi
grep -q 'mq-ui.sh' "$WORK/err"
echo "  ok: the fallback is still \$HOME/macos-scripts, and it still fails when absent"

echo "[5/5] the suite did not touch the theme of the machine running it"
real_after="(absent)"
[[ -f "$REAL_THEME" ]] && real_after="$(shasum "$REAL_THEME" | cut -d' ' -f1)"
if [[ "$real_before" != "$real_after" ]]; then
  echo "FAIL: $REAL_THEME changed during this test ($real_before -> $real_after)" >&2
  exit 1
fi
echo "  ok: $REAL_THEME is unchanged"

echo "PASS: mq-theme-manager.sh runs outside \$HOME/macos-scripts"
