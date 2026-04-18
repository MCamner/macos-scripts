#!/usr/bin/env bash

open_system_menu() {
  local choice

  while true; do
    print_header
    row_bold "SYSTEM"
    empty_row

    row "OBSERVABILITY"
    row2 " 1. Performance"   " 2. Network"
    row2 " 3. Network Ghost" ""

    empty_row
    row "HEALTH / SAFETY"
    row2 " 4. Doctor"        " 5. Self-check"
    row2 " 6. Debug bundle"  " 7. System check"
    row2 " 8. Vault Scan"    ""

    empty_row
    row "SESSION / CONTROL"
    row2 " 9. Lock screen"   "10. Sleep display"
    row2 "11. Restart Finder" "12. Show date and time"

    empty_row
    row "NAVIGATION"
    row2 "13. Repo folder" "14. Repo in browser"

    empty_row
    row2 " b. Back" " x. Exit"

    print_footer
    printf "${C_TITLE}Select option [1-14,b,x]: ${C_RESET}"

    read -r choice
    echo

    case "$choice" in
      1) open_performance_menu ;;
      2) show_network_info ;;
      3) "$BASE_DIR/tools/scripts/network-ghost.sh"; pause_enter ;;
      4) "$BASE_DIR/tools/scripts/doctor.sh"; pause_enter ;;
      5) run_self_check || true; pause_enter ;;
      6) run_debug_bundle || true; pause_enter ;;
      7) system_check; pause_enter ;;
      8) "$BASE_DIR/tools/scripts/vault-scan.sh"; pause_enter ;;
      9) lock_screen ;;
      10) sleep_display ;;
      11) restart_finder ;;
      12) show_date_time ;;
      13) open_base_dir ;;
      14) open_repo_browser ;;
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

