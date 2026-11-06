#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GALLERY="$ROOT/docs/hal-gallery.md"
PREVIEW="$ROOT/docs/hal-menu-preview.txt"

echo "SMOKE: HAL gallery docs"

echo "[1/8] gallery exists"
test -f "$GALLERY"

echo "[2/8] preview exists"
test -f "$PREVIEW"

echo "[3/8] gallery documents command groups"
for group in Observe Intelligence Health Memory "Debug / Advanced"; do
  grep -qF "### $group" "$GALLERY"
done

echo "[4/8] gallery includes core commands"
grep -q "mqlaunch hal audit" "$GALLERY"
grep -q "mqlaunch hal release-brief" "$GALLERY"
grep -q "mqlaunch hal repo-status" "$GALLERY"
grep -q "mqlaunch hal ci" "$GALLERY"

echo "[5/8] gallery documents layout contract"
grep -q "surface_panel_header" "$GALLERY"
grep -q "surface_split_row" "$GALLERY"
grep -q 'read_main_choice "hal"' "$GALLERY"

echo "[6/8] preview contains menu title"
grep -q "MQ HAL" "$PREVIEW"

echo "[7/8] preview and gallery match render_hal_panel"
# Both copies once showed a 16-choice menu after the real one had 10.
MENU="$ROOT/terminal/menus/mq-hal-menu.sh"
choice_re='[0-9]+\. [A-Za-z]+( [A-Za-z]+)*'
src_choices="$(sed -n '/^render_hal_panel()/,/^}/p' "$MENU" \
  | grep -E 'surface_(split_)?row' | grep -oE "\"$choice_re\"" | tr -d '"' | sort -u)"
preview_choices="$({ grep -oE "$choice_re" "$PREVIEW" || true; } | sort -u)"
test -n "$src_choices"
if [ "$src_choices" != "$preview_choices" ]; then
  echo "FAIL: docs/hal-menu-preview.txt differs from render_hal_panel" >&2
  diff <(printf '%s\n' "$src_choices") <(printf '%s\n' "$preview_choices") >&2 || true
  exit 1
fi
gallery_block="$(awk '/^## HAL Menu Preview/{f=1;next} f&&/^```text/{b=1;next} b&&/^```/{exit} b' "$GALLERY")"
if [ "$gallery_block" != "$(cat "$PREVIEW")" ]; then
  echo "FAIL: hal-gallery.md preview block differs from docs/hal-menu-preview.txt" >&2
  diff <(printf '%s\n' "$gallery_block") "$PREVIEW" >&2 || true
  exit 1
fi

echo "[8/8] preview contains Back and Exit"
grep -q "Back" "$PREVIEW"
grep -q "Exit launcher" "$PREVIEW"

echo "OK: HAL gallery docs smoke test passed"
