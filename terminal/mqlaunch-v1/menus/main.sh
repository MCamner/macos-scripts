#!/usr/bin/env bash

menu_main() {
  local choice

  while true; do
    print_header
    print_section "Main Menu"
    print_menu_item "1" "System"
    print_menu_item "2" "Tools"
    print_menu_item "3" "Automation"
    print_menu_item "4" "Dev"
    print_menu_item "5" "AI"
    print_menu_item "6" "Performance"
    print_menu_item "7" "Health Check"
    print_menu_item "8" "Open Repo"
    print_menu_item "9" "Open Terminal Guide"
    print_menu_item "x" "Exit"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) menu_system ;;
      2) menu_tools ;;
      3) menu_automation ;;
      4) menu_dev ;;
      5) menu_ai ;;
      6) menu_performance ;;
      7) command_health_check ;;
      8) command_open_repo ;;
      9) command_open_terminal_guide ;;
      x|X|exit|quit) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
