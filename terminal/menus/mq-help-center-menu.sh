#!/usr/bin/env bash

open_help_center_menu() {
  local choice

  while true; do
    print_header
    row_menu_title "HELP"
    empty_row

    row "REFERENCE"
    row2 " 1. Command index" " 2. About / Status"

    empty_row
    row "INFO"
    row2 " 3. Version" " 4. Release Notes"

    empty_row
    row "SUPPORT"
    row2 " 5. Repo in browser" " 6. Repo folder"

    empty_row
    row2 " b. Back" " x. Exit"

    print_footer
    read_menu_choice "Select option [1-6,b,x] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) show_command_index || true ;;
      2) show_about_dashboard || true ;;
      3) show_version_info || true ;;
      4) show_release_notes || true ;;
      5) open_repo_browser ;;
      6) open_base_dir ;;
      b|B) return ;;
      x|X)
        echo "Exiting ${APP_TITLE}..."
        exit 0
        ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}
