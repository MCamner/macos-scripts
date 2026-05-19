#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/hal-command-surface.md"

echo "SMOKE: HAL command surface docs"

echo "[1/8] command surface doc exists"
test -f "$DOC"

echo "[2/8] documents bridge"
grep -q "terminal/bridges/hal-bridge.sh" "$DOC"

echo "[3/8] documents menu"
grep -q "terminal/menus/mq-hal-menu.sh" "$DOC"

echo "[4/8] documents layout primitives"
grep -q "surface_panel_header" "$DOC"
grep -q "surface_split_row" "$DOC"
grep -q 'read_main_choice "hal"' "$DOC"

echo "[5/8] documents observe commands"
grep -q "mqlaunch hal brief" "$DOC"
grep -q "mqlaunch hal audit" "$DOC"
grep -q "mqlaunch hal release-brief" "$DOC"
grep -q "mqlaunch hal repo-status" "$DOC"
grep -q "mqlaunch hal ci" "$DOC"

echo "[6/8] documents planning command"
grep -q "mqlaunch hal fix-doctor" "$DOC"

echo "[7/8] documents memory commands"
grep -q "mqlaunch hal session" "$DOC"
grep -q "mqlaunch hal remember" "$DOC"

echo "[8/8] documents safety model"
grep -q "auto-release" "$DOC"
grep -q "run arbitrary shell" "$DOC"

echo "OK: HAL command surface docs smoke test passed"
