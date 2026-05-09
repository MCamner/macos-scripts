#!/usr/bin/env bash

command_run_self_check() {
  local check_script="$PROJECT_ROOT/tools/scripts/system-check.sh"

  if [[ -x "$check_script" ]]; then
    "$check_script"
    return $?
  fi

  if [[ -f "$check_script" ]]; then
    bash "$check_script"
    return $?
  fi

  command_health_check
}
