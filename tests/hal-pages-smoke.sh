#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAGE="$ROOT/docs/hal.html"

echo "SMOKE: HAL Pages"

echo "[1/8] hal.html exists"
test -f "$PAGE"

echo "[2/8] page has title"
grep -q "MQLaunch HAL" "$PAGE"

echo "[3/8] page documents core commands"
grep -q "mqlaunch hal brief" "$PAGE"
grep -q "mqlaunch hal audit" "$PAGE"
grep -q "mqlaunch hal release-brief" "$PAGE"
grep -q "mqlaunch hal repo-status" "$PAGE"
grep -q "mqlaunch hal ci" "$PAGE"

echo "[4/8] page documents groups"
grep -q "Observe" "$PAGE"
grep -q "Plan" "$PAGE"
grep -q "Memory" "$PAGE"
grep -q "Debug" "$PAGE"

echo "[5/8] page mentions bridge model"
grep -q "mqlaunch.*owns UX" "$PAGE"
grep -q "mq-hal.*owns the logic" "$PAGE"

echo "[6/8] page mentions guardrails"
grep -q "surface_" "$PAGE"

echo "[7/8] page is valid enough HTML"
grep -qi "<!doctype html>" "$PAGE"
grep -q "</html>" "$PAGE"

echo "[8/8] docs link exists if index is present"
if [ -f "$ROOT/docs/index.html" ]; then
  grep -q "hal.html" "$ROOT/docs/index.html"
fi

echo "OK: HAL Pages smoke test passed"
