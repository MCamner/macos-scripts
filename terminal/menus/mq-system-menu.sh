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
    row2 " 8. Vault Scan"    " 9. Reap"

    empty_row
    row "SESSION / CONTROL"
    row2 "10. Lock screen"   "11. Sleep display"
    row2 "12. Restart Finder" "13. Show date and time"

    empty_row
    row "NAVIGATION"
    row2 "14. Repo folder" "15. Repo in browser"

    empty_row
    row2 " b. Back" " x. Exit"

    print_footer
    read_menu_choice "Select option [1-15,b,x] > " || return
    choice="$REPLY"
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
      9) "$BASE_DIR/tools/scripts/overseer.sh"; pause_enter ;;
      10) lock_screen ;;
      11) sleep_display ;;
      12) restart_finder ;;
      13) show_date_time ;;
      14) open_base_dir ;;
      15) open_repo_browser ;;
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
