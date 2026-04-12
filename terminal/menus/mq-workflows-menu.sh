#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
WORKFLOWS_DIR="$BASE_DIR/automation/workflows"
PROJECT_BOOT_SCRIPT="$WORKFLOWS_DIR/project-boot.sh"
PROJECT_CHECK_SCRIPT="$WORKFLOWS_DIR/project-check.sh"
WORKFLOWS_README="$WORKFLOWS_DIR/README.md"
AUTOMATION_README="$BASE_DIR/automation/README.md"

APP_TITLE="MQ Workflows"
APP_SUBTITLE="Project Workflows and Automation"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

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

run_project_boot_default() {
  require_project_boot || return 1

  print_header
  row_bold "PROJECT BOOT"
  empty_row
  row "Starting default project boot..."
  print_footer

  "$PROJECT_BOOT_SCRIPT"
}

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
  printf "${C_TITLE}Project name: ${C_RESET}"
  read -r project_name
  printf "${C_TITLE}Project directory: ${C_RESET}"
  read -r project_dir
  printf "${C_TITLE}Project URL: ${C_RESET}"
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

run_project_check_custom() {
  local project_name=""
  local project_dir=""

  require_project_check || return 1

  print_header
  row_bold "CUSTOM PROJECT CHECK"
  empty_row
  row "Leave fields blank to use defaults."
  print_footer
  printf "${C_TITLE}Project name: ${C_RESET}"
  read -r project_name
  printf "${C_TITLE}Project directory: ${C_RESET}"
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

open_workflows_folder() {
  print_header
  row_bold "OPEN WORKFLOWS FOLDER"
  empty_row
  row "Opening:"
  row " $WORKFLOWS_DIR"
  print_footer
  open "$WORKFLOWS_DIR"
}

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

show_workflows_status() {
  print_header
  row_bold "WORKFLOWS STATUS"
  empty_row

  row "Workflows dir:  $WORKFLOWS_DIR"
  row "Project boot:   $PROJECT_BOOT_SCRIPT"
  row "Project check:  $PROJECT_CHECK_SCRIPT"

  if [[ -f "$WORKFLOWS_README" ]]; then
    row "README:         $WORKFLOWS_README"
  else
    row "README:         missing"
  fi

  print_footer
  pause_enter
}

print_menu() {
  print_header
  row_bold "WORKFLOWS"
  empty_row

  row2 " 1. Workflows status" " 2. Run project boot"
  row2 " 3. Custom project boot" " 4. Run project check"
  row2 " 5. Custom project check" " 6. Open workflows folder"
  row2 " 7. Open workflows README" " 0. Back"

  print_footer
  printf "${C_TITLE}Select option [0-7]: ${C_RESET}"
}

menu_loop() {
  local choice

  while true; do
    print_menu
    read -r choice
    echo

    case "$choice" in
      1) show_workflows_status ;;
      2) run_project_boot_default ;;
      3) run_project_boot_custom ;;
      4) run_project_check_default ;;
      5) run_project_check_custom ;;
      6) open_workflows_folder ;;
      7) open_workflows_readme ;;
      0) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

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
  readme        Open workflows README
  help          Show this help
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    status) show_workflows_status ;;
    boot) run_project_boot_default ;;
    boot-custom) run_project_boot_custom ;;
    check) run_project_check_default ;;
    check-custom) run_project_check_custom ;;
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
