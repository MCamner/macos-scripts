#!/usr/bin/env bash

command_health_check() {
  print_header
  print_section "System Health Check"

  echo "Hostname: $(scutil --get ComputerName 2>/dev/null || hostname)"
  echo "User:     $(whoami)"
  echo "Shell:    $SHELL"
  echo "Date:     $(date)"
  echo

  print_section "Disk"
  df -h / | tail -1

  print_section "Memory"
  vm_stat | head -10

  print_section "Uptime"
  uptime

  print_section "Network"
  ipconfig getifaddr en0 2>/dev/null || echo "No en0 IP found"

  pause_enter
}

command_lock_screen() {
  /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
}

command_show_date_time() {
  print_header
  print_section "Date & Time"
  date
  pause_enter
}
