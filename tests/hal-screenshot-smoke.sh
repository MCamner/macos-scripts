#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHOT="$ROOT/docs/screenshots/hal-menu.png"
HAL_PAGE="$ROOT/docs/hal.html"
INDEX_PAGE="$ROOT/docs/index.html"

echo "SMOKE: HAL screenshot docs"

echo "[1/6] screenshot exists"
test -f "$SHOT"

echo "[2/6] screenshot is non-empty"
test -s "$SHOT"

echo "[3/6] screenshot is substantial"
BYTES="$(wc -c < "$SHOT" | tr -d ' ')"
if [ "$BYTES" -lt 20000 ]; then
  echo "HAL screenshot looks too small: $BYTES bytes" >&2
  exit 1
fi

echo "[4/6] HAL page references screenshot"
grep -q "screenshots/hal-menu.png" "$HAL_PAGE"

echo "[5/6] index references screenshot"
grep -q "screenshots/hal-menu.png" "$INDEX_PAGE"

echo "[6/6] image alt text mentions HAL"
grep -q "HAL menu" "$HAL_PAGE"
grep -q "HAL menu" "$INDEX_PAGE"

echo "OK: HAL screenshot docs smoke test passed"
