#!/usr/bin/env bash

menu_system() {
  local choice

  while true; do
    print_header
    print_section "System Menu"
    print_menu_item "1" "Health Check"
    print_menu_item "2" "Show Date & Time"
    print_menu_item "3" "Lock Screen"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_health_check ;;
      2) command_show_date_time ;;
      3) command_lock_screen ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
