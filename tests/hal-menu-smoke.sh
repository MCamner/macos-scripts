#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/4] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/4] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/4] syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/4] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "OK: HAL menu smoke test passed"
