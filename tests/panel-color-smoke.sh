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

echo "[1/8] the ui library exists"
test -f "$UI"

echo "[2/8] the panel colour is a theme variable"
grep -q 'MQ_COLOR_PANEL' "$UI" || {
  echo "FAIL: mq-ui.sh does not read MQ_COLOR_PANEL" >&2
  exit 1
}

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

echo "[3/8] the default names white rather than a palette index"
# `|| true` so a broken helper reports below instead of killing the script under
# `set -e`. The first CI run of this test died here without printing anything,
# which said "exit 1" and nothing about why.
default_colour="$(panel_colour 'unset MQ_COLOR_PANEL; unset NO_COLOR')" || true
case "$default_colour" in
  *'[38;2;255;255;255m'*) ;;
  *)
    echo "FAIL: default panel colour is not bright white: $default_colour" >&2
    exit 1
    ;;
esac
echo "  ok: default names white outright"

echo "[4/8] a theme can override it"
themed_colour="$(panel_colour "export MQ_COLOR_PANEL=\$'\\033[0;35m'; unset NO_COLOR")" || true
case "$themed_colour" in
  *'033[0;35m'*) ;;
  *)
    echo "FAIL: MQ_COLOR_PANEL did not reach surface_panel_color: $themed_colour" >&2
    exit 1
    ;;
esac
echo "  ok: MQ_COLOR_PANEL wins over the default"

echo "[5/8] no menu hardcodes a panel colour past the theme"
# Static, so it fails on any machine. The render checks above only prove the
# library; a menu assigning its own escape defeats the theme without touching
# surface_panel_color at all — which is exactly how four of them drifted grey.
if grep -rn "panel_color=\$'\\\\033\[" "$ROOT/terminal/menus/" 2>/dev/null; then
  echo "FAIL: a menu sets panel_color directly; call surface_panel_color" >&2
  exit 1
fi
echo "  ok: menus take the colour from the library"

echo "[6/8] no panel is drawn with an empty colour"
# The step above catches a menu that picks its own colour. It does not catch a
# menu that passes `""` and gets no colour at all — which is how the HAL and
# Obsidian "not found" panels drew in the terminal default while every other
# panel followed the theme. Same class of defect, opposite symptom.
if grep -rnE 'surface_(top|row|split_row|bottom|panel_header) .*"\$width" ""' \
  "$ROOT/terminal/menus/" 2>/dev/null; then
  echo "FAIL: a panel passes an empty colour; call surface_panel_color" >&2
  exit 1
fi
echo "  ok: no panel opts out of the colour"

echo "[7/8] the stack has one white"
# C_WHITE meant two different things: 1;97 in gitlaunch, the zsh theme and the
# prompt preview, but 37 — grey — in the dashboards. The READY banner sits
# directly above a panel, so the disagreement was visible as two shades of
# almost-white on one screen. Both were palette indices, which a terminal
# profile is free to remap; white is named outright now so it cannot be.
#
# Written in python, not as piped greps. The first version chained three greps
# and one of them held an empty alternation, which BSD grep rejects outright —
# so the middle stage errored, the pipeline returned non-zero, the `if` took the
# false branch, and the step printed "ok" having checked nothing.
if ! python3 - "$ROOT" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
assign = re.compile(r"C_WHITE:?=(?P<value>.*)")
# Empty is deliberate: it is how every one of these files spells "no colour".
allowed_empty = {"", '""', "''", '}"', "}"}

offenders = []
for directory in ("ui", "terminal", "tools"):
    for path in sorted((root / directory).rglob("*")):
        if path.suffix not in {".sh", ".zsh"} or not path.is_file():
            continue
        for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            found = assign.search(line)
            if not found:
                continue
            value = found.group("value").strip()
            if "38;2;255;255;255" in value or value in allowed_empty:
                continue
            # The library reads a theme variable rather than naming a shade.
            if "MQ_COLOR_WHITE" in value:
                continue
            offenders.append(f"{path.relative_to(root)}:{number}: {line.strip()}")

if offenders:
    print("FAIL: C_WHITE does not name white outright here:", file=sys.stderr)
    for line in offenders:
        print(f"  {line}", file=sys.stderr)
    sys.exit(1)
print(f"  checked {sum(1 for _ in (root / 'ui').rglob('*.sh'))} ui scripts and their peers")
PY
then
  exit 1
fi
echo "  ok: every C_WHITE names white outright or is deliberately empty"

echo "[8/8] the dashboard header keeps its colour through a command substitution"
# print_dashboard_header runs the dashboard inside `$( )`, so its stdout is a
# pipe. The dashboard sets its own colours behind a guard that accepts
# MQ_DASHBOARD_FORCE_COLOR, then sources mq-ui.sh — whose guard was `-t 1`
# alone, so it reset every colour to empty and the READY banner printed with no
# escape at all. The panel below it was white; the banner was whatever the
# terminal happened to be.
#
# Checked by rendering the banner the way print_dashboard_header does, not by
# reading the guard: the two files have to agree, and only running it shows that.
# Isolate this positive colour assertion from a host-level NO_COLOR setting.
# NO_COLOR must still win in normal use; this step specifically proves the
# internal capture path used by print_dashboard_header.
dashboard_banner="$(NO_COLOR='' MQ_DASHBOARD_FORCE_COLOR=1 bash \
  "$ROOT/ui/ascii/mqlaunch-dashboard-v7.1.sh" "MQ" "test" "ONLINE" 2>/dev/null \
  | grep -a "READY //" || true)"
if [[ -z "$dashboard_banner" ]]; then
  echo "FAIL: the dashboard printed no READY banner to check" >&2
  exit 1
fi
case "$dashboard_banner" in
  *$'\033['*) ;;
  *)
    echo "FAIL: the READY banner carries no colour through a pipe" >&2
    exit 1
    ;;
esac
echo "  ok: the banner keeps its colour when captured"

echo "OK: panel colour smoke test passed"
