#!/usr/bin/env bash
# Runtime authority freeze gate (P1 Step 10).
#
# The legacy `terminal/mqlaunch-v1/` tree is COMPAT, not LIVE
# (see docs/AUTHORITY_MAP.md). Only the documented compatibility edges may
# reach it. Any *other* runtime shell file that references `mqlaunch-v1` is a
# new live -> legacy dependency — a freeze violation — and fails this check.
#
# Scope: every tracked shell file except the v1 tree itself and `tests/`, which
# drives v1 on purpose. It was three directories (terminal/, ui/, mqlaunch/)
# until 2026-08-01, which is narrower than "live runtime shell" and let two
# edges sit unseen: `automation/login/mqlogin.sh` preferred the frozen launcher
# over the current one, and `tools/scripts/create-debug-bundle.sh` runs
# `bash v1/mqlaunch.sh help` from a live system-menu row. Neither was a
# conscious decision, which is the only thing an allowlist is for.
#
# The file list comes from `git ls-files`, so an untracked copy of a menu in the
# working tree can neither add an edge nor hide one — the same reason
# tools/scripts/inventory-command-surfaces.py reads from git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Live code that depends on the v1 tree at runtime. Keep in sync with
# docs/AUTHORITY_MAP.md. Shrinking this list is the goal (Step 12); growing it
# must be a conscious, reviewed decision.
COMPAT_EDGES=(
  "terminal/bridges/performance-bridge.sh"
  "terminal/bridges/tools-bridge.sh"
  "terminal/menus/mq-performance-menu.sh"
  "tools/scripts/create-debug-bundle.sh"
)

# Build, lint and documentation tooling that names the v1 tree to exclude it, to
# test it, or to police it. These are not runtime dependencies, so deleting v1
# would edit them rather than break them — a distinction the old single list
# could not express, and the reason widening the scan needed two lists instead
# of a longer one.
TOOLING=(
  "scripts/check-runtime-authority.sh"
  "tools/scripts/generate-wiki-command-ref.sh"
  "tools/scripts/lint.sh"
  "tools/scripts/shellcheck-report.sh"
  "tools/scripts/test-all.sh"
  "tools/scripts/test-mqlaunch-v1.sh"
  "tools/scripts/test-mqlaunch.sh"
)

CLASSIFIED=("${COMPAT_EDGES[@]}" "${TOOLING[@]}")

# Returns 0 if the path is classified on either list.
is_classified() {
  local f="$1" a
  for a in "${CLASSIFIED[@]}"; do
    [[ "$f" == "$a" ]] && return 0
  done
  return 1
}

violations=0
while IFS= read -r f; do
  case "$f" in
    terminal/mqlaunch-v1/*|tests/*) continue ;;
  esac
  if grep -q 'mqlaunch-v1' "$f" && ! is_classified "$f"; then
    echo "FORBIDDEN: $f references mqlaunch-v1 but is on neither list"
    grep -n 'mqlaunch-v1' "$f" | sed 's/^/    /'
    violations=$(( violations + 1 ))
  fi
done < <(git ls-files '*.sh' '*.zsh')

# Also assert the lists have not silently drifted: every entry must still exist
# and still reference v1 (otherwise it is stale and the list should shrink — a
# Step 12 win worth surfacing).
stale=0
for a in "${CLASSIFIED[@]}"; do
  if [[ ! -f "$a" ]]; then
    echo "STALE LIST: $a no longer exists — remove it"
    stale=$(( stale + 1 ))
  elif ! grep -q 'mqlaunch-v1' "$a"; then
    echo "STALE LIST: $a no longer references mqlaunch-v1 — remove it"
    stale=$(( stale + 1 ))
  fi
done

if (( violations > 0 || stale > 0 )); then
  echo ""
  echo "Runtime authority freeze failed: ${violations} unclassified live->v1 edge(s), ${stale} stale entry/entries."
  echo "See docs/AUTHORITY_MAP.md. Route new work through a documented compat bridge, or migrate off v1."
  exit 1
fi

echo "[PASS] Runtime authority freeze: no new live->mqlaunch-v1 edges (compat edges: ${#COMPAT_EDGES[@]}, tooling: ${#TOOLING[@]})."
