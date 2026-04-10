#!/usr/bin/env bash

open_v1_performance_menu() {
  local v1_launcher="$BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"

  if [[ -x "$v1_launcher" ]]; then
    "$v1_launcher" performance
  elif [[ -f "$v1_launcher" ]]; then
    bash "$v1_launcher" performance
  else
    echo "${C_ERR}mqlaunch-v1 not found:${C_RESET} $v1_launcher"
    return 1
  fi
}

run_v1_performance_command() {
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
