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
grep -q "Observe" "$GALLERY"
grep -q "Plan" "$GALLERY"
grep -q "Memory" "$GALLERY"
grep -q "Debug" "$GALLERY"

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

echo "[7/8] preview contains Audit"
grep -q "Audit" "$PREVIEW"

echo "[8/8] preview contains Back and Exit"
grep -q "Back" "$PREVIEW"
grep -q "Exit launcher" "$PREVIEW"

echo "OK: HAL gallery docs smoke test passed"
