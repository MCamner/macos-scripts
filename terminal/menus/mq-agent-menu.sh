#!/usr/bin/env bash
# mq-agent menu module for mqlaunch

MQ_AGENT_BIN="${MQ_AGENT_BIN:-$HOME/mq-agent}"

# Prints mq-agent menu.
print_agent_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "AI Agent Orchestrator" "mq-agent" "$width" "$panel_color"
  surface_row "REPO ANALYSIS  (no API key required)" "$width" "$panel_color"
  surface_split_row "1. Score repository" "2. Full signal assessment" "$width" "$panel_color"
  surface_split_row "3. Repo summary" "4. List tools" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "AI COMMANDS  (requires OPENAI_API_KEY)" "$width" "$panel_color"
  surface_split_row "5. Audit repository" "6. Signal + AI plan" "$width" "$panel_color"
  surface_split_row "7. Release check" "8. Diagnose CI" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MCP LOCAL TOOLS  (requires mq-mcp on :8765)" "$width" "$panel_color"
  surface_split_row "11. MCP status" "12. MCP tools list" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "ENVIRONMENT" "$width" "$panel_color"
  surface_split_row "9. Doctor" "10. TUI dashboard" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs an mq-agent command inside the mq-agent project dir.
_run_agent() {
  (cd "$MQ_AGENT_BIN" && uv run mq-agent "$@")
}

# Handles agent menu choice.
handle_agent_menu_choice() {
  local choice="$1"
  case "$choice" in
    1) _run_agent score .;    pause_enter ;;
    2) _run_agent signal .;   pause_enter ;;
    3) _run_agent repo-summary .; pause_enter ;;
    4) _run_agent tools;      pause_enter ;;
    5) _run_agent audit .;    pause_enter ;;
    6) _run_agent signal .;   pause_enter ;;
    7) _run_agent release-check; pause_enter ;;
    8) _run_agent fix-ci;     pause_enter ;;
    9) _run_agent doctor;     pause_enter ;;
    10) _run_agent tui ;;
    11) _run_agent mcp status;  pause_enter ;;
    12) _run_agent mcp tools;   pause_enter ;;
    b|B|x|X|exit) return 1 ;;
    *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
  esac
  return 0
}

# Handles agent menu loop.
agent_menu_loop() {
  local choice
  while true; do
    print_agent_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "mq-agent" || break
    else
      printf "\nmq-agent > "
      read -r choice
    fi
    echo
    if ! handle_agent_menu_choice "$choice"; then
      break
    fi
  done
}

# Opens agent menu.
open_agent_menu() {
  agent_menu_loop
}
