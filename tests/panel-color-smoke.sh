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
# Runs a snippet on a pty, because the colour block is guarded by `[[ -t 1 ]]`
# and off a terminal every check below would compare empty strings and pass.
#
# python3 rather than `script`: the two `script` implementations disagree on how
# a command is passed — macOS takes `script -q /dev/null cmd args`, util-linux
# needs `-c` and reads the rest as filenames. The BSD form died under `set -e`
# on the runner before printing anything, so the step failed for the wrong
# reason. pty.spawn behaves the same on both.
#
# MACOS_SCRIPTS_HOME is set and the source is not silenced: without the home the
# library bails and surface_panel_color prints nothing, which an earlier version
# of this helper did while the checks quietly compared empty strings.
panel_colour() {
  local env_line="$1"
  python3 - "$ROOT" "$UI" "$env_line" <<'PY' 2>/dev/null | tr -d '\r'
import os, pty, subprocess, sys
root, ui, env_line = sys.argv[1], sys.argv[2], sys.argv[3]
code = (
    f"export MACOS_SCRIPTS_HOME='{root}'\n"
    f"{env_line}\n"
    f". '{ui}'\n"
    "surface_panel_color | od -An -c | tr -d ' \\n'\n"
)
main_fd, child_fd = pty.openpty()
proc = subprocess.Popen(
    ["/bin/bash", "-c", code],
    stdin=subprocess.DEVNULL, stdout=child_fd, stderr=subprocess.DEVNULL,
    close_fds=True,
)
os.close(child_fd)
chunks = []
while True:
    try:
        data = os.read(main_fd, 1024)
    except OSError:
        break
    if not data:
        break
    chunks.append(data)
proc.wait()
os.close(main_fd)
sys.stdout.write(b"".join(chunks).decode("utf-8", "replace"))
PY
}

echo "[3/5] the default is white, not grey"
# `|| true` so a broken helper reports below instead of killing the script under
# `set -e`. The first CI run of this test died here without printing anything,
# which said "exit 1" and nothing about why.
default_colour="$(panel_colour 'unset MQ_COLOR_PANEL; unset NO_COLOR')" || true
case "$default_colour" in
  *'033[1;37m'*) ;;
  *)
    echo "FAIL: default panel colour is not bright white: $default_colour" >&2
    exit 1
    ;;
esac
echo "  ok: default renders 1;37"

echo "[4/5] a theme can override it"
themed_colour="$(panel_colour "export MQ_COLOR_PANEL=\$'\\033[0;35m'; unset NO_COLOR")" || true
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
