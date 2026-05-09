#!/usr/bin/env bash

# Opens performance menu.
open_performance_menu() {
  local v3_perf_menu="$BASE_DIR/terminal/menus/mq-performance-menu.sh"

  if [[ -f "$v3_perf_menu" ]]; then
    # shellcheck disable=SC1091
    source "$v3_perf_menu"
    open_performance_menu "$@"
  else
    # Fallback to v1 if v3 is missing
    local v1_launcher="$BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"
    if [[ -x "$v1_launcher" ]]; then
      "$v1_launcher" performance
    elif [[ -f "$v1_launcher" ]]; then
      bash "$v1_launcher" performance
    else
      echo "${C_ERR}Performance menu not found:${C_RESET} $v3_perf_menu"
      return 1
    fi
  fi
}

# Runs performance command.
run_performance_command() {
  local v1_launcher="$BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"
  local subcmd="${1:-performance}"

  if [[ -x "$v1_launcher" ]]; then
    "$v1_launcher" "$subcmd"
  elif [[ -f "$v1_launcher" ]]; then
    bash "$v1_launcher" "$subcmd"
  else
    echo "${C_ERR}mqlaunch-v1 not found:${C_RESET} $v1_launcher"
    return 1
  fi
}

# Backward-compatible aliases
open_v1_performance_menu() {
  open_performance_menu "$@"
}

# Runs v1 performance command.
run_v1_performance_command() {
  run_performance_command "$@"
}
