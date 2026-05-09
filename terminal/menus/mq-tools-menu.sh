#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
WORK_DIR="${MQ_WORK_DIR:-$PWD}"

if repo_root="$(git -C "$WORK_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  WORK_DIR="$repo_root"
fi

UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

# shellcheck disable=SC2034
APP_TITLE="MQ Tools Menu"
# shellcheck disable=SC2034
APP_SUBTITLE="Reusable Terminal Module"
# shellcheck disable=SC2034
APP_AUTHOR="Author Mattias Camner"
# shellcheck disable=SC2034
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

SYSTEM_CHECK="$BASE_DIR/tools/scripts/system-check.sh"
DOCUMENT_FUNCTIONS="$BASE_DIR/tools/scripts/document-functions.sh"
DOCUMENT_FUNCTION_TARGETS=("$WORK_DIR")
DOCUMENT_FUNCTION_ARGS=(--summary --exclude '*.bak.*' --exclude '*/.git/*')
MQLAUNCH="$BASE_DIR/terminal/launchers/mqlaunch.sh"
DASHBOARD="$BASE_DIR/ui/dashboards/mq-dashboard.sh"
THEMES_DIR="$BASE_DIR/terminal/themes"
LAUNCHERS_DIR="$BASE_DIR/terminal/launchers"
MENUS_DIR="$BASE_DIR/terminal/menus"
GUIDE_HTML="$BASE_DIR/tools/mac-terminal-guide/mac-terminal-guide.html"
GUIDE_URL="https://mcamner.github.io/macos-scripts/"

