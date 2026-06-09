#!/usr/bin/env bash

# Prints ai menu.
print_ai_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "AI Modes" "AI" "$width" "$panel_color"
  surface_row "MODES" "$width" "$panel_color"
  surface_split_row "1. Auto Mode" "2. Atlas One" "$width" "$panel_color"
  surface_split_row "3. Atlas Router" "4. Decision" "$width" "$panel_color"
  surface_split_row "5. Research" "6. Root Cause" "$width" "$panel_color"
  surface_split_row "7. Problem Solving" "8. Prompt Debugger" "$width" "$panel_color"
  surface_split_row "9. AI Menu" "t. B2 Atlas TUI" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Routes the ai menu selection to the matching action.
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
    t|T) PYTHONPATH="${BASE_DIR}" python3 -m mqlaunch.b2_tui.main ;;
    b|B|x|X|exit) return 1 ;;
    *) echo "${C_ERR}Invalid AI selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

# Keeps the ai menu interactive until the user backs out.
ai_menu_loop() {
  local choice

  while true; do
    print_ai_menu
    read_menu_choice "" "ai"
    choice="$REPLY"
    echo

    if ! handle_ai_menu_choice "$choice"; then
      break
    fi
  done
}

# Opens ai menu.
open_ai_menu() {
  ai_menu_loop
}
