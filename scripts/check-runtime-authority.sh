#!/usr/bin/env bash
# Runtime authority freeze gate (P1 Step 10, Step 12.6).
#
# The legacy `terminal/mqlaunch-v1/` tree is gone as of 2026-08-02. This is a
# tombstone gate now: a path that no longer exists cannot be depended on by
# accident, but it can be recreated, and a second runtime is exactly what the
# v2.0.0 track spent its length removing. Any shell file that references
# `mqlaunch-v1` without being classified fails the check.
#
# Scope: every tracked shell file except `tests/`, which plants references on
# purpose to prove this gate still fires. It was three directories (terminal/,
# ui/, mqlaunch/) until 2026-08-01, which is narrower than "live runtime shell"
# and let two edges sit unseen: `automation/login/mqlogin.sh` preferred the
# frozen launcher over the current one, and `tools/scripts/create-debug-bundle.sh`
# ran its help as a probe from a live system-menu row. Neither was a conscious
# decision, which is the only thing an allowlist is for.
#
# The file list comes from `git ls-files`, so an untracked copy of a menu in the
# working tree can neither add an edge nor hide one — the same reason
# tools/scripts/inventory-command-surfaces.py reads from git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Live code that depends on the v1 tree at runtime. Empty since 2026-08-02 and
# now permanently so — there is no tree to depend on. The four entries that were
# here were migrated or retired in #160, not tolerated: the performance data
# layer moved to mqlaunch/lib/performance.sh, tools-bridge.sh was deleted for
# want of a caller, performance-bridge.sh lost a fallback that only fired when
# the current menu was missing, and create-debug-bundle.sh stopped probing a
# tree nothing routes to.
#
# A non-empty list here again means someone reintroduced the legacy runtime.
COMPAT_EDGES=()

# Tooling that names the v1 tree without depending on it. This was seven files
# excluding, testing or policing the tree; deleting the tree edited them all.
# Two are left, and both name it in order to assert its absence.
TOOLING=(
  "scripts/check-runtime-authority.sh"
  "tools/scripts/test-mqlaunch.sh"
)

# The `+` guards are for the empty COMPAT_EDGES: under `set -u`, bash 3.2 —
# which is what /bin/bash is on macOS — treats "${EMPTY[@]}" as an unbound
# variable and aborts.
CLASSIFIED=(
  ${COMPAT_EDGES[@]+"${COMPAT_EDGES[@]}"}
  ${TOOLING[@]+"${TOOLING[@]}"}
)

# Returns 0 if the path is classified on either list.
is_classified() {
  local f="$1" a
  for a in ${CLASSIFIED[@]+"${CLASSIFIED[@]}"}; do
    [[ "$f" == "$a" ]] && return 0
  done
  return 1
}

violations=0
while IFS= read -r f; do
  case "$f" in
    tests/*) continue ;;
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
for a in ${CLASSIFIED[@]+"${CLASSIFIED[@]}"}; do
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

echo "[PASS] Runtime authority freeze: the v1 tree is gone and nothing references it (compat edges: ${#COMPAT_EDGES[@]}, tooling: ${#TOOLING[@]})."
