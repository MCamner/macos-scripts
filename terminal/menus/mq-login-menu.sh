#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
LOGIN_SCRIPT="$BASE_DIR/automation/login/mqlogin.sh"

APP_TITLE="MQ Login"
APP_SUBTITLE="Session Boot Menu"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

require_login_script() {
  if [[ ! -x "$LOGIN_SCRIPT" ]]; then
    print_header
    row_bold "LOGIN / SESSION"
    empty_row
    row "Missing or non-executable script:"
    row " $LOGIN_SCRIPT"
    row "Run:"
    row " chmod +x $LOGIN_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

run_login_mode() {
  local title="$1"
  shift

  require_login_script || return 1

  print_header
  row_bold "$title"
  empty_row
  row "Starting session flow..."
  print_footer

  "$LOGIN_SCRIPT" "$@"
}

run_login_inline_menu() {
  local mode="$1"

  require_login_script || return 1

  print_header
  row_bold "INLINE SESSION"
  empty_row
  row "Mode: $mode"
  row "Running in current terminal."
  print_footer

  "$LOGIN_SCRIPT" "$mode" --inline
  pause_enter
}

run_quiet_inline_menu() {
  local mode="$1"

  require_login_script || return 1

  print_header
  row_bold "QUIET INLINE SESSION"
  empty_row
  row "Mode: $mode"
  row "No Finder, Code, or Terminal windows."
  print_footer

  "$LOGIN_SCRIPT" "$mode" --inline --no-finder --no-code --no-terminal
  pause_enter
}

show_login_help() {
  require_login_script || return 1

  print_header
  row_bold "MQLOGIN HELP"
  empty_row

  if ! "$LOGIN_SCRIPT" --help; then
    echo
    row "mqlogin help failed."
  fi

  print_footer
  pause_enter
}

print_menu() {
  print_header
  row_bold "LOGIN / SESSION MENU"
  empty_row

  row2 " 1. Start session menu" " 2. Start session about"
  row2 " 3. Start session check" " 4. Inline menu session"
  row2 " 5. Inline about session" " 6. Quiet inline menu"
  row2 " 7. Quiet inline about" " 8. Show mqlogin help"
  row2 " 0. Back" ""

  print_footer
  printf "${C_TITLE}Select option [0-8]: ${C_RESET}"
}

menu_loop() {
  local choice

  while true; do
    print_menu
    read -r choice
    echo

    case "$choice" in
      1) run_login_mode "SESSION MENU" menu ;;
      2) run_login_mode "SESSION ABOUT" about ;;
      3) run_login_mode "SESSION CHECK" check ;;
      4) run_login_inline_menu menu ;;
      5) run_login_inline_menu about ;;
      6) run_quiet_inline_menu menu ;;
      7) run_quiet_inline_menu about ;;
      8) show_login_help ;;
      0) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-login-menu.sh - interactive login/session menu

Usage:
  mq-login-menu.sh [command]

Commands:
  menu      Open menu (default)
  start     Start normal session menu
  about     Start session in about mode
  check     Start session in check mode
  inline    Start inline menu session
  help      Show this help
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    start) run_login_mode "SESSION MENU" menu ;;
    about) run_login_mode "SESSION ABOUT" about ;;
    check) run_login_mode "SESSION CHECK" check ;;
    inline) run_login_inline_menu menu ;;
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
