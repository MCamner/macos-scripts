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

assert_grep 'perf\|performance\).*open_performance_menu' "$LEGACY" "Performance route exists in launcher"
assert_grep 'dev\).*open_dev_menu' "$LEGACY" "Dev route exists in launcher"
assert_grep 'tools\) open_tools_menu' "$LEGACY" "Tools route exists in launcher"
assert_grep 'tools-menu\|toolsmenu\|menu-tools\|tools-v1\|menu-tools-v1\)' "$LEGACY" "Legacy Tools aliases still exist"

assert_grep 'render_main_menu_panel' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu panel exists"
assert_grep 'surface_top "Main Menu"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu panel has title"
assert_grep 'surface_split_row "1\. Workflows" "2\. System"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Workflows and System"
assert_grep 'surface_split_row "3\. Git" "4\. Release"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Git and Release"
assert_grep 'surface_split_row "5\. Dev" "6\. Help"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Dev and Help"
assert_grep 'surface_split_row "p\. Performance" "n\. Network"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Performance and Network quick access"
assert_grep 'surface_split_row "h\. Health Check" "a\. Apps"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Health Check and Apps quick access"

echo
echo "All legacy + bridge checks passed."
