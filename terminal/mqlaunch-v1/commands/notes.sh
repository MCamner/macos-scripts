#!/usr/bin/env bash

command_show_changelog() {
  print_header
  print_section "Release Notes"

  local changelog="$PROJECT_ROOT/CHANGELOG.md"

  if [[ ! -f "$changelog" ]]; then
    err "Missing: $changelog"
    pause_enter
    return 1
  fi

  if command -v bat >/dev/null 2>&1; then
    bat --style=plain --paging=never "$changelog" | head -n 80
  else
    head -n 80 "$changelog"
  fi

  pause_enter
}
