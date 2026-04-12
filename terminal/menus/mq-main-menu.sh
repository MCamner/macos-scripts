#!/usr/bin/env bash

print_main_menu() {
  print_header
  row_bold "MAIN MENU"
  empty_row

  row "APPS"
  row3 " 1. Finder" " 2. Safari" " 3. Google Chrome"
  row3 " 4. Spotify" " 5. Xcode" " 6. System Settings"
  row3 " 7. Activity Monitor" "" ""

  empty_row
  row "SYSTEM / CONTROL"
  row3 " 8. Downloads folder" " 9. Home folder" "10. Show IP + network"
  row3 "11. Git Menu" "12. Lock screen" "13. Sleep display"

  empty_row
  row "QUICK ACTIONS"
  row3 "14. Utilities folder" "15. Applications folder" "16. Restart Finder"
  row3 "17. Show date and time" "18. Open repo in browser" "19. Run system check"

  empty_row
  row "MENUS"
  row3 "20. AI Modes" "21. Dev / Prompts" "22. Tweaks"

  empty_row
  row "WORKFLOWS"
  row2 "23. Performance" "24. Dev"
  row2 "25. Tools" "26. Release"
  row2 "27. Login / Session" "28. Shortcuts"
  row2 "29. Version" "30. Self-check"
  row2 "31. Debug bundle" "32. Release notes"
  row2 "33. About / Status" "34. Command index"

  print_main_footer
  printf "${C_TITLE}Select option [1-34,X]: ${C_RESET}"
}

handle_main_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) open_app "Finder" ;;
    2) open_app "Safari" ;;
    3) open_app "Google Chrome" ;;
    4) open_app "Spotify" ;;
    5) open_app "Xcode" ;;
    6) open_app "System Settings" ;;
    7) open_app "Activity Monitor" ;;
    8) open_downloads_folder ;;
    9) open_home_folder ;;
    10) show_network_info ;;
    11) open_git_menu ;;
    x|X) echo "Exiting ${APP_TITLE}..."; exit 0 ;;
    12) lock_screen ;;
    13) sleep_display ;;
    14) open_utilities_folder ;;
    15) open_applications_folder ;;
    16) restart_finder ;;
    17) show_date_time ;;
    18) open_repo_browser ;;
    19) system_check ;;
    20) ai_menu_loop ;;
    21) dev_menu_loop ;;
    22) tweaks_menu_loop ;;
    23) open_v1_performance_menu ;;
    24) open_v1_dev_menu ;;
    25) open_v1_tools_menu ;;
    26) open_release_menu ;;
    27) run_mqlogin ;;
    28) run_mqshortcuts ;;
    29) show_version_info ;;
    30) run_self_check || true ;;
    31) run_debug_bundle || true ;;
    32) show_release_notes || true ;;
    33) show_about_dashboard || true ;;
    34) show_command_index || true ;;
    *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
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
