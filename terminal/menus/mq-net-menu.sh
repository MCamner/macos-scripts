#!/usr/bin/env bash

print_net_menu() {
  print_header
  row "NET LAUNCH"
  empty_row

  row2 " 1. Show IP + network info" " 2. Ping test"
  row2 " 3. Show DNS + gateway" " 4. Open Network Settings"
  row2 " 5. Copy IP info to clipboard" " 0. Back"

  print_footer
  printf "${C_TITLE}Select net option [0-5]: ${C_RESET}"
}

handle_net_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) show_network_info ;;
    2) ping_test ;;
    3) show_dns_gateway ;;
    4) open_network_settings ;;
    5) copy_network_info ;;
    0) return 1 ;;
    *) echo "${C_ERR}Invalid net selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

net_menu_loop() {
  local choice

  while true; do
    print_net_menu
    read -r choice
    echo

    if ! handle_net_menu_choice "$choice"; then
      break
    fi
  done
}

open_net_menu() {
  net_menu_loop
}
