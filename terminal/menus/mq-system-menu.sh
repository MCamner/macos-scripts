#!/usr/bin/env bash

open_system_menu() {
  local choice

  while true; do
    print_header
    row_bold "SYSTEM"
    empty_row

    row "OBSERVABILITY"
    row2 " 1. Performance" " 2. Network"

    empty_row
    row "HEALTH / SAFETY"
    row2 " 3. Doctor / Check" " 4. Self-check"
    row2 " 5. Debug bundle"   " 6. System check"

    empty_row
    row "SESSION / CONTROL"
    row2 " 7. Lock screen"    " 8. Sleep display"
    row2 " 9. Restart Finder" "10. Show date and time"

    empty_row
    row "NAVIGATION"
    row2 "11. Repo folder" "12. Repo in browser"

    empty_row
    row2 " b. Back" " x. Exit"

    print_footer
    printf "${C_TITLE}Select option [1-12,b,x]: ${C_RESET}"

    read -r choice
    echo

    case "$choice" in
      1) open_performance_menu ;;
      2) show_network_info ;;
      3) system_check ;;
      4) run_self_check || true ;;
      5) run_debug_bundle || true ;;
      6) system_check ;;
      7) lock_screen ;;
      8) sleep_display ;;
      9) restart_finder ;;
      10) show_date_time ;;
      11) open_base_dir ;;
      12) open_repo_browser ;;
      b|B) return ;;
      x|X)
        echo "Exiting ${APP_TITLE}..."
        exit 0
        ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}
