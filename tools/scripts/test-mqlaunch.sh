#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="$HOME/macos-scripts"
LEGACY="$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
V1="$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  exit 1
}

[[ -f "$LEGACY" ]] || fail "Legacy launcher missing"
[[ -f "$V1" ]] || fail "V1 launcher missing"
pass "Launcher files exist"

zsh "$LEGACY" help >/dev/null 2>&1 || fail "Legacy launcher help failed"
pass "Legacy launcher help works"

bash "$V1" help >/dev/null 2>&1 || fail "V1 launcher help failed"
pass "V1 launcher help works"

grep -q 'perf|performance' "$LEGACY" || fail "Performance route missing in legacy launcher"
pass "Performance route exists"

grep -q 'open_v1_dev_menu' "$LEGACY" || fail "Dev bridge route missing in legacy launcher"
pass "Dev bridge route exists"

grep -q 'open_v1_tools_menu' "$LEGACY" || fail "Tools bridge route missing in legacy launcher"
pass "Tools bridge route exists"

echo
echo "All mqlaunch checks passed."
