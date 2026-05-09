#!/usr/bin/env bash

command_run_debug_bundle() {
  print_header
  print_section "Debug Bundle"

  local bundle_script="$PROJECT_ROOT/tools/scripts/create-debug-bundle.sh"

  if [[ ! -x "$bundle_script" ]]; then
    err "Missing or non-executable: $bundle_script"
    pause_enter
    return 1
  fi

  local outfile
  outfile="$("$bundle_script")"
  local status=$?

  echo
  if [[ $status -eq 0 ]]; then
    ok "Debug bundle created:"
    echo " $outfile"
    [[ -f "$outfile" ]] && open -R "$outfile" 2>/dev/null || true
  else
    err "Debug bundle failed."
  fi

  pause_enter
  return $status
}