# Normalizes document function target.
normalize_document_function_target() {
  local target="$1"

  if [[ "$target" = /* ]]; then
    printf '%s\n' "$target"
  else
    printf '%s/%s\n' "$WORK_DIR" "$target"
  fi
}

# Runs system check.
run_system_check() {
  if [[ -x "$SYSTEM_CHECK" ]]; then
    "$SYSTEM_CHECK"
  else
    print_header
    row "SYSTEM CHECK"
    empty_row
    row "system-check.sh not found or not executable:"
    row " $SYSTEM_CHECK"
    print_footer
    pause_enter
  fi
}

# Opens repo.
open_repo() {
  open "$BASE_DIR"
}

# Opens launchers.
open_launchers() {
  open "$LAUNCHERS_DIR"
}

# Opens themes.
open_themes() {
  open "$THEMES_DIR"
}

# Opens menus.
open_menus() {
  open "$MENUS_DIR"
}

# Opens dashboard.
open_dashboard() {
  if [[ -x "$DASHBOARD" ]]; then
    bash "$DASHBOARD" menu
  elif [[ -f "$DASHBOARD" ]]; then
    chmod +x "$DASHBOARD" 2>/dev/null || true
    bash "$DASHBOARD" menu
  else
    print_header
    row "DASHBOARD"
    empty_row
    row "Dashboard script missing:"
    row " $DASHBOARD"
    print_footer
    pause_enter
  fi
}

# Opens guide.
open_guide() {
  if [[ -f "$GUIDE_HTML" ]]; then
    open "$GUIDE_HTML"
  else
    open "$GUIDE_URL"
  fi
}

# Shows paths.
show_paths() {
  print_header
  row_bold "KEY PATHS"
  empty_row

  row "BASE_DIR"
  row " $BASE_DIR"
  empty_row

  row "WORK_DIR"
  row " $WORK_DIR"
  empty_row

  row "MQLAUNCH"
  row " $MQLAUNCH"
  empty_row

  row "DASHBOARD"
  row " $DASHBOARD"
  empty_row

  row "THEMES DIR"
  row " $THEMES_DIR"
  empty_row

  row "MENUS DIR"
  row " $MENUS_DIR"

  print_footer
  pause_enter
}

# Shows git status.
show_git_status() {
  print_header
  row_bold "GIT STATUS"
  empty_row

  if [[ -d "$BASE_DIR/.git" ]]; then
    git -C "$BASE_DIR" status --short --branch || true
  else
    row "Not a git repository:"
    row " $BASE_DIR"
  fi

  print_footer
  pause_enter
}

# Runs document functions preview.
run_document_functions_preview() {
  print_header
  row_bold "DOCUMENT FUNCTIONS"
  empty_row

  if [[ -x "$DOCUMENT_FUNCTIONS" ]]; then
    run_document_functions_command "${DOCUMENT_FUNCTION_ARGS[@]}" "${DOCUMENT_FUNCTION_TARGETS[@]}"
  elif [[ -f "$DOCUMENT_FUNCTIONS" ]]; then
    run_document_functions_command "${DOCUMENT_FUNCTION_ARGS[@]}" "${DOCUMENT_FUNCTION_TARGETS[@]}"
  else
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
  fi

  print_footer
  if [[ -t 0 ]]; then
    pause_enter
  fi
}

# Runs document functions command.
run_document_functions_command() {
  if [[ -x "$DOCUMENT_FUNCTIONS" ]]; then
    MACOS_SCRIPTS_HOME="$WORK_DIR" "$DOCUMENT_FUNCTIONS" "$@"
  else
    MACOS_SCRIPTS_HOME="$WORK_DIR" bash "$DOCUMENT_FUNCTIONS" "$@"
  fi
}

# Handles pause if interactive.
pause_if_interactive() {
  if [[ -t 0 ]]; then
    pause_enter
  fi
}

# Handles select document function targets.
select_document_function_targets() {
  local action="${1:-update}"
  local selection custom target

  SELECTED_DOCUMENT_FUNCTION_TARGETS=()

  row "Choose what to $action:"
  row " a. Current repo/path (default)"
  row " 1. tools/scripts in current path"
  row " 2. terminal/menus in current path"
  row " 3. terminal/launchers in current path"
  row " 4. One script/path"
  row " c. Custom list"
  row " q. Cancel"
  empty_row

  printf 'Target [a,1-4,c,q] > '
  read -r selection
  selection="${selection:-a}"

  case "$selection" in
    a|A)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("${DOCUMENT_FUNCTION_TARGETS[@]}")
      ;;
    1)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "tools/scripts")")
      ;;
    2)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "terminal/menus")")
      ;;
    3)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "terminal/launchers")")
      ;;
    4)
      printf 'Script/path > '
      read -r custom
      if [[ -z "${custom// }" ]]; then
        ui_warn "No path entered."
        return 1
      fi
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "$custom")")
      ;;
    c|C)
      row "Enter space-separated files or directories."
      printf 'Paths > '
      read -r custom
      if [[ -z "${custom// }" ]]; then
        ui_warn "No paths entered."
        return 1
      fi
      for target in $custom; do
        SELECTED_DOCUMENT_FUNCTION_TARGETS+=("$(normalize_document_function_target "$target")")
      done
      ;;
    q|Q|n|N)
      ui_warn "Cancelled."
      return 1
      ;;
    *)
      ui_err "Unknown target selection: $selection"
      return 1
      ;;
  esac

  return 0
}

# Prints document function targets.
print_document_function_targets() {
  local target

  for target in "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"; do
    row " $target"
  done
}

# Runs document functions preview selected.
run_document_functions_preview_selected() {
  print_header
  row_bold "DOCUMENT FUNCTIONS PREVIEW"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "preview"; then
    print_footer
    pause_if_interactive
    return 0
  fi

  empty_row
  run_document_functions_command "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"

  print_footer
  pause_if_interactive
}

# Runs document functions diff selected.
run_document_functions_diff_selected() {
  print_header
  row_bold "DOCUMENT FUNCTIONS DIFF"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "diff"; then
    print_footer
    pause_if_interactive
    return 0
  fi

  empty_row
  run_document_functions_command --diff "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"

  print_footer
  pause_if_interactive
}

# Runs document functions check selected.
run_document_functions_check_selected() {
  print_header
  row_bold "DOCUMENT FUNCTIONS CHECK"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "check"; then
    print_footer
    pause_if_interactive
    return 0
  fi

  empty_row
  if run_document_functions_command --check "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"; then
    ui_ok "All selected function comments are current."
  else
    ui_warn "Selected files need function comment updates."
  fi

  print_footer
  pause_if_interactive
}

# Runs document functions update.
run_document_functions_update() {
  local confirm

  print_header
  row_bold "UPDATE FUNCTION COMMENTS"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    if [[ -t 0 ]]; then
      pause_enter
    fi
    return 1
  fi

  if ! select_document_function_targets "update"; then
    print_footer
    if [[ -t 0 ]]; then
      pause_enter
    fi
    return 0
  fi

  empty_row
  row "This will add or refresh generated function comments in:"
  print_document_function_targets
  empty_row
  row "Backups will be saved under backups/scripts before files are changed."
  empty_row

  printf 'Update comments now? [y/N] '
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    ui_warn "Cancelled."
    print_footer
    if [[ -t 0 ]]; then
      pause_enter
    fi
    return 0
  fi

  empty_row
  run_document_functions_command --write --backup "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"

  print_footer
  if [[ -t 0 ]]; then
    pause_enter
  fi
}

# Prints document functions menu.
print_document_functions_menu() {
  print_header
  row_bold "DOCUMENT FUNCTIONS"
  empty_row

  row2 " 1. Preview active areas" " 2. Preview selected"
  row2 " 3. Diff selected" " 4. Check selected"
  row2 " 5. Update selected" " b. Back"

  print_footer
}

# Documents functions menu loop.
document_functions_menu_loop() {
  local choice

  while true; do
    print_document_functions_menu
    read_menu_choice "Select option [1-5,b] > " "docs" || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) run_document_functions_preview ;;
      2) run_document_functions_preview_selected ;;
      3) run_document_functions_diff_selected ;;
      4) run_document_functions_check_selected ;;
      5) run_document_functions_update ;;
      b|B) ui_ok "Back."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints menu.
print_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Tools Menu" "Tools" "$width" "$panel_color"
  surface_row "SYSTEM" "$width" "$panel_color"
  surface_split_row "1. Run system check" "2. Open repo folder" "$width" "$panel_color"
  surface_split_row "3. Open launchers folder" "4. Open themes folder" "$width" "$panel_color"
  surface_split_row "5. Open menus folder" "6. Open dashboard" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "REFERENCE" "$width" "$panel_color"
  surface_split_row "7. Open terminal guide" "8. Show key paths" "$width" "$panel_color"
  surface_split_row "9. Show git status" "10. Boot Maker" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "ACTIONS" "$width" "$panel_color"
  surface_split_row "11. Blackout Mode" "12. Document functions" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the menu loop.
menu_loop() {
  local choice

  while true; do
    print_menu
    read_menu_choice "Select option [1-12,b] > " "tools" || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) run_system_check ;;
      2) open_repo ;;
      3) open_launchers ;;
      4) open_themes ;;
      5) open_menus ;;
      6) open_dashboard ;;
      7) open_guide ;;
      8) show_paths ;;
      9) show_git_status ;;
    10) "$BASE_DIR/tools/cli/boot-maker.sh"; pause_enter ;;
    11) "$BASE_DIR/tools/scripts/blackout.sh"; pause_enter ;;
    12) document_functions_menu_loop ;;
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints usage information.
usage() {
  cat <<USAGE
mq-tools-menu.sh - reusable tools menu

Usage:
  mq-tools-menu.sh [command]

Commands:
  menu        Open menu (default)
  check       Run system check
  dashboard   Open dashboard
  guide       Open terminal guide
  paths       Show key paths
  git         Show git status
  docfunc     Open function documentation menu
  docpreview  Preview missing shell function comments
  docwrite    Add/update shell function comments with backups
USAGE
}

# Runs the main entry point.
main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    check) run_system_check ;;
    dashboard) open_dashboard ;;
    guide) open_guide ;;
    paths) show_paths ;;
    git) show_git_status ;;
    docfunc|document-functions|docs) document_functions_menu_loop ;;
    docpreview|document-functions-preview) run_document_functions_preview ;;
    docwrite|document-functions-write) run_document_functions_update ;;
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
