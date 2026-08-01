#!/usr/bin/env bash

# Renders the apps panel view for terminal output.
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
  surface_row "QUICK ACTIONS" "$width" "$panel_color"
  surface_split_row "7. Lock screen" "8. Sleep display" "$width" "$panel_color"
  surface_split_row "9. Restart Finder" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MORE" "$width" "$panel_color"
  surface_split_row "10. Folders and shortcuts" "b. Back" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Renders the folders-and-shortcuts submenu.
#
# The four folders were rows 7-10 on the front panel and "Repo in browser" and
# "Excalidraw" were 14 and 15. They group because none of them opens an app:
# each one takes you somewhere — a directory in Finder, the repo on GitHub, a
# drawing surface — rather than launching something on this machine.
render_apps_more_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  surface_panel_header "Folders and shortcuts" "Apps" "$width" "$panel_color"
  surface_row "FOLDERS" "$width" "$panel_color"
  surface_split_row "1. Downloads" "2. Home" "$width" "$panel_color"
  surface_split_row "3. Utilities" "4. Applications" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "SHORTCUTS" "$width" "$panel_color"
  surface_split_row "5. Repo in browser" "6. Excalidraw" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the folders-and-shortcuts submenu loop.
open_apps_more_menu() {
  local choice

  while true; do
    print_header
    render_apps_more_panel
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "apps" || return
    else
      printf "\napps > "
      read -r choice
    fi
    echo

    case "$choice" in
      1) open_downloads_folder ;;
      2) open_home_folder ;;
      3) open_utilities_folder ;;
      4) open_applications_folder ;;
      5) open_repo_browser ;;
      # The dispatcher routes this script too. Its route does not pause, so this
      # arm keeps pause_enter.
      6) "$BASE_DIR/bin/mqlaunch" excalidraw; pause_enter ;;
      b|B|x|X|exit) return ;;
      "") ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}

# Opens apps menu.
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
      7) lock_screen ;;
      8) sleep_display ;;
      9) restart_finder ;;
      10) open_apps_more_menu ;;
      b|B|x|X|exit) return ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}
