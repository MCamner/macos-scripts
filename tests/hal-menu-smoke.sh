#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/6] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/6] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/6] menu syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/6] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[5/6] bridge mentions repo-status"
grep -q "repo-status" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[6/6] bridge mentions ci"
grep -q "ci-status" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "OK: HAL menu smoke test passed"
