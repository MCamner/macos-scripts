#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE="$ROOT/terminal/bridges/hal-bridge.sh"
MENU="$ROOT/terminal/menus/mq-hal-menu.sh"
COMMANDS="$ROOT/docs/COMMANDS.md"

echo "SMOKE: HAL file formatting"

test -f "$BRIDGE"
test -f "$MENU"

BRIDGE_LINES="$(wc -l < "$BRIDGE" | tr -d ' ')"
MENU_LINES="$(wc -l < "$MENU" | tr -d ' ')"

if [ "$BRIDGE_LINES" -lt 40 ]; then
  echo "hal-bridge.sh looks flattened: $BRIDGE_LINES lines" >&2
  exit 1
fi

if [ "$MENU_LINES" -lt 80 ]; then
  echo "mq-hal-menu.sh looks flattened: $MENU_LINES lines" >&2
  exit 1
fi

bash -n "$BRIDGE"
bash -n "$MENU"

grep -q "audit" "$BRIDGE"
grep -q "release-brief" "$BRIDGE"
grep -q "repo-status" "$BRIDGE"
grep -q "ci" "$BRIDGE"

grep -q "surface_panel_header" "$MENU"
grep -q "read_main_choice" "$MENU"
grep -q "Audit" "$MENU"

if [ -f "$COMMANDS" ]; then
  grep -q "HAL Command Surface" "$COMMANDS"
fi

echo "OK: HAL file formatting preserved"
