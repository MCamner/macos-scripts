#!/usr/bin/env bash

print_dev_menu() {
  print_header
  row "PROMPT TOOLS"
  empty_row

  row2 " 1. Open AI Prompts folder" " 2. Show prompt files"
  row2 " 3. Edit mqlaunch" " 4. Backup prompts"
  row2 " 5. Backup mqlaunch" " 6. Open macos-scripts folder"
  row2 " 7. Open launcher folder" " 8. Open mac terminal guide"
  row2 " 9. Git Menu" "10. Net Launch"
  row2 "11. Themes" "12. Tools Menu"
  row2 " b. Back" ""

  print_footer
  printf "${C_TITLE}Select dev option [1-12,b]: ${C_RESET}"
}

handle_dev_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) open_ai_prompts_folder ;;
    2) show_prompt_files ;;
    3) edit_mqlaunch ;;
    4) backup_prompts ;;
    5) backup_mqlaunch ;;
    6) open_base_dir ;;
    7) open_launcher_folder ;;
    8) open_terminal_guide ;;
    9) open_git_menu ;;
    10) net_menu_loop ;;
    11) themes_menu_loop ;;
    12) open_tools_menu ;;
    b|B) return 1 ;;
    *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

dev_menu_loop() {
  local choice

  while true; do
    print_dev_menu
    read -r choice
    echo

    if ! handle_dev_menu_choice "$choice"; then
      break
    fi
  done
}

open_dev_menu() {
  dev_menu_loop
}
