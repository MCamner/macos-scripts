#!/usr/bin/env bash

command_run_login_boot() {
  local login_menu="$PROJECT_ROOT/terminal/menus/mq-login-menu.sh"
  local login_script="$PROJECT_ROOT/automation/login/mqlogin.sh"

  if [[ $# -eq 0 && -x "$login_menu" ]]; then
    "$login_menu" menu
    return $?
  fi

  if [[ ! -x "$login_script" ]]; then
    print_header
    print_section "Login Boot"
    echo "Missing or non-executable script:"
    echo " $login_script"
    echo
    echo "Run:"
    echo " chmod +x $login_script"
    pause_enter
    return 1
  fi

  "$login_script" "$@"
}
