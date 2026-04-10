#!/usr/bin/env bash

menu_dev() {
  local choice

  while true; do
    print_header
    print_section "Dev Menu"
    print_menu_item "1" "Git Status"
    print_menu_item "2" "Git Pull"
    print_menu_item "3" "Git Push"
    print_menu_item "4" "Edit mqlaunch"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_git_status ;;
      2) command_git_pull ;;
      3) command_git_push ;;
      4) command_edit_mqlaunch ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
