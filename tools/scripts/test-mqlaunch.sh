#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
LEGACY="$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
V1="$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"
TOOLS_BRIDGE="$PROJECT_ROOT/terminal/bridges/tools-bridge.sh"
DEV_BRIDGE="$PROJECT_ROOT/terminal/bridges/dev-bridge.sh"
PERF_BRIDGE="$PROJECT_ROOT/terminal/bridges/performance-bridge.sh"
RELEASE_SCRIPT="$PROJECT_ROOT/release.sh"
RELEASE_MENU="$PROJECT_ROOT/terminal/menus/mq-release-menu.sh"

# Marks a passing check.
pass() {
  echo "[PASS] $1"
}

# Marks a failing check.
fail() {
  echo "[FAIL] $1"
  exit 1
}

# Coordinates assert file behavior.
assert_file() {
  local path="$1"
  local label="$2"
  [[ -f "$path" ]] || fail "$label missing: $path"
  pass "$label exists"
}

# Coordinates assert grep behavior.
assert_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -qE "$pattern" "$file" || fail "$label"
  pass "$label"
}

# Coordinates assert absent grep behavior.
assert_not_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -qE "$pattern" "$file" && fail "$label"
  pass "$label"
}

# Coordinates assert cmd ok behavior.
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
assert_file "$RELEASE_SCRIPT" "Release script"

assert_cmd_ok "Legacy launcher help works" zsh "$LEGACY" help
assert_cmd_ok "V1 launcher help works" bash "$V1" help

assert_grep 'perf\|performance\).*open_performance_menu' "$LEGACY" "Performance route exists in launcher"
assert_grep 'dev\).*open_dev_menu' "$LEGACY" "Dev route exists in launcher"
assert_not_grep 'mqlaunch-v1' "$DEV_BRIDGE" "Dev bridge is decommissioned from v1"
assert_grep 'tools\) open_tools_menu' "$LEGACY" "Tools route exists in launcher"
assert_grep 'restart\|reload\|relaunch\).*restart_mqlaunch' "$LEGACY" "mqlaunch restart route exists"
assert_grep 'tools-menu\|toolsmenu\|menu-tools\|tools-v1\|menu-tools-v1\)' "$LEGACY" "Legacy Tools aliases still exist"
assert_grep 'terminal/launchers/gitlaunch\.sh' "$PROJECT_ROOT/mqlaunch/lib/git-menus.sh" "Git route uses gitlaunch"
assert_grep 'RELEASE_SCRIPT="\$RELEASE_REPO/release\.sh"' "$RELEASE_MENU" "Release menu points at root release script"

assert_grep 'render_main_menu_panel' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu panel exists"
assert_grep 'surface_top "Main Menu"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu panel has title"
assert_grep 'surface_split_row "1\. Workflows" "2\. System"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Workflows and System"
assert_grep 'surface_split_row "3\. Git" "4\. Release"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Git and Release"
assert_grep 'surface_split_row "5\. Dev" "6\. Repos"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Dev and Repos"
assert_grep 'surface_split_row "p\. Performance" "n\. Network"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Performance and Network quick access"
assert_grep 'surface_split_row "h\. Health Check" "z\. Restart mqlaunch"' "$PROJECT_ROOT/terminal/menus/mq-main-menu.sh" "Main menu contains Health Check and Restart quick access"
assert_grep 'render_help_center_panel' "$PROJECT_ROOT/terminal/menus/mq-help-center-menu.sh" "Help center panel exists"
assert_grep 'surface_top "Help"' "$PROJECT_ROOT/terminal/menus/mq-help-center-menu.sh" "Help center uses surface panel"
assert_grep 'surface_split_row "1\. Command index" "2\. About / Status"' "$PROJECT_ROOT/terminal/menus/mq-help-center-menu.sh" "Help center contains reference actions"
assert_grep 'surface_panel_header "System"' "$PROJECT_ROOT/terminal/menus/mq-system-menu.sh" "System menu uses surface panel"
assert_grep 'surface_panel_header "Prompt Tools"' "$PROJECT_ROOT/terminal/menus/mq-dev-menu.sh" "Dev menu uses surface panel"
assert_grep 'surface_split_row "9\. Network Tools" "10\. Themes"' "$PROJECT_ROOT/terminal/menus/mq-dev-menu.sh" "Dev menu links to Network Tools"
assert_grep 'surface_panel_header "AI Modes"' "$PROJECT_ROOT/terminal/menus/mq-ai-menu.sh" "AI menu uses surface panel"
assert_grep 'surface_panel_header "Network"' "$PROJECT_ROOT/terminal/menus/mq-net-menu.sh" "Network menu uses surface panel"
assert_grep 'surface_row "STATUS"' "$PROJECT_ROOT/terminal/menus/mq-net-menu.sh" "Network menu groups status actions"
assert_grep 'surface_split_row "1\. Network overview" "2\. Connectivity test"' "$PROJECT_ROOT/terminal/menus/mq-net-menu.sh" "Network menu has overview and connectivity"
assert_grep 'surface_split_row "7\. Network quality" "8\. Network ghost"' "$PROJECT_ROOT/terminal/menus/mq-net-menu.sh" "Network menu exposes quality and ghost tools"
assert_grep 'surface_panel_header "Apps / Shortcuts"' "$PROJECT_ROOT/terminal/menus/mq-apps-menu.sh" "Apps menu uses surface panel"
assert_grep 'surface_panel_header "Release"' "$PROJECT_ROOT/terminal/menus/mq-release-menu.sh" "Release menu uses surface panel"
assert_grep 'surface_panel_header "Tools Menu"' "$PROJECT_ROOT/terminal/menus/mq-tools-menu.sh" "Tools menu uses surface panel"
assert_grep 'surface_panel_header "Workflows"' "$PROJECT_ROOT/terminal/menus/mq-workflows-menu.sh" "Workflows menu uses surface panel"
assert_grep 'surface_panel_header "Shortcuts"' "$PROJECT_ROOT/terminal/menus/mq-shortcuts-menu.sh" "Shortcuts menu uses surface panel"
assert_grep 'surface_panel_header "Login"' "$PROJECT_ROOT/terminal/menus/mq-login-menu.sh" "Login menu uses surface panel"

echo
echo "All legacy + bridge checks passed."
