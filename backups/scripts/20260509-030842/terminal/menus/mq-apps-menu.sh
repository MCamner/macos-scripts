#!/usr/bin/env bash

render_apps_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  surface_panel_header "Apps / Shortcuts" "Apps" "$width" "$panel_color"
  surface_row "APPS" "$width" "$panel_color"
  surface_split_row "1. Finder" "2. Safari" "$width" "$panel_color"
  surface_split_row "3. Google Chrome" "4. Spotify" "$width" "$panel_color"
  surface_split_row "5. Xcode" "6. System Settings" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "FOLDERS" "$width" "$panel_color"
  surface_split_row "7. Downloads" "8. Home" "$width" "$panel_color"
  surface_split_row "9. Utilities" "10. Applications" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "QUICK ACTIONS" "$width" "$panel_color"
  surface_split_row "11. Lock screen" "12. Sleep display" "$width" "$panel_color"
  surface_split_row "13. Restart Finder" "14. Repo in browser" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "x. Exit" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

open_apps_menu() {
  local choice

  while true; do
    print_header
    render_apps_panel
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice || return
    else
      printf "\nmqlaunch > "
      read -r choice
    fi
    echo

    case "$choice" in
      1) open_app "Finder" ;;
      2) open_app "Safari" ;;
      3) open_app "Google Chrome" ;;
      4) open_app "Spotify" ;;
      5) open_app "Xcode" ;;
      6) open_app "System Settings" ;;
      7) open_downloads_folder ;;
      8) open_home_folder ;;
      9) open_utilities_folder ;;
      10) open_applications_folder ;;
      11) lock_screen ;;
      12) sleep_display ;;
      13) restart_finder ;;
      14) open_repo_browser ;;
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
