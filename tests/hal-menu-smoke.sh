#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/5] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/5] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/5] menu syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/5] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[5/5] bridge mentions brief"
grep -q "brief" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "OK: HAL menu smoke test passed"
