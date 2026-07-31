#!/usr/bin/env bash
set -euo pipefail

# The panel border and its host/mode row were the one part of the surface that
# ignored the theme: surface_panel_color() printed a literal `\033[0;37m`, and
# four menus hardcoded the same value again. 0;37 is ANSI white at normal
# intensity, which terminals render grey — so "MQ HAL" drew a grey box while
# MQ_COLOR_TITLE and friends were themeable.
#
# This pins the colour as themeable and single-sourced, not as a specific shade:
# the default may change, but the panel must keep reading it from one place.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"

echo "SMOKE: panel colour"

echo "[1/5] the ui library exists"
test -f "$UI"

echo "[2/5] the panel colour is a theme variable"
grep -q 'MQ_COLOR_PANEL' "$UI" || {
  echo "FAIL: mq-ui.sh does not read MQ_COLOR_PANEL" >&2
  exit 1
}

# Rendered through a pty, because the colour block is guarded by `[[ -t 1 ]]`
# and every one of these checks would otherwise compare empty strings and pass.
panel_colour() {
  local env_line="$1"
  # MACOS_SCRIPTS_HOME is set, and the source is not silenced: without the home
  # the library bails, surface_panel_color prints nothing, and every case below
  # would compare against an empty string. An empty result fails these checks
  # rather than passing them, which is what caught it.
  script -q /dev/null /bin/bash -c "
    export MACOS_SCRIPTS_HOME='$ROOT'
    $env_line
    . '$UI'
    surface_panel_color | od -An -c | tr -d ' \n'
  " 2>/dev/null | tr -d '\r'
}

echo "[3/5] the default is white, not grey"
default_colour="$(panel_colour 'unset MQ_COLOR_PANEL; unset NO_COLOR')"
case "$default_colour" in
  *'033[1;37m'*) ;;
  *)
    echo "FAIL: default panel colour is not bright white: $default_colour" >&2
    exit 1
    ;;
esac
echo "  ok: default renders 1;37"

echo "[4/5] a theme can override it"
themed_colour="$(panel_colour "export MQ_COLOR_PANEL=\$'\\033[0;35m'; unset NO_COLOR")"
case "$themed_colour" in
  *'033[0;35m'*) ;;
  *)
    echo "FAIL: MQ_COLOR_PANEL did not reach surface_panel_color: $themed_colour" >&2
    exit 1
    ;;
esac
echo "  ok: MQ_COLOR_PANEL wins over the default"

echo "[5/5] no menu hardcodes a panel colour past the theme"
# Static, so it fails on any machine. The render checks above only prove the
# library; a menu assigning its own escape defeats the theme without touching
# surface_panel_color at all — which is exactly how four of them drifted grey.
if grep -rn "panel_color=\$'\\\\033\[" "$ROOT/terminal/menus/" 2>/dev/null; then
  echo "FAIL: a menu sets panel_color directly; call surface_panel_color" >&2
  exit 1
fi
echo "  ok: menus take the colour from the library"

echo "OK: panel colour smoke test passed"
