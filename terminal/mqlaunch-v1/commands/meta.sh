#!/usr/bin/env bash

command_show_version() {
  print_header
  print_section "Version Info"

  local version_file="$PROJECT_ROOT/VERSION"
  local version="unknown"

  if [[ -f "$version_file" ]]; then
    version="$(head -n 1 "$version_file")"
  fi

  print_kv "Project:" "macos-scripts"
  print_kv "Version:" "$version"
  print_kv "Release stage:" "baseline"
  print_kv "Project root:" "$PROJECT_ROOT"
  print_kv "Legacy launcher:" "$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
  print_kv "V1 launcher:" "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"

  pause_enter
}
