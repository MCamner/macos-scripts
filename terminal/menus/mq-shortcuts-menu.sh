#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
SHORTCUTS_SCRIPT="$BASE_DIR/automation/shortcuts/mqshortcuts.sh"

APP_TITLE="MQ Shortcuts"
APP_SUBTITLE="macOS Shortcuts Workspace"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

require_shortcuts_script() {
  if [[ ! -x "$SHORTCUTS_SCRIPT" ]]; then
    print_header
    row_bold "SHORTCUTS"
    empty_row
    row "Missing or non-executable script:"
    row " $SHORTCUTS_SCRIPT"
    row "Run:"
    row " chmod +x $SHORTCUTS_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

run_shortcuts_screen() {
  local title="$1"
  shift

  require_shortcuts_script || return 1

  print_header
  row_bold "$title"
  empty_row

  if ! "$SHORTCUTS_SCRIPT" "$@"; then
    echo
    row "Shortcuts command failed."
  fi

  print_footer
  pause_enter
}

list_shortcuts_menu() {
  local folder=""

  print_header
  row_bold "LIST SHORTCUTS"
  empty_row
  row "Leave folder blank to list everything."
  print_footer
  printf "${C_TITLE}Folder (optional): ${C_RESET}"
  read -r folder

  if [[ -n "${folder// }" ]]; then
    run_shortcuts_screen "SHORTCUTS IN: $folder" list "$folder"
  else
    run_shortcuts_screen "ALL SHORTCUTS" list
  fi
}

search_shortcuts_menu() {
  local query=""
  local folder=""

  print_header
  row_bold "SEARCH SHORTCUTS"
  empty_row
  print_footer
  printf "${C_TITLE}Search query: ${C_RESET}"
  read -r query

  if [[ -z "${query// }" ]]; then
    ui_err "Search query cannot be empty."
    pause_enter
    return 1
  fi

  printf "${C_TITLE}Folder (optional): ${C_RESET}"
  read -r folder

  if [[ -n "${folder// }" ]]; then
    run_shortcuts_screen "SEARCH: $query" search "$query" "$folder"
  else
    run_shortcuts_screen "SEARCH: $query" search "$query"
  fi
}

run_shortcut_menu() {
  local name=""
  local input_path=""

  print_header
  row_bold "RUN SHORTCUT"
  empty_row
  print_footer
  printf "${C_TITLE}Shortcut name: ${C_RESET}"
  read -r name

  if [[ -z "${name// }" ]]; then
    ui_err "Shortcut name cannot be empty."
    pause_enter
    return 1
  fi

  printf "${C_TITLE}Input path (optional): ${C_RESET}"
  read -r input_path

  if [[ -n "${input_path// }" ]]; then
    run_shortcuts_screen "RUN: $name" run "$name" "$input_path"
  else
    run_shortcuts_screen "RUN: $name" run "$name"
  fi
}

view_shortcut_menu() {
  local name=""

  print_header
  row_bold "VIEW SHORTCUT"
  empty_row
  print_footer
  printf "${C_TITLE}Shortcut name: ${C_RESET}"
  read -r name

  if [[ -z "${name// }" ]]; then
    ui_err "Shortcut name cannot be empty."
    pause_enter
    return 1
  fi

  run_shortcuts_screen "VIEW: $name" view "$name"
}

open_shortcuts_app() {
  print_header
  row_bold "OPEN SHORTCUTS APP"
  empty_row
  row "Opening Shortcuts..."
  print_footer
  open -a "Shortcuts" >/dev/null 2>&1 || {
    ui_err "Could not open Shortcuts."
    pause_enter
    return 1
  }
}

show_shortcuts_help() {
  run_shortcuts_screen "MQSHORTCUTS HELP" help
}

print_menu() {
  print_header
  row_bold "SHORTCUTS"
  empty_row

  row2 " 1. List shortcuts" " 2. List folders"
  row2 " 3. Search shortcuts" " 4. Run shortcut"
  row2 " 5. View shortcut" " 6. Open Shortcuts app"
  row2 " 7. Show mqshortcuts help" " b. Back"

  print_footer
}

menu_loop() {
  local choice

  while true; do
    print_menu
    read_menu_choice "Select option [1-7,b] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) list_shortcuts_menu ;;
      2) run_shortcuts_screen "SHORTCUT FOLDERS" folders ;;
      3) search_shortcuts_menu ;;
      4) run_shortcut_menu ;;
      5) view_shortcut_menu ;;
      6) open_shortcuts_app ;;
      7) show_shortcuts_help ;;
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-shortcuts-menu.sh - interactive shortcuts menu

Usage:
  mq-shortcuts-menu.sh [command]

Commands:
  menu      Open menu (default)
  list      List shortcuts
  folders   List shortcut folders
  search    Open interactive search flow
  run       Open interactive run flow
  view      Open interactive view flow
  help      Show this help
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    list) run_shortcuts_screen "ALL SHORTCUTS" list ;;
    folders) run_shortcuts_screen "SHORTCUT FOLDERS" folders ;;
    search) search_shortcuts_menu ;;
    run) run_shortcut_menu ;;
    view) view_shortcut_menu ;;
    help|-h|--help) usage ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

main "${1:-menu}"
