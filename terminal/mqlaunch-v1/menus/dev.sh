#!/usr/bin/env bash

menu_dev() {
  local choice

  while true; do
    print_header
    print_section "Dev Menu"
    print_menu_item "1" "Repo health"
    print_menu_item "2" "Git status"
    print_menu_item "3" "Git pull"
    print_menu_item "4" "Git push"
    print_menu_item "5" "Recent commits"
    print_menu_item "6" "Current branch"
    print_menu_item "7" "Open repo root"
    print_menu_item "8" "Open terminal folder"
    print_menu_item "9" "Open tools folder"
    print_menu_item "10" "Open AI prompts folder"
    print_menu_item "11" "Edit v1 launcher"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_dev_repo_health ;;
      2) command_git_status ;;
      3) command_git_pull ;;
      4) command_git_push ;;
      5) command_git_log_recent ;;
      6) command_git_branch_current ;;
      7) command_repo_open_root ;;
      8) command_repo_open_terminal ;;
      9) command_repo_open_tools ;;
      10) command_repo_open_ai_prompts ;;
      11) command_edit_v1_launcher ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
