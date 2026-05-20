#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAGE="$ROOT/docs/index.html"
SITEMAP="$ROOT/docs/sitemap.xml"

echo "SMOKE: Pages index"

echo "[1/9] index exists"
test -f "$PAGE"

echo "[2/9] page has product title"
grep -q "Structured macOS workflows" "$PAGE"

echo "[3/9] page documents install/run/explore"
grep -q "Install, run, explore" "$PAGE"
grep -q "mqlaunch doctor" "$PAGE"
grep -q "mqlaunch hal" "$PAGE"

echo "[4/9] page links core docs"
grep -q "case.html" "$PAGE"
grep -q "hal.html" "$PAGE"
grep -q "COMMANDS.md" "$PAGE"
grep -q "mac-terminal-guide.html" "$PAGE"

echo "[5/9] page references screenshots"
grep -q "screenshots/hal-menu.png" "$PAGE"
grep -q "screenshots/main-menu.png" "$PAGE"
grep -q "screenshots/performance-menu.png" "$PAGE"
grep -q "screenshots/release-flow.png" "$PAGE"

echo "[6/9] page highlights HAL"
grep -q "HAL overview" "$PAGE"
grep -q "Observe before acting" "$PAGE"

echo "[7/9] page is valid enough HTML"
grep -qi "<!doctype html>" "$PAGE"
grep -q "</html>" "$PAGE"

echo "[8/9] screenshot assets exist"
test -s "$ROOT/docs/screenshots/hal-menu.png"
test -s "$ROOT/docs/screenshots/main-menu.png"
test -s "$ROOT/docs/screenshots/performance-menu.png"
test -s "$ROOT/docs/screenshots/release-flow.png"

echo "[9/9] sitemap includes HAL page"
grep -q "hal.html" "$SITEMAP"

echo "OK: Pages index smoke test passed"
