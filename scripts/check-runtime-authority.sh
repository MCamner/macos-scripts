#!/usr/bin/env bash
# Runtime authority freeze gate (P1 Step 10).
#
# The legacy `terminal/mqlaunch-v1/` tree is COMPAT, not LIVE
# (see docs/AUTHORITY_MAP.md). Only the documented compatibility edges may
# reach it. Any *other* runtime shell file that references `mqlaunch-v1` is a
# new live -> legacy dependency — a freeze violation — and fails this check.
#
# Scope: live/compat runtime shell only (terminal/, ui/, mqlaunch/), excluding
# the v1 tree itself. Test/tooling under tools/ and tests/ legitimately drives
# v1 and is out of scope.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Files allowed to reference the legacy v1 tree — the documented compat edges.
# Keep this list in sync with docs/AUTHORITY_MAP.md. Shrinking it is the goal
# (Step 12); growing it must be a conscious, reviewed decision.
ALLOW=(
  "terminal/bridges/performance-bridge.sh"
  "terminal/bridges/tools-bridge.sh"
  "terminal/menus/mq-performance-menu.sh"
)

# Returns 0 if the path is on the compat allowlist.
is_allowed() {
  local f="$1" a
  for a in "${ALLOW[@]}"; do
    [[ "$f" == "$a" ]] && return 0
  done
  return 1
}

violations=0
while IFS= read -r -d '' f; do
  if grep -q 'mqlaunch-v1' "$f" && ! is_allowed "$f"; then
    echo "FORBIDDEN: $f references mqlaunch-v1 but is not a documented compat edge"
    grep -n 'mqlaunch-v1' "$f" | sed 's/^/    /'
    violations=$(( violations + 1 ))
  fi
done < <(
  find terminal ui mqlaunch \
    -type f \( -name '*.sh' -o -name '*.zsh' \) \
    -not -path 'terminal/mqlaunch-v1/*' \
    -print0 2>/dev/null
)

# Also assert the allowlist has not silently drifted: every allowed file must
# still exist and still reference v1 (otherwise the entry is stale and the list
# should shrink — a Step 12 win worth surfacing).
stale=0
for a in "${ALLOW[@]}"; do
  if [[ ! -f "$a" ]]; then
    echo "STALE ALLOWLIST: $a no longer exists — remove it from ALLOW"
    stale=$(( stale + 1 ))
  elif ! grep -q 'mqlaunch-v1' "$a"; then
    echo "STALE ALLOWLIST: $a no longer references mqlaunch-v1 — remove it from ALLOW"
    stale=$(( stale + 1 ))
  fi
done

if (( violations > 0 || stale > 0 )); then
  echo ""
  echo "Runtime authority freeze failed: ${violations} new live->v1 edge(s), ${stale} stale allowlist entry/entries."
  echo "See docs/AUTHORITY_MAP.md. Route new work through a documented compat bridge, or migrate off v1."
  exit 1
fi

echo "[PASS] Runtime authority freeze: no new live->mqlaunch-v1 edges (compat allowlist: ${#ALLOW[@]})."
