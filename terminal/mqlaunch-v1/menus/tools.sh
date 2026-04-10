#!/usr/bin/env bash

menu_tools() {
  local choice

  while true; do
    print_header
    print_section "Tools Menu"
    print_menu_item "1" "Open Tools Folder"
    print_menu_item "2" "Open Terminal Folder"
    print_menu_item "3" "Open AI Prompts Folder"
    print_menu_item "4" "Open Terminal Guide"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_open_tools_dir ;;
      2) command_open_terminal_dir ;;
      3) command_open_ai_prompts_dir ;;
      4) command_open_terminal_guide ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
