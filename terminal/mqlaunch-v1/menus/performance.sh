#!/usr/bin/env bash

menu_performance() {
  local choice

  while true; do
    print_header
    print_section "Performance Menu"
    print_menu_item "1" "Overview"
    print_menu_item "2" "Health score"
    print_menu_item "3" "Top CPU processes"
    print_menu_item "4" "Top memory processes"
    print_menu_item "5" "Disk usage"
    print_menu_item "6" "Network overview"
    print_menu_item "7" "Battery status"
    print_menu_item "8" "Create performance snapshot"
    print_menu_item "9" "Quick watch"
    print_menu_item "b" "Back"
    print_footer_hint

    printf "\n> "
    read -r choice

    case "$choice" in
      1) command_perf_overview ;;
      2) command_perf_health_score ;;
      3) command_perf_cpu_top ;;
      4) command_perf_mem_top ;;
      5) command_perf_disk_usage ;;
      6) command_perf_network ;;
      7) command_perf_battery ;;
      8) command_perf_snapshot ;;
      9) command_perf_quick_watch ;;
      b|B|back) break ;;
      *) warn "Unknown choice: $choice"; sleep 1 ;;
    esac
  done
}
