#!/usr/bin/env bash

# Prints net menu.
print_net_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Network" "Network" "$width" "$panel_color"
  surface_row "TOOLS" "$width" "$panel_color"
  surface_split_row "1. Show IP + network info" "2. Ping test" "$width" "$panel_color"
  surface_split_row "3. Show DNS + gateway" "4. Open Network Settings" "$width" "$panel_color"
  surface_split_row "5. Copy IP info to clipboard" "6. Port scan" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Handles handle net menu choice.
handle_net_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) show_network_info ;;
    2) ping_test ;;
    3) show_dns_gateway ;;
    4) open_network_settings ;;
    5) copy_network_info ;;
    6) "$BASE_DIR/tools/scripts/port-scan.sh"; pause_enter ;;
    b|B) return 1 ;;
    *) echo "${C_ERR}Invalid net selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

# Handles net menu loop.
net_menu_loop() {
  local choice

  while true; do
    print_net_menu
    read_menu_choice "" "network"
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
