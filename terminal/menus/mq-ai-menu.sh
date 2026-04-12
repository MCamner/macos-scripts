#!/usr/bin/env bash

print_ai_menu() {
  print_header
  row "AI MODES"
  empty_row

  row2 " 1. Auto Mode" " 2. Atlas One"
  row2 " 3. Atlas Router" " 4. Decision"
  row2 " 5. Research" " 6. Root Cause"
  row2 " 7. Problem Solving" " 8. Prompt Debugger"
  row2 " 9. AI Menu" " 0. Back"

  print_footer
  printf "${C_TITLE}Select AI mode [0-9]: ${C_RESET}"
}

handle_ai_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) safe_run_ai auto ;;
    2) safe_run_ai one ;;
    3) safe_run_ai atlas ;;
    4) safe_run_ai decide ;;
    5) safe_run_ai research ;;
    6) safe_run_ai root ;;
    7) safe_run_ai solve ;;
    8) safe_run_ai pdebug ;;
    9) safe_run_ai menu ;;
    0) return 1 ;;
    *) echo "${C_ERR}Invalid AI selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

ai_menu_loop() {
  local choice

  while true; do
    print_ai_menu
    read -r choice
    echo

    if ! handle_ai_menu_choice "$choice"; then
      break
    fi
  done
}

open_ai_menu() {
  ai_menu_loop
}
