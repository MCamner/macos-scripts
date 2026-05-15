#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-${HOME}/macos-scripts}"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
LOGIN_SCRIPT="$BASE_DIR/automation/login/mqlogin.sh"

APP_TITLE="MQ Login"
APP_SUBTITLE="Login and Session Boot"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

# Handles require login script.
require_login_script() {
  if [[ ! -x "$LOGIN_SCRIPT" ]]; then
    print_header
    row_bold "LOGIN"
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

# Runs login mode.
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

# Runs login inline menu.
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

# Runs quiet inline menu.
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

# Shows login help.
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

# Prints menu.
print_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Login" "Login" "$width" "$panel_color"
  surface_row "SESSION" "$width" "$panel_color"
  surface_split_row "1. Start session menu" "2. Start session about" "$width" "$panel_color"
  surface_split_row "3. Start session check" "4. Inline menu session" "$width" "$panel_color"
  surface_split_row "5. Inline about session" "6. Quiet inline menu" "$width" "$panel_color"
  surface_split_row "7. Quiet inline about" "8. Show mqlogin help" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the menu loop.
login_menu_loop() {
  local choice

  while true; do
    print_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "login" || return
    else
      printf "\nlogin > "; read -r choice
    fi
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
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints usage information.
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

# Runs the main entry point.
main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) login_menu_loop ;;
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

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]] || [[ -z "${ZSH_VERSION:-}" && "${0}" == *mq-login-menu* ]]; then
  main "${1:-menu}"
fi
