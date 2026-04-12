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
  row3 "11. Repo folder" "12. Lock screen" "13. Sleep display"

  empty_row
  row "QUICK ACTIONS"
  row3 "14. Utilities folder" "15. Applications folder" "16. Restart Finder"
  row3 "17. Show date and time" "18. Open repo in browser" "19. Run system check"

  empty_row
  row "MENUS"
  row3 "20. AI Modes" "21. Prompt Tools" "22. Tweaks"

  empty_row
  row "WORKFLOWS"
  row2 "23. Git" "24. Performance"
  row2 "25. Dev Tools" "26. Tools"
  row2 "27. Project workflows" "28. Release"
  row2 "29. Login / Session" "30. Shortcuts"
  row2 "31. Version" "32. Self-check"
  row2 "33. Debug bundle" "34. Release Notes"
  row2 "35. About / Status" "36. Command index"

  print_main_footer
  printf "${C_TITLE}Select option [1-36,X]: ${C_RESET}"
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
    11) open_base_dir ;;
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
    23) open_git_menu ;;
    24) open_v1_performance_menu ;;
    25) open_v1_dev_menu ;;
    26) open_v1_tools_menu ;;
    27) run_mqworkflows ;;
    28) open_release_menu ;;
    29) run_mqlogin ;;
    30) run_mqshortcuts ;;
    31) show_version_info ;;
    32) run_self_check || true ;;
    33) run_debug_bundle || true ;;
    34) show_release_notes || true ;;
    35) show_about_dashboard || true ;;
    36) show_command_index || true ;;
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
