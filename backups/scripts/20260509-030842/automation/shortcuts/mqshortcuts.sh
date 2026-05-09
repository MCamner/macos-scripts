#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="mqshortcuts"

usage() {
  cat <<'EOF'
mqshortcuts — fast macOS Shortcuts helper for terminal workflows

Usage:
  bash automation/shortcuts/mqshortcuts.sh <command> [options]

Commands:
  list [folder]              List shortcuts, optionally in a folder
  folders                    List shortcut folders
  search <query> [folder]    Search shortcuts by name
  run <name> [input-path]    Run a shortcut, optionally with input
  view <name>                Open a shortcut in the Shortcuts app
  help                       Show this help

Examples:
  bash automation/shortcuts/mqshortcuts.sh list
  bash automation/shortcuts/mqshortcuts.sh folders
  bash automation/shortcuts/mqshortcuts.sh search clip
  bash automation/shortcuts/mqshortcuts.sh search clip Work
  bash automation/shortcuts/mqshortcuts.sh run "Daily Briefing"
  bash automation/shortcuts/mqshortcuts.sh run "Resize Image" ~/Desktop/pic.png
  bash automation/shortcuts/mqshortcuts.sh view "Daily Briefing"
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_shortcuts() {
  command -v shortcuts >/dev/null 2>&1 || die "The macOS 'shortcuts' CLI is not available"
}

run_shortcuts_cli() {
  local output=""

  if output="$("$@" 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  if [[ "$output" == *"Couldn’t communicate with a helper application."* ]] || [[ "$output" == *"Couldn't communicate with a helper application."* ]]; then
    die "The Shortcuts helper app is not reachable right now. Try opening the Shortcuts app once and run the command again."
  fi

  die "$output"
}

print_header() {
  echo
  echo "== $1 =="
}

list_shortcuts() {
  local folder="${1:-}"

  print_header "SHORTCUTS"

  if [[ -n "$folder" ]]; then
    run_shortcuts_cli shortcuts list --folder-name "$folder"
  else
    run_shortcuts_cli shortcuts list
  fi
}

list_folders() {
  print_header "SHORTCUT FOLDERS"
  run_shortcuts_cli shortcuts list --folders
}

search_shortcuts() {
  local query="${1:-}"
  local folder="${2:-}"
  local output=""

  [[ -n "$query" ]] || die "Missing search query"

  print_header "SEARCH: $query"

  if [[ -n "$folder" ]]; then
    output="$(run_shortcuts_cli shortcuts list --folder-name "$folder")"
  else
    output="$(run_shortcuts_cli shortcuts list)"
  fi

  if [[ -z "$output" ]]; then
    echo "No shortcuts found."
    return 0
  fi

  if command -v rg >/dev/null 2>&1; then
    if ! printf '%s\n' "$output" | rg -i -- "$query"; then
      echo "No matches."
    fi
  else
    if ! printf '%s\n' "$output" | grep -i -- "$query"; then
      echo "No matches."
    fi
  fi
}

run_shortcut() {
  local name="${1:-}"
  local input_path="${2:-}"

  [[ -n "$name" ]] || die "Missing shortcut name"

  print_header "RUN: $name"

  if [[ -n "$input_path" ]]; then
    run_shortcuts_cli shortcuts run "$name" --input-path "$input_path"
  else
    run_shortcuts_cli shortcuts run "$name"
  fi
}

view_shortcut() {
  local name="${1:-}"

  [[ -n "$name" ]] || die "Missing shortcut name"

  print_header "VIEW: $name"
  run_shortcuts_cli shortcuts view "$name"
}

main() {
  local cmd="${1:-help}"

  require_shortcuts

  case "$cmd" in
    list)
      shift
      list_shortcuts "${1:-}"
      ;;
    folders)
      list_folders
      ;;
    search)
      shift
      search_shortcuts "${1:-}" "${2:-}"
      ;;
    run)
      shift
      run_shortcut "${1:-}" "${2:-}"
      ;;
    view)
      shift
      view_shortcut "${1:-}"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
