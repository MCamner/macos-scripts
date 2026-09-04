#!/usr/bin/env bash

# Renders the system panel view for terminal output.
render_system_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  surface_panel_header "System" "System" "$width" "$panel_color"
  surface_row "OBSERVE" "$width" "$panel_color"
  surface_split_row "1. Performance" "2. Network" "$width" "$panel_color"
  surface_split_row "3. Processes" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "HEALTH" "$width" "$panel_color"
  surface_split_row "4. Doctor" "5. Checks" "$width" "$panel_color"
  surface_split_row "6. Debug bundle" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MAINTAIN" "$width" "$panel_color"
  surface_split_row "7. Maintenance" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "DESKTOP" "$width" "$panel_color"
  surface_split_row "8. Desktop" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "OPEN" "$width" "$panel_color"
  surface_split_row "9. Repo folder" "10. Repo in browser" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}


# The three submenus the grouped front menu opens.
#
# Nothing was dropped: every action the flat sixteen offered is still here. The
# two network rows are the exception, and they were removed rather than moved —
# `show_network_info` and the ghost route are options 1 and 8 of the network
# menu, so copying them here gave two ways to reach two functions and no way to
# reach the other seven. Option 2 opens that menu instead.

# Renders a System submenu panel from a title and its rows.
_system_submenu_panel() {
  local title="$1"; shift
  local width panel_color heading
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  heading="$(printf '%s' "$title" | tr '[:lower:]' '[:upper:]')"

  print_header
  surface_panel_header "$title" "System" "$width" "$panel_color"
  surface_row "$heading" "$width" "$panel_color"
  local row
  for row in "$@"; do
    surface_split_row "$row" "" "$width" "$panel_color"
  done
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the checks submenu.
#
# Three checks that sound alike and are not: self-check runs the test suite,
# system check verifies the install (symlink, PATH, prompt dir), and the vault
# scan reads mqobsidian. Doctor stays on the front menu — it is the exit gate,
# and the one doctor itself recommends when the machine is healthy.
system_checks_menu_loop() {
  local choice
  while true; do
    _system_submenu_panel "Checks" "1. Self-check" "2. System check" "3. Vault scan"
    read_menu_choice "" "checks" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) "$BASE_DIR/bin/mqlaunch" self-check ;;
      2) system_check; pause_enter ;;
      3) "$BASE_DIR/tools/scripts/vault-scan.sh"; pause_enter ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

# Runs the maintenance submenu.
system_maintenance_menu_loop() {
  local choice
  while true; do
    _system_submenu_panel "Maintenance" "1. Brew check" "2. Cleanup" \
      "3. Rotate OpenAI API key"
    read_menu_choice "" "maintenance" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) "$BASE_DIR/tools/scripts/brew-check.sh"; pause_enter ;;
      2) "$BASE_DIR/tools/scripts/cleanup.sh"; pause_enter ;;
      3) "$BASE_DIR/tools/scripts/rotate-openai-key.sh"; pause_enter ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

# Runs the desktop submenu.
#
# Four macOS commands with nothing to do with the MQ stack. They were a third of
# the front menu.
system_desktop_menu_loop() {
  local choice
  while true; do
    _system_submenu_panel "Desktop" "1. Lock screen" "2. Sleep display" \
      "3. Restart Finder" "4. Show date and time"
    read_menu_choice "" "desktop" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) lock_screen ;;
      2) sleep_display ;;
      3) restart_finder ;;
      4) show_date_time ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

# Opens system menu.
open_system_menu() {
  local choice

  while true; do
    print_header
    render_system_panel
    read_menu_choice "" "system" || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) open_performance_menu ;;
      # The whole network menu, not a copy of two of its rows. This used to be
      # `show_network_info` with the ghost route beside it — the two functions
      # the network menu already offers as its options 1 and 8.
      2) open_net_menu ;;
      # `reap` is the dispatcher's name for overseer.sh. That route ends in
      # `return $?` with no pause of its own, so this arm keeps pause_enter.
      3) "$BASE_DIR/bin/mqlaunch" reap; pause_enter ;;
      # Through the dispatcher, not the script. It owns the pause too, so this
      # arm no longer calls pause_enter — doing both would stop twice.
      4) "$BASE_DIR/bin/mqlaunch" doctor ;;
      5) system_checks_menu_loop ;;
      # Stays on the front menu although it is a check: it is reached when
      # something is already wrong and the evidence has to go somewhere, which
      # is the wrong moment to add a keystroke.
      6) run_debug_bundle || true; pause_enter ;;
      7) system_maintenance_menu_loop ;;
      8) system_desktop_menu_loop ;;
      9) open_base_dir ;;
      10) open_repo_browser ;;
      b|B|x|X|exit) return ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}
