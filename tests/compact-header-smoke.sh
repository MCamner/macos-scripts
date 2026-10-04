#!/usr/bin/env bash
# Compact header: the 38-line dashboard on first start, a 5-line header after.
#
# Every submenu and every return to the main menu redrew the logo, the SYSTEM,
# WORKSPACE and LIVE SHORTCUTS panels and the READY banner — 38 lines before
# the first menu choice, so on a normal terminal the menu itself scrolled off.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$ROOT/ui/ascii/mqlaunch-dashboard-v7.1.sh"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
MAIN_MENU="$ROOT/terminal/menus/mq-main-menu.sh"

echo "SMOKE: compact header"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Marks a failing check.
fail() {
  echo "FAIL: $1" >&2
  exit 1
}

git -C "$TMP" init -q
git -C "$TMP" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

echo "[1/6] compact layout is a six-line box with the figures and the status"
compact="$(cd "$TMP" && MQ_DASHBOARD_LAYOUT=compact MACOS_SCRIPTS_HOME="$ROOT" \
  bash "$DASHBOARD" MQ test ONLINE 2>/dev/null)"
lines="$(printf '%s\n' "$compact" | grep -c .)"
[[ "$lines" == 6 ]] || fail "compact header has $lines lines, expected 6"
grep -q "▄▄████▄▄" <<<"$compact" || fail "figures missing"
head -1 <<<"$compact" | grep -q "┌─ MQLAUNCH" || fail "box top with MQLAUNCH title missing"
tail -1 <<<"$compact" | grep -q "└" || fail "box bottom missing"
# Every row as wide as the menu panel below it, or the two frames do not line up.
widths="$(printf '%s\n' "$compact" | while IFS= read -r l; do printf '%s\n' "${#l}"; done | sort -u)"
[[ "$(wc -l <<<"$widths" | tr -d ' ')" == 1 ]] || fail "box rows differ in width: $(tr '\n' ' ' <<<"$widths")"
grep -q "Next:" <<<"$compact" || fail "next action missing"
grep -qE "MEM .*BAT " <<<"$compact" || fail "MEM/BAT missing"
! grep -q "PHOSPHOR" <<<"$compact" || fail "compact header still draws the banner"

echo "[2/6] full layout is unchanged by default"
full="$(cd "$TMP" && MACOS_SCRIPTS_HOME="$ROOT" bash "$DASHBOARD" MQ test ONLINE 2>/dev/null)"
grep -q "PHOSPHOR" <<<"$full" || fail "full header lost its banner"

echo "[3/6] layout choice: full once in a tall window, compact after"
out="$(MACOS_SCRIPTS_HOME="$ROOT" bash -c '
  source "$1"
  unset MQ_HEADER_FULL_SHOWN MQ_FULL_HEADER_REQUEST
  MQ_TERM_LINES=60
  printf "%s " "$(mq_header_layout)"; mq_header_mark_shown
  printf "%s " "$(mq_header_layout)"
  MQ_FULL_HEADER_REQUEST=1
  printf "%s " "$(mq_header_layout)"; mq_header_mark_shown
  printf "%s\n" "$(mq_header_layout)"
' _ "$UI")"
[[ "$out" == "full compact full compact" ]] || fail "tall window sequence: $out"

echo "[4/6] small window starts compact"
out="$(MACOS_SCRIPTS_HOME="$ROOT" bash -c '
  source "$1"
  unset MQ_HEADER_FULL_SHOWN MQ_FULL_HEADER_REQUEST
  MQ_TERM_LINES=30
  mq_header_layout
' _ "$UI")"
[[ "$out" == "compact" ]] || fail "small window started with: $out"

echo "[5/6] panels drop the Host/User row only when the header carries it"
with="$(MACOS_SCRIPTS_HOME="$ROOT" MQ_USE_DASHBOARD_HEADER=1 bash -c '
  source "$1"; surface_panel_header "System" "System" 80 ""' _ "$UI")"
without="$(MACOS_SCRIPTS_HOME="$ROOT" MQ_USE_DASHBOARD_HEADER=0 bash -c '
  source "$1"; surface_panel_header "System" "System" 80 ""' _ "$UI")"
! grep -q "Host:" <<<"$with" || fail "panel repeats Host/User under the dashboard header"
grep -q "Host:" <<<"$without" || fail "panel lost Host/User without a dashboard header"

echo "[6/6] main menu offers f for the full header and drops Command Surface"
grep -qE '^[[:space:]]*f\)' "$MAIN_MENU" || fail "no f) arm in the main menu"
grep -q '"f. Full header"' "$MAIN_MENU" || fail "f. Full header not shown in the panel"

echo "PASS: compact header"
