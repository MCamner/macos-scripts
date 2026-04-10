#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="$HOME/macos-scripts"
LEGACY="$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
V1="$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"
TOOLS_BRIDGE="$PROJECT_ROOT/terminal/bridges/tools-bridge.sh"
DEV_BRIDGE="$PROJECT_ROOT/terminal/bridges/dev-bridge.sh"
PERF_BRIDGE="$PROJECT_ROOT/terminal/bridges/performance-bridge.sh"

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  exit 1
}

assert_file() {
  local path="$1"
  local label="$2"
  [[ -f "$path" ]] || fail "$label missing: $path"
  pass "$label exists"
}

assert_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -qE "$pattern" "$file" || fail "$label"
  pass "$label"
}

assert_cmd_ok() {
  local label="$1"
  shift
  "$@" >/dev/null 2>&1 || fail "$label"
  pass "$label"
}

assert_file "$LEGACY" "Legacy launcher"
assert_file "$V1" "V1 launcher"
assert_file "$TOOLS_BRIDGE" "Tools bridge"
assert_file "$DEV_BRIDGE" "Dev bridge"
assert_file "$PERF_BRIDGE" "Performance bridge"

assert_cmd_ok "Legacy launcher help works" zsh "$LEGACY" help
assert_cmd_ok "V1 launcher help works" bash "$V1" help

assert_grep 'perf\|performance\).*open_v1_performance_menu' "$LEGACY" "Performance route exists in legacy launcher"
assert_grep 'dev\|git\).*open_v1_dev_menu' "$LEGACY" "Dev route exists in legacy launcher"
assert_grep 'tools\|tools-v1\|menu-tools-v1\).*open_v1_tools_menu' "$LEGACY" "Tools route exists in legacy launcher"

assert_grep 'WORKFLOWS' "$LEGACY" "Main menu contains WORKFLOWS section"
assert_grep '23\. Performance' "$LEGACY" "Main menu contains Performance entry"
assert_grep '24\. Dev' "$LEGACY" "Main menu contains Dev entry"
assert_grep '25\. Tools' "$LEGACY" "Main menu contains Tools entry"

assert_grep 'QUICK ACTIONS' "$LEGACY" "Legacy TOOLS section renamed to QUICK ACTIONS"
assert_grep '23\) open_v1_performance_menu' "$LEGACY" "Numeric route 23 exists"
assert_grep '24\) open_v1_dev_menu' "$LEGACY" "Numeric route 24 exists"
assert_grep '25\) open_v1_tools_menu' "$LEGACY" "Numeric route 25 exists"

echo
echo "All legacy + bridge checks passed."
