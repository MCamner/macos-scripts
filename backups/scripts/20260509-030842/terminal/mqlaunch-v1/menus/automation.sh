#!/usr/bin/env bash

menu_automation() {
  local choice

  while true; do
    print_header
    print_section "Automation Menu"
    print_menu_item "1" "Open automation folder"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) open_path "$PROJECT_ROOT/automation" ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
