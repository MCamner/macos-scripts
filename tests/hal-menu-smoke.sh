#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/8] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/8] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/8] menu syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/8] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[5/8] bridge routes audit"
grep -q "audit)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[6/8] bridge routes release-brief"
grep -q "release-brief|release)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[7/8] menu shows Audit"
grep -q "Audit" "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[8/8] menu shows Release Brief"
grep -q "Release Brief" "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "OK: HAL menu smoke test passed"
