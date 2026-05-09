#!/usr/bin/env bash

menu_ai() {
  local choice

  while true; do
    print_header
    print_section "AI Menu"
    print_menu_item "1" "Open AI prompts folder"
    print_menu_item "2" "Open repo root"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_open_ai_prompts_dir ;;
      2) command_open_repo ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
