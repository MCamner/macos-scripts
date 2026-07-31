#!/usr/bin/env bash

# Renders the system panel view for terminal output.
render_system_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  surface_panel_header "System" "System" "$width" "$panel_color"
  surface_row "OBSERVABILITY" "$width" "$panel_color"
  surface_split_row "1. Performance" "2. Network" "$width" "$panel_color"
  surface_split_row "3. Network Ghost" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "HEALTH / SAFETY" "$width" "$panel_color"
  surface_split_row "4. Doctor" "5. Self-check" "$width" "$panel_color"
  surface_split_row "6. Debug bundle" "7. System check" "$width" "$panel_color"
  surface_split_row "8. Vault Scan" "9. Overseer" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "SESSION / CONTROL" "$width" "$panel_color"
  surface_split_row "10. Lock screen" "11. Sleep display" "$width" "$panel_color"
  surface_split_row "12. Restart Finder" "13. Show date and time" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MAINTENANCE" "$width" "$panel_color"
  surface_split_row "16. Brew Check" "17. Cleanup" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "NAVIGATION" "$width" "$panel_color"
  surface_split_row "14. Repo folder" "15. Repo in browser" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
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
      2) show_network_info ;;
      # The ghost route returns without pausing, so this arm keeps its pause_enter
      # — unlike the doctor arm below, where the dispatcher owns it.
      3) "$BASE_DIR/bin/mqlaunch" ghost; pause_enter ;;
      # Through the dispatcher, not the script. It owns the pause too, so this
      # arm no longer calls pause_enter — doing both would stop twice.
      4) "$BASE_DIR/bin/mqlaunch" doctor ;;
      # Through the dispatcher, which owns run_self_check and its pause. Calling
      # the function here reached test-all.sh without passing the dispatcher and
      # then paused a second time.
      5) "$BASE_DIR/bin/mqlaunch" self-check ;;
      6) run_debug_bundle || true; pause_enter ;;
      7) system_check; pause_enter ;;
      8) "$BASE_DIR/tools/scripts/vault-scan.sh"; pause_enter ;;
      # `reap` is the dispatcher's name for overseer.sh. That route ends in
      # `return $?` with no pause of its own, so this arm keeps pause_enter.
      9) "$BASE_DIR/bin/mqlaunch" reap; pause_enter ;;
      10) lock_screen ;;
      11) sleep_display ;;
      12) restart_finder ;;
      13) show_date_time ;;
      14) open_base_dir ;;
      15) open_repo_browser ;;
      16) "$BASE_DIR/tools/scripts/brew-check.sh"; pause_enter ;;
      17) "$BASE_DIR/tools/scripts/cleanup.sh"; pause_enter ;;
      b|B|x|X|exit) return ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}
