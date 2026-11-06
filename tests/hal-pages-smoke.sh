#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAGE="$ROOT/docs/hal.html"

echo "SMOKE: HAL Pages"

echo "[1/10] hal.html exists"
test -f "$PAGE"

echo "[2/10] page has title"
grep -q "MQLaunch HAL" "$PAGE"

echo "[3/10] page documents core commands"
grep -q "mqlaunch hal brief" "$PAGE"
grep -q "mqlaunch hal audit" "$PAGE"
grep -q "mqlaunch hal release-brief" "$PAGE"
grep -q "mqlaunch hal repo-status" "$PAGE"
grep -q "mqlaunch hal ci" "$PAGE"

echo "[4/10] page documents groups"
for group in OBSERVE INTELLIGENCE HEALTH MEMORY "DEBUG / ADVANCED"; do
  grep -qF "$group" "$PAGE"
done

echo "[5/10] page mentions bridge model"
grep -q "mqlaunch.*owns UX" "$PAGE"
grep -q "mq-hal.*owns the logic" "$PAGE"

echo "[6/10] page mentions guardrails"
grep -q "surface_" "$PAGE"

echo "[7/10] page is valid enough HTML"
grep -qi "<!doctype html>" "$PAGE"
grep -q "</html>" "$PAGE"

echo "[8/10] docs link exists if index is present"
if [ -f "$ROOT/docs/index.html" ]; then
  grep -q "hal.html" "$ROOT/docs/index.html"
fi

echo "[9/10] page menu matches render_hal_panel"
# The page once showed a 16-choice menu long after the real one had 10.
# Compare the numbered choices both ways so the copy cannot drift again.
MENU="$ROOT/terminal/menus/mq-hal-menu.sh"
choice_re='[0-9]+\. [A-Za-z]+( [A-Za-z]+)*'
src_choices="$(sed -n '/^render_hal_panel()/,/^}/p' "$MENU" \
  | grep -E 'surface_(split_)?row' | grep -oE "\"$choice_re\"" | tr -d '"' | sort -u)"
page_choices="$(sed -n '/<pre id="hal-menu"/,/<\/pre>/p' "$PAGE" \
  | sed 's/<[^>]*>//g' | { grep -oE "$choice_re" || true; } | sort -u)"
test -n "$src_choices"
if [ "$src_choices" != "$page_choices" ]; then
  echo "FAIL: docs/hal.html menu differs from render_hal_panel" >&2
  diff <(printf '%s\n' "$src_choices") <(printf '%s\n' "$page_choices") >&2 || true
  exit 1
fi

echo "[10/10] page version matches VERSION"
grep -qF "$(tr -d '[:space:]' < "$ROOT/VERSION")" "$PAGE"

echo "OK: HAL Pages smoke test passed"
