#!/usr/bin/env bash

command_git_status() {
  print_header
  print_section "Git Status"
  (cd "$PROJECT_ROOT" && git status)
  pause_enter
}

command_git_pull() {
  print_header
  print_section "Git Pull"
  (cd "$PROJECT_ROOT" && git pull)
  pause_enter
}

command_git_push() {
  print_header
  print_section "Git Push"
  (cd "$PROJECT_ROOT" && git push)
  pause_enter
}

command_edit_mqlaunch() {
  local target="$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"

  if command_exists code; then
    code "$target"
  else
    open "$target"
  fi
}
