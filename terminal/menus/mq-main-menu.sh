#!/usr/bin/env bash

print_main_menu() {
  print_header
  row_bold "MAIN MENU"
  empty_row

  row "CORE"
  row2 " 1. Workflows" " 2. System"
  row2 " 3. Git" " 4. Release"
  row2 " 5. Dev" " 6. Help"

  empty_row
  row "QUICK ACCESS"
  row2 " p. Performance" " n. Network"
  row2 " h. Health Check" " a. Apps"

  empty_row
  local USER_NAME HOST_NAME TIME SURFACE_COLOR
  USER_NAME="${USER:-$(whoami)}"
  HOST_NAME="$(hostname -s)"
  TIME="$(date '+%Y-%m-%d %H:%M:%S')"
  if [[ -t 1 ]]; then
    SURFACE_COLOR=$'\033[0;37m'
  else
    SURFACE_COLOR=""
  fi

  surface_top() {
    local title="$1"
    local width=80
    local fill=$(( width - 5 - ${#title} ))
    (( fill < 0 )) && fill=0
    printf "%b┌─ %s %s┐%b\n" "$SURFACE_COLOR" "$title" "$(repeat_char "$fill" "─")" "$C_RESET"
  }

  surface_bottom() {
    printf "%b└%s┘%b\n" "$SURFACE_COLOR" "$(repeat_char 78 "─")" "$C_RESET"
  }

  surface_dual_row() {
    printf "%b│ %-41.41s %-34.34s │%b\n" "$SURFACE_COLOR" "$1" "$2" "$C_RESET"
  }

  surface_top "Command Surface"
  surface_dual_row "Welcome back ${USER_NAME}!" "Tips for getting started"
  surface_dual_row " " "Run help to see index"

  printf "%b│ %-16s%s%-17s %-34s │%b\n" "$SURFACE_COLOR" " " "▄▄████▄▄" " " " " "$C_RESET"
  printf "%b│ %-16s%s%-17s %-34s │%b\n" "$SURFACE_COLOR" " " "████████" " " "System: Stable" "$C_RESET"
  printf "%b│ %-16s%s%-17s %-34s │%b\n" "$SURFACE_COLOR" " " "██▄██▄██" " " " " "$C_RESET"
  printf "%b│ %-16s%s%-17s %-34s │%b\n" "$SURFACE_COLOR" " " " ▄█▀▀█▄ " " " "Activity: Monitoring" "$C_RESET"

  surface_dual_row "Host: ${HOST_NAME}" "User: ${USER_NAME}"
  surface_dual_row "Time: ${TIME}" "X. Exit launcher"
  surface_bottom
}

handle_main_menu_choice() {
  local choice="$1"

  case "$choice" in
    # CORE
    1) run_mqworkflows ;;
    2) open_system_menu ;;
    3) open_git_menu ;;
    4) open_release_menu ;;
    5) open_dev_menu ;;
    6) open_help_center_menu ;;

    # QUICK ACCESS
    p|P) open_performance_menu ;;
    n|N) show_network_info ;;
    h|H) system_check ;;
    a|A) open_apps_menu ;;

    # EXIT
    x|X)
      echo "Exiting ${APP_TITLE}..."
      exit 0
      ;;

    *)
      echo "${C_ERR}Invalid selection:${C_RESET} $choice"
      pause_enter
      ;;
  esac
}

read_main_choice() {
  read_prompt "${C_TITLE}mqlaunch > ${C_RESET}" "mqlaunch > "
  choice="$REPLY"
}

main_loop() {
  local choice

  while true; do
    print_main_menu
    read_main_choice || return
    echo
    handle_main_menu_choice "$choice"
  done
}
