#!/usr/bin/env bash

open_apps_menu() {
  local choice

  while true; do
    print_header
    row_bold "APPS / SHORTCUTS"
    empty_row

    row "APPS"
    row3 " 1. Finder" " 2. Safari" " 3. Google Chrome"
    row3 " 4. Spotify" " 5. Xcode" " 6. System Settings"

    empty_row
    row "FOLDERS"
    row2 " 7. Downloads" " 8. Home"
    row2 " 9. Utilities" "10. Applications"

    empty_row
    row "QUICK ACTIONS"
    row2 "11. Lock screen" "12. Sleep display"
    row2 "13. Restart Finder" "14. Repo in browser"

    empty_row
    row2 " b. Back" " x. Exit"

    print_footer
    read_menu_choice "Select option [1-14,b,x] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) open_app "Finder" ;;
      2) open_app "Safari" ;;
      3) open_app "Google Chrome" ;;
      4) open_app "Spotify" ;;
      5) open_app "Xcode" ;;
      6) open_app "System Settings" ;;
      7) open_downloads_folder ;;
      8) open_home_folder ;;
      9) open_utilities_folder ;;
      10) open_applications_folder ;;
      11) lock_screen ;;
      12) sleep_display ;;
      13) restart_finder ;;
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
