#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
WORKFLOWS_DIR="$BASE_DIR/automation/workflows"
PROJECT_BOOT_SCRIPT="$WORKFLOWS_DIR/project-boot.sh"
PROJECT_CHECK_SCRIPT="$WORKFLOWS_DIR/project-check.sh"
WORKSPACE_SCRIPT="$WORKFLOWS_DIR/workspace.sh"
WORKFLOWS_README="$WORKFLOWS_DIR/README.md"
AUTOMATION_README="$BASE_DIR/automation/README.md"

# shellcheck disable=SC2034
APP_TITLE="MQ Workflows"
# shellcheck disable=SC2034
APP_SUBTITLE="Project Workflows and Automation"
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

# Handles require project boot.
require_project_boot() {
  if [[ ! -x "$PROJECT_BOOT_SCRIPT" ]]; then
    print_header
    row_bold "WORKFLOWS"
    empty_row
    row "Missing or non-executable script:"
    row " $PROJECT_BOOT_SCRIPT"
    row "Run:"
    row " chmod +x $PROJECT_BOOT_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

# Handles require project check.
require_project_check() {
  if [[ ! -x "$PROJECT_CHECK_SCRIPT" ]]; then
    print_header
    row_bold "WORKFLOWS"
    empty_row
    row "Missing or non-executable script:"
    row " $PROJECT_CHECK_SCRIPT"
    row "Run:"
    row " chmod +x $PROJECT_CHECK_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

# Handles require workspace.
require_workspace() {
  if [[ ! -x "$WORKSPACE_SCRIPT" ]]; then
    print_header
    row_bold "WORKFLOWS"
    empty_row
    row "Missing or non-executable script:"
    row " $WORKSPACE_SCRIPT"
    row "Run:"
    row " chmod +x $WORKSPACE_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

# Runs project boot default.
run_project_boot_default() {
  require_project_boot || return 1

  print_header
  row_bold "PROJECT BOOT"
  empty_row
  row "Starting default project boot..."
  print_footer

  "$PROJECT_BOOT_SCRIPT"
}

# Runs project boot custom.
run_project_boot_custom() {
  local project_name=""
  local project_dir=""
  local project_url=""

  require_project_boot || return 1

  print_header
  row_bold "CUSTOM PROJECT BOOT"
  empty_row
  row "Leave fields blank to use defaults."
  print_footer
  printf '%bProject name: %b' "$C_TITLE" "$C_RESET"
  read -r project_name
  printf '%bProject directory: %b' "$C_TITLE" "$C_RESET"
  read -r project_dir
  printf '%bProject URL: %b' "$C_TITLE" "$C_RESET"
  read -r project_url

  project_name="${project_name:-macos-scripts}"
  project_dir="${project_dir:-$HOME/macos-scripts}"
  project_url="${project_url:-https://github.com/MCamner/macos-scripts}"

  print_header
  row_bold "PROJECT BOOT"
  empty_row
  row "Project:   $project_name"
  row "Directory: $project_dir"
  row "Repo URL:  $project_url"
  print_footer

  "$PROJECT_BOOT_SCRIPT" "$project_name" "$project_dir" "$project_url"
}

# Runs project check default.
run_project_check_default() {
  require_project_check || return 1

  print_header
  row_bold "PROJECT CHECK"
  empty_row
  row "Running default project check..."
  print_footer

  "$PROJECT_CHECK_SCRIPT"
  pause_enter
}

# Runs project check custom.
run_project_check_custom() {
  local project_name=""
  local project_dir=""

  require_project_check || return 1

  print_header
  row_bold "CUSTOM PROJECT CHECK"
  empty_row
  row "Leave fields blank to use defaults."
  print_footer
  printf '%bProject name: %b' "$C_TITLE" "$C_RESET"
  read -r project_name
  printf '%bProject directory: %b' "$C_TITLE" "$C_RESET"
  read -r project_dir

  project_name="${project_name:-macos-scripts}"
  project_dir="${project_dir:-$HOME/macos-scripts}"

  print_header
  row_bold "PROJECT CHECK"
  empty_row
  row "Project:   $project_name"
  row "Directory: $project_dir"
  print_footer

  "$PROJECT_CHECK_SCRIPT" "$project_name" "$project_dir"
  pause_enter
}

# Opens workflows folder.
open_workflows_folder() {
  print_header
  row_bold "OPEN WORKFLOWS FOLDER"
  empty_row
  row "Opening:"
  row " $WORKFLOWS_DIR"
  print_footer
  open "$WORKFLOWS_DIR"
}

# Opens workflows readme.
open_workflows_readme() {
  local target="$WORKFLOWS_README"

  [[ -f "$target" ]] || target="$AUTOMATION_README"

  print_header
  row_bold "OPEN WORKFLOWS README"
  empty_row
  row "Opening:"
  row " $target"
  print_footer

  if command -v code >/dev/null 2>&1; then
    code "$target"
  else
    open "$target"
  fi
}

# Shows workflows status.
show_workflows_status() {
  print_header
  row_bold "WORKFLOWS STATUS"
  empty_row

  row "Workflows dir:  $WORKFLOWS_DIR"
  row "Project boot:   $PROJECT_BOOT_SCRIPT"
  row "Project check:  $PROJECT_CHECK_SCRIPT"
  row "Workspace:      $WORKSPACE_SCRIPT"

  if [[ -f "$WORKFLOWS_README" ]]; then
    row "README:         $WORKFLOWS_README"
  else
    row "README:         missing"
  fi

  print_footer
  pause_enter
}

# Opens workspace menu.
open_workspace_menu() {
  require_workspace || return 1
  "$WORKSPACE_SCRIPT" menu
}

# Handles save workspace snapshot.
save_workspace_snapshot() {
  require_workspace || return 1
  "$WORKSPACE_SCRIPT" save
  pause_enter
}

# Handles restore workspace snapshot.
restore_workspace_snapshot() {
  require_workspace || return 1
  "$WORKSPACE_SCRIPT" restore
  pause_enter
}

# Prints menu.
print_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Workflows" "Workflows" "$width" "$panel_color"
  surface_row "PROJECT" "$width" "$panel_color"
  surface_split_row "1. Workflows status" "2. Run project boot" "$width" "$panel_color"
  surface_split_row "3. Custom project boot" "4. Run project check" "$width" "$panel_color"
  surface_split_row "5. Custom project check" "6. Open workflows folder" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "REFERENCE" "$width" "$panel_color"
  surface_split_row "7. Open workflows README" "8. Workspace snapshots" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "WORKSPACE" "$width" "$panel_color"
  surface_split_row "9. Save workspace" "10. Restore workspace" "$width" "$panel_color"
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
    read_menu_choice "Select option [1-10,b] > " "workflows" || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) show_workflows_status ;;
      2) run_project_boot_default ;;
      3) run_project_boot_custom ;;
      4) run_project_check_default ;;
      5) run_project_check_custom ;;
      6) open_workflows_folder ;;
      7) open_workflows_readme ;;
      8) open_workspace_menu ;;
      9) save_workspace_snapshot ;;
      10) restore_workspace_snapshot ;;
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints usage information.
usage() {
  cat <<USAGE
mq-workflows-menu.sh - interactive workflows menu

Usage:
  mq-workflows-menu.sh [command]

Commands:
  menu          Open menu (default)
  status        Show workflows status
  boot          Run default project boot
  boot-custom   Run custom project boot
  check         Run default project check
  check-custom  Run custom project check
  workspace     Open workspace snapshots menu
  save          Save current workspace snapshot
  restore       Restore latest workspace snapshot
  readme        Open workflows README
  help          Show this help
USAGE
}

# Runs the main entry point.
main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    status) show_workflows_status ;;
    boot) run_project_boot_default ;;
    boot-custom) run_project_boot_custom ;;
    check) run_project_check_default ;;
    check-custom) run_project_check_custom ;;
    workspace) open_workspace_menu ;;
    save) save_workspace_snapshot ;;
    restore) restore_workspace_snapshot ;;
    readme) open_workflows_readme ;;
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
