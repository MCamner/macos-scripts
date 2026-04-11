#!/usr/bin/env bash

command_run_shortcuts_helper() {
  local shortcuts_script="$PROJECT_ROOT/automation/shortcuts/mqshortcuts.sh"

  if [[ ! -x "$shortcuts_script" ]]; then
    print_header
    print_section "Shortcuts"
    echo "Missing or non-executable script:"
    echo " $shortcuts_script"
    echo
    echo "Run:"
    echo " chmod +x $shortcuts_script"
    pause_enter
    return 1
  fi

  "$shortcuts_script" "$@"
}
