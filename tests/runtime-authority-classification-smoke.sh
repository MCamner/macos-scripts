#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$ROOT/docs/AUTHORITY_MAP.md"
PLAN="$ROOT/docs/plans/P1-runtime-authority.md"
FREEZE="$ROOT/scripts/check-runtime-authority.sh"

echo "SMOKE: runtime authority classification"

echo "[1/6] authority files exist"
[[ -f "$MAP" && -f "$PLAN" && -x "$FREEZE" ]]

echo "[2/6] official entrypoint and coordinator are declared"
grep -q '`bin/mqlaunch`.*Official entrypoint' "$MAP"
grep -q '`terminal/launchers/mqlaunch.sh`.*Current runtime coordinator' "$MAP"

echo "[3/6] every authority class is defined"
for class in LIVE COMPAT DEPRECATED TEST-ONLY; do
  grep -q "\*\*$class\*\*" "$MAP"
done

echo "[4/6] UI and dashboard authorities are explicit"
grep -q '`ui/terminal-ui/mq-ui.sh`.*UI authority' "$MAP"
grep -q '`ui/ascii/mqlaunch-dashboard-v7.1.sh`.*Dashboard authority' "$MAP"

echo "[5/6] performance compat exception and forbidden direction are explicit"
grep -q '`terminal/menus/mq-performance-menu.sh`.*COMPAT' "$MAP"
grep -q 'live menus or launchers depending directly on `terminal/mqlaunch-v1/\*`' "$MAP"

echo "[6/6] freeze gate agrees with the documented boundary"
"$FREEZE"

bash -n "$0"
echo "OK: runtime authority is documented and enforced"
