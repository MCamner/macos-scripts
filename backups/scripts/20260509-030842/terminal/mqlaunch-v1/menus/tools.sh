#!/usr/bin/env bash

menu_tools() {
  local choice

  while true; do
    print_header
    print_section "Tools Menu"
    print_menu_item "1" "Open tools root"
    print_menu_item "2" "Open scripts folder"
    print_menu_item "3" "Open CLI folder"
    print_menu_item "4" "Open terminal guide folder"
    print_menu_item "5" "Open terminal guide file"
    print_menu_item "6" "Show tools tree"
    print_menu_item "7" "Show tools summary"
    print_menu_item "8" "Find README files"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_tools_open_tools_root ;;
      2) command_tools_open_scripts_dir ;;
      3) command_tools_open_cli_dir ;;
      4) command_tools_open_guide_dir ;;
      5) command_tools_open_guide_file ;;
      6) command_tools_list_tree ;;
      7) command_tools_repo_summary ;;
      8) command_tools_find_readmes ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
