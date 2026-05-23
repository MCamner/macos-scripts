#!/usr/bin/env bash
# Local install smoke test — verifies install.sh, release.sh, and core commands.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m[FAIL]\033[0m %s\n" "$*" >&2; exit 1; }
step() { printf "\033[1;34m[STEP]\033[0m %s\n" "$*"; }

cd "$REPO_ROOT"

step "install.sh --help"
bash install.sh --help > /dev/null && pass "install.sh --help"

step "install.sh --dry-run"
bash install.sh --dry-run --yes > /dev/null && pass "install.sh --dry-run"

step "bash -n on install.sh"
bash -n install.sh && pass "install.sh syntax OK"

step "bash -n on release.sh"
bash -n release.sh && pass "release.sh syntax OK"

step "Syntax check all .sh files by shebang (exclude backups/)"
find . \
  -name "*.sh" \
  -not -path "./.git/*" \
  -not -path "./backups/*" \
  -print0 \
| while IFS= read -r -d '' f; do
    shebang="$(head -1 "$f")"
    if [[ "$shebang" == *zsh* ]]; then
      zsh -n "$f" || { printf "\033[1;31m[FAIL]\033[0m zsh -n: %s\n" "$f" >&2; exit 1; }
    else
      bash -n "$f" || { printf "\033[1;31m[FAIL]\033[0m bash -n: %s\n" "$f" >&2; exit 1; }
    fi
  done
pass "all .sh files pass syntax check"

step "mqlaunch doctor --json"
if command -v mqlaunch >/dev/null 2>&1; then
  mqlaunch doctor --json | grep -q '"status"' && pass "mqlaunch doctor --json"
else
  printf "[SKIP] mqlaunch not in PATH — run after install\n"
fi

step "mqlaunch selftest"
if command -v mqlaunch >/dev/null 2>&1; then
  mqlaunch selftest && pass "mqlaunch selftest"
else
  printf "[SKIP] mqlaunch not in PATH — run after install\n"
fi

printf "\n\033[1;32m=== install smoke test passed ===\033[0m\n"
