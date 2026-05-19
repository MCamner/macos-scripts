#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-hal-menu.sh"

echo "SMOKE: HAL menu layout"

echo "[1/10] menu exists"
test -f "$MENU"

echo "[2/10] syntax check"
bash -n "$MENU"

echo "[3/10] uses mqlaunch surface panel"
grep -q "surface_panel_header" "$MENU"

echo "[4/10] uses surface rows"
grep -q "surface_row" "$MENU"

echo "[5/10] uses split rows"
grep -q "surface_split_row" "$MENU"

echo "[6/10] closes surface box"
grep -q "surface_bottom" "$MENU"

echo "[7/10] uses pinned mqlaunch prompt"
grep -q 'read_main_choice "hal"' "$MENU"

echo "[8/10] keeps Back and Exit launcher"
grep -q "b. Back" "$MENU"
grep -q "x. Exit launcher" "$MENU"

echo "[9/10] includes Audit menu item"
grep -q "Audit" "$MENU"

echo "[10/10] includes audit case"
grep -q "a|audit)" "$MENU"

echo "OK: HAL menu layout preserved"
