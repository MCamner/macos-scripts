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

  print_main_footer
  printf "${C_TITLE}Select option [1-6,p,n,h,a,X]: ${C_RESET}"
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

main_loop() {
  local choice

  while true; do
    print_main_menu
    read -r choice
    echo
    handle_main_menu_choice "$choice"
  done
}
