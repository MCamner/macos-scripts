#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

APP_TITLE="MQ Tools Menu"
APP_SUBTITLE="Reusable Terminal Module"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

SYSTEM_CHECK="$BASE_DIR/tools/scripts/system-check.sh"
MQLAUNCH="$BASE_DIR/terminal/launchers/mqlaunch.sh"
DASHBOARD="$BASE_DIR/ui/dashboards/mq-dashboard.sh"
THEMES_DIR="$BASE_DIR/terminal/themes"
LAUNCHERS_DIR="$BASE_DIR/terminal/launchers"
MENUS_DIR="$BASE_DIR/terminal/menus"
GUIDE_HTML="$BASE_DIR/tools/mac-terminal-guide/mac-terminal-guide.html"
GUIDE_URL="https://mcamner.github.io/macos-scripts/"

run_system_check() {
  if [[ -x "$SYSTEM_CHECK" ]]; then
    "$SYSTEM_CHECK"
  else
    print_header
    row "SYSTEM CHECK"
    empty_row
    row "system-check.sh not found or not executable:"
    row " $SYSTEM_CHECK"
    print_footer
    pause_enter
  fi
}

open_repo() {
  open "$BASE_DIR"
}

open_launchers() {
  open "$LAUNCHERS_DIR"
}

open_themes() {
  open "$THEMES_DIR"
}

open_menus() {
  open "$MENUS_DIR"
}

open_dashboard() {
  if [[ -x "$DASHBOARD" ]]; then
    bash "$DASHBOARD" menu
  elif [[ -f "$DASHBOARD" ]]; then
    chmod +x "$DASHBOARD" 2>/dev/null || true
    bash "$DASHBOARD" menu
  else
    print_header
    row "DASHBOARD"
    empty_row
    row "Dashboard script missing:"
    row " $DASHBOARD"
    print_footer
    pause_enter
  fi
}

open_guide() {
  if [[ -f "$GUIDE_HTML" ]]; then
    open "$GUIDE_HTML"
  else
    open "$GUIDE_URL"
  fi
}

show_paths() {
  print_header
  row_bold "KEY PATHS"
  empty_row

  row "BASE_DIR"
  row " $BASE_DIR"
  empty_row

  row "MQLAUNCH"
  row " $MQLAUNCH"
  empty_row

  row "DASHBOARD"
  row " $DASHBOARD"
  empty_row

  row "THEMES DIR"
  row " $THEMES_DIR"
  empty_row

  row "MENUS DIR"
  row " $MENUS_DIR"

  print_footer
  pause_enter
}

show_git_status() {
  print_header
  row_bold "GIT STATUS"
  empty_row

  if [[ -d "$BASE_DIR/.git" ]]; then
    git -C "$BASE_DIR" status --short --branch || true
  else
    row "Not a git repository:"
    row " $BASE_DIR"
  fi

  print_footer
  pause_enter
}

print_menu() {
  print_header
  row_bold "TOOLS MENU"
  empty_row

  row2 " 1. Run system check" " 2. Open repo folder"
  row2 " 3. Open launchers folder" " 4. Open themes folder"
  row2 " 5. Open menus folder" " 6. Open dashboard"
  row2 " 7. Open terminal guide" " 8. Show key paths"
  row2 " 9. Show git status" "10. Boot Maker"
  row2 "11. Blackout Mode" ""
  row2 " b. Back" ""

  print_footer
}

menu_loop() {
  local choice

  while true; do
    print_menu
    read_menu_choice "Select option [1-11,b] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) run_system_check ;;
      2) open_repo ;;
      3) open_launchers ;;
      4) open_themes ;;
      5) open_menus ;;
      6) open_dashboard ;;
      7) open_guide ;;
      8) show_paths ;;
      9) show_git_status ;;
    10) "$BASE_DIR/tools/cli/boot-maker.sh"; pause_enter ;;
    11) "$BASE_DIR/tools/scripts/blackout.sh"; pause_enter ;;
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-tools-menu.sh - reusable tools menu

Usage:
  mq-tools-menu.sh [command]

Commands:
  menu        Open menu (default)
  check       Run system check
  dashboard   Open dashboard
  guide       Open terminal guide
  paths       Show key paths
  git         Show git status
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    check) run_system_check ;;
    dashboard) open_dashboard ;;
    guide) open_guide ;;
    paths) show_paths ;;
    git) show_git_status ;;
    help|-h|--help) usage ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

main "${1:-menu}"
