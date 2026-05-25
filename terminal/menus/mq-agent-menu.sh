#!/usr/bin/env bash
# mq-agent menu module for mqlaunch

MQ_AGENT_BIN="${MQ_AGENT_BIN:-$HOME/mq-agent}"
MQ_MCP_DIR="${MQ_MCP_DIR:-$HOME/mq-mcp/mq-mcp}"
MQ_MCP_PORT="${MQ_MCP_PORT:-8765}"

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
  surface_row "MCP LOCAL TOOLS  (:8765)" "$width" "$panel_color"
  surface_split_row "11. MCP status" "12. MCP tools list" "$width" "$panel_color"
  surface_split_row "13. Start MCP server" "14. Stop MCP server" "$width" "$panel_color"
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
  (cd "$MQ_AGENT_BIN" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$MQ_AGENT_BIN" run mq-agent "$@")
}

# Starts mq-mcp server in the background if not already running on MQ_MCP_PORT.
_mcp_start() {
  if lsof -ti:"$MQ_MCP_PORT" >/dev/null 2>&1; then
    printf "mq-mcp already running on :%s\n" "$MQ_MCP_PORT"
    return 0
  fi
  if [[ ! -f "$MQ_MCP_DIR/server.py" ]]; then
    printf "server.py not found at %s\n" "$MQ_MCP_DIR" >&2
    return 1
  fi
  (cd "$MQ_MCP_DIR" && env -u VIRTUAL_ENV nohup uv run python server.py > /tmp/mq-mcp.log 2>&1 &)
  local pid=$!
  sleep 1
  if lsof -ti:"$MQ_MCP_PORT" >/dev/null 2>&1; then
    printf "mq-mcp started on :%s (pid %s)\n" "$MQ_MCP_PORT" "$pid"
  else
    printf "mq-mcp failed to start — check /tmp/mq-mcp.log\n" >&2
    return 1
  fi
}

# Stops mq-mcp server if running on MQ_MCP_PORT.
_mcp_stop() {
  local pids
  pids="$(lsof -ti:"$MQ_MCP_PORT" 2>/dev/null)"
  if [[ -z "$pids" ]]; then
    printf "mq-mcp is not running on :%s\n" "$MQ_MCP_PORT"
    return 0
  fi
  echo "$pids" | xargs kill 2>/dev/null || true
  sleep 1
  if lsof -ti:"$MQ_MCP_PORT" >/dev/null 2>&1; then
    printf "mq-mcp still running on :%s — try kill -9\n" "$MQ_MCP_PORT" >&2
    return 1
  fi
  printf "mq-mcp stopped (port :%s is free)\n" "$MQ_MCP_PORT"
}

# Handles direct mqlaunch agent commands.
run_agent_command() {
  local subcmd="${1:-menu}"
  case "$subcmd" in
    menu|"")
      open_agent_menu
      ;;
    doctor)
      shift || true
      _run_agent doctor "$@"
      ;;
    score)
      shift || true
      _run_agent score "$@"
      ;;
    audit)
      shift || true
      _run_agent audit "$@"
      ;;
    release-check)
      shift || true
      _run_agent release-check "$@"
      ;;
    mcp-status)
      shift || true
      _run_agent mcp status "$@"
      ;;
    mcp-tools)
      shift || true
      _run_agent mcp tools "$@"
      ;;
    mcp-start)
      _mcp_start
      ;;
    mcp-stop)
      _mcp_stop
      ;;
    *)
      _run_agent "$@"
      ;;
  esac
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
    13) _mcp_start;             pause_enter ;;
    14) _mcp_stop;              pause_enter ;;
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
