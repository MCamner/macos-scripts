#!/usr/bin/env bash

# Performance Menu for MQLaunch v3
# Uses the Command Surface (v3) styling and sources data from v1 commands.

# Handles performance menu is sourced.
performance_menu_is_sourced() {
  if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    [[ ":$ZSH_EVAL_CONTEXT:" == *:file:* ]]
    return
  fi
  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

# Source dependencies if not already available
if ! command -v surface_top >/dev/null 2>&1; then
  BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
  [[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"
fi

# Compatibility with v1 commands
: "${PROJECT_ROOT:=$BASE_DIR}"

if ! command -v perf_health_score >/dev/null 2>&1; then
  BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
  [[ -f "$BASE_DIR/terminal/mqlaunch-v1/commands/performance.sh" ]] && source "$BASE_DIR/terminal/mqlaunch-v1/commands/performance.sh"
fi

# Handles render performance panel.
render_performance_panel() {
  local width panel_color score perf_status color output warnings
  width="$(surface_terminal_width)"
  
  if [[ -t 1 ]]; then
    panel_color=$'\033[0;37m'
  else
    panel_color=""
  fi

  output="$(perf_health_score)"
  score="$(echo "$output" | sed -n '1p')"
  perf_status="$(perf_score_status "$score")"
  color="$(perf_score_color "$score")"

  surface_top "Performance Hub" "$width" "$panel_color"
  surface_row "Health Score: ${color}${score}/100${C_RESET} ($perf_status)" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "MONITORING" "$width" "$panel_color"
  surface_split_row "1. Overview" "2. Detailed Health" "$width" "$panel_color"
  surface_split_row "3. Top CPU" "4. Top Memory" "$width" "$panel_color"
  surface_split_row "5. Disk Usage" "6. Network Overview" "$width" "$panel_color"
  surface_split_row "7. Battery Status" "" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "TOOLS" "$width" "$panel_color"
  surface_split_row "8. Create Snapshot" "9. Quick Watch" "$width" "$panel_color"
  surface_split_row "10. MQ Scan" "b. Back" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "Signals: Load $(perf_load_1m) | Disk $(perf_disk_percent_root)% | Batt $(perf_battery_display)%" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
}

# Opens performance menu.
open_performance_menu() {
  local choice
  
  while true; do
    print_header
    render_performance_panel
    
    # Reuse the main choice reader logic for consistency
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice || return
    else
      printf "\nmqlaunch > "
      read -r choice
    fi
    
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
      10) "$PROJECT_ROOT/tools/scripts/scan.sh"; pause_enter ;;
      b|B|back) break ;;
      x|X) exit 0 ;;
      *)
        # If it looks like a shell command, try to run it
        if [[ -n "$choice" ]]; then
          echo
          /bin/zsh -lc "$choice"
          pause_enter
        fi
        ;;
    esac
  done
}

if ! performance_menu_is_sourced; then
  open_performance_menu "$@"
fi
