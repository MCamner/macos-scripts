#!/usr/bin/env bash

# Prints net menu.
print_net_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Network" "Network" "$width" "$panel_color"
  surface_row "STATUS" "$width" "$panel_color"
  surface_split_row "1. Network overview" "2. Connectivity test" "$width" "$panel_color"
  surface_split_row "3. DNS + gateway" "4. Wi-Fi / netpulse diagnostic" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "TOOLS" "$width" "$panel_color"
  surface_split_row "5. Copy network report" "6. Port scan" "$width" "$panel_color"
  surface_split_row "7. Network quality" "8. Network ghost" "$width" "$panel_color"
  surface_split_row "9. Open Network Settings" "b. Back" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Routes the net menu selection to the matching action.
handle_net_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) show_network_info ;;
    2) ping_test ;;
    3) show_dns_gateway ;;
    4) run_network_pulse ;;
    5) copy_network_info ;;
    6) "$BASE_DIR/tools/scripts/port-scan.sh"; pause_enter ;;
    7) run_network_quality ;;
    8) run_network_ghost ;;
    9) open_network_settings ;;
    b|B|x|X|exit) return 1 ;;
    *) echo "${C_ERR}Invalid net selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

# Keeps the net menu interactive until the user backs out.
net_menu_loop() {
  local choice

  while true; do
    print_net_menu
    read_menu_choice "" "network" || return
    choice="$REPLY"
    echo

    if ! handle_net_menu_choice "$choice"; then
      break
    fi
  done
}

# Opens net menu.
open_net_menu() {
  net_menu_loop
}
