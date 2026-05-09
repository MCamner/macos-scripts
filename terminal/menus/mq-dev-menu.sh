#!/usr/bin/env bash

# Prints dev menu.
print_dev_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Prompt Tools" "Dev" "$width" "$panel_color"
  surface_row "PROMPTS" "$width" "$panel_color"
  surface_split_row "1. Open AI Prompts folder" "2. Show prompt files" "$width" "$panel_color"
  surface_split_row "3. Edit mqlaunch" "4. Backup prompts" "$width" "$panel_color"
  surface_split_row "5. Backup mqlaunch" "6. Open macos-scripts folder" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "NAVIGATION" "$width" "$panel_color"
  surface_split_row "7. Open launcher folder" "8. HAL terminal guide" "$width" "$panel_color"
  surface_split_row "9. Git Menu" "10. Net Launch" "$width" "$panel_color"
  surface_split_row "11. Themes" "12. Tools Menu" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Handles handle dev menu choice.
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
    8) "$BASE_DIR/tools/scripts/hal-terminal-guide.sh" ;;
    9) open_git_menu ;;
    10) net_menu_loop ;;
    11) open_themes_menu ;;
    12) open_tools_menu ;;
    b|B) return 1 ;;
    *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

# Handles dev menu loop.
dev_menu_loop() {
  local choice

  while true; do
    print_dev_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice || break
    else
      printf "\nmqlaunch > "
      read -r choice
    fi
    echo

    if ! handle_dev_menu_choice "$choice"; then
      break
    fi
  done
}

# Opens dev menu.
open_dev_menu() {
  dev_menu_loop
}
