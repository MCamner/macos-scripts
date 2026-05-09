#!/usr/bin/env bash

open_v1_tools_menu() {
  local v1_launcher="$BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"

  if [[ -x "$v1_launcher" ]]; then
    "$v1_launcher" tools
  elif [[ -f "$v1_launcher" ]]; then
    bash "$v1_launcher" tools
  else
    echo "${C_ERR}mqlaunch-v1 not found:${C_RESET} $v1_launcher"
    return 1
  fi
}

run_v1_tools_command() {
  local v1_launcher="$BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"
  local subcmd="${1:-tools}"

  if [[ -x "$v1_launcher" ]]; then
    "$v1_launcher" "$subcmd"
  elif [[ -f "$v1_launcher" ]]; then
    bash "$v1_launcher" "$subcmd"
  else
    echo "${C_ERR}mqlaunch-v1 not found:${C_RESET} $v1_launcher"
    return 1
  fi
}
