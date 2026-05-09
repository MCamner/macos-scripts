#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

APP_TITLE="MQ Dashboard"
APP_SUBTITLE="Project Status Console"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

MQ_SCRIPT="$BASE_DIR/terminal/launchers/mqlaunch.sh"
MACOS_TWEAKS="$BASE_DIR/system/tweaks/macos-tweaks.sh"
TERMINAL_TWEAKS="$BASE_DIR/terminal/tweaks.sh"
SYSTEM_CHECK="$BASE_DIR/tools/scripts/system-check.sh"
GUIDE_HTML="$BASE_DIR/tools/mac-terminal-guide/mac-terminal-guide.html"
GUIDE_URL="https://mcamner.github.io/macos-scripts/"
DOCS_DIR="$BASE_DIR/docs"

MACOS_TWEAKS_BACKUP="${HOME}/.macos-tweaks-backup"
TERMINAL_TWEAKS_BACKUP="${HOME}/.terminal-tweaks-backup"

status_word() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf "OK"
  else
    printf "MISSING"
  fi
}

status_exec_word() {
  local path="$1"
  if [[ -x "$path" ]]; then
    printf "OK"
  elif [[ -e "$path" ]]; then
    printf "FOUND"
  else
    printf "MISSING"
  fi
}

tool_word() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    printf "INSTALLED"
  else
    printf "NOT FOUND"
  fi
}

latest_backup_dir() {
  local dir="$1"
  ls -td "$dir"/* 2>/dev/null | head -n 1 || true
}

shorten_path() {
  local p="$1"
  local max="${2:-58}"
  if [[ ${#p} -le $max ]]; then
    printf "%s" "$p"
  else
    printf "...%s" "${p: -$((max-3))}"
  fi
}

git_branch() {
  git -C "$BASE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf "-"
}

git_short_status_count() {
  git -C "$BASE_DIR" status --short 2>/dev/null | wc -l | tr -d ' '
}

git_dirty_word() {
  local count
  count="$(git_short_status_count)"
  if [[ "$count" == "0" ]]; then
    printf "CLEAN"
  else
    printf "DIRTY (%s)" "$count"
  fi
}

git_last_commit() {
  git -C "$BASE_DIR" log -1 --pretty=format:'%h %s' 2>/dev/null || printf "-"
}

git_remote_url() {
  git -C "$BASE_DIR" remote get-url origin 2>/dev/null || printf "-"
}

show_dashboard() {
  local mq_status tweaks_status terminal_tweaks_status ui_status system_check_status guide_status docs_status
  local eza_status bat_status fd_status rg_status jq_status zoxide_status gh_status btop_status
  local latest_macos_backup latest_terminal_backup
  local mq_cmd host_name branch dirty last_commit remote_url

  mq_status="$(status_exec_word "$MQ_SCRIPT")"
  tweaks_status="$(status_exec_word "$MACOS_TWEAKS")"
  terminal_tweaks_status="$(status_exec_word "$TERMINAL_TWEAKS")"
  ui_status="$(status_exec_word "$UI_LIB")"
  system_check_status="$(status_exec_word "$SYSTEM_CHECK")"
  guide_status="$(status_word "$GUIDE_HTML")"
  docs_status="$(status_word "$DOCS_DIR")"

  eza_status="$(tool_word eza)"
  bat_status="$(tool_word bat)"
  fd_status="$(tool_word fd)"
  rg_status="$(tool_word rg)"
  jq_status="$(tool_word jq)"
  zoxide_status="$(tool_word zoxide)"
  gh_status="$(tool_word gh)"
  btop_status="$(tool_word btop)"

  latest_macos_backup="$(latest_backup_dir "$MACOS_TWEAKS_BACKUP")"
  latest_terminal_backup="$(latest_backup_dir "$TERMINAL_TWEAKS_BACKUP")"

  mq_cmd="$(command -v mqlaunch 2>/dev/null || printf "-")"
  host_name="$(hostname -s 2>/dev/null || hostname)"
  branch="$(git_branch)"
  dirty="$(git_dirty_word)"
  last_commit="$(git_last_commit)"
  remote_url="$(git_remote_url)"

  print_header
  row_bold "PROJECT DASHBOARD"
  empty_row

  row "PROJECT"
  row2 " Repo: $(shorten_path "$BASE_DIR" 34)" " Branch: $branch"
  row2 " Repo state: $dirty" " mqlaunch cmd: $(shorten_path "$mq_cmd" 24)"
  row " Last commit: $(shorten_path "$last_commit" 78)"
  row " Remote: $(shorten_path "$remote_url" 82)"

  empty_row
  row "CORE FILES"
  row2 " mqlaunch.sh: $mq_status" " macos-tweaks.sh: $tweaks_status"
  row2 " terminal/tweaks.sh: $terminal_tweaks_status" " mq-ui.sh: $ui_status"
  row2 " system-check.sh: $system_check_status" " terminal guide: $guide_status"
  row2 " docs/: $docs_status" " host: $host_name"

  empty_row
  row "TOOLS"
  row2 " eza: $eza_status" " bat: $bat_status"
  row2 " fd: $fd_status" " ripgrep: $rg_status"
  row2 " jq: $jq_status" " zoxide: $zoxide_status"
  row2 " gh: $gh_status" " btop: $btop_status"

  empty_row
  row "BACKUPS"
  row " macOS tweaks latest: $(shorten_path "${latest_macos_backup:-NONE}" 66)"
  row " terminal tweaks latest: $(shorten_path "${latest_terminal_backup:-NONE}" 63)"

  empty_row
  row "PATHS"
  row " Guide URL: $GUIDE_URL"
  row " UI Lib: $(shorten_path "$UI_LIB" 74)"

  print_footer
}

open_repo_folder() {
  if [[ -d "$BASE_DIR" ]]; then
    open "$BASE_DIR"
  else
    ui_err "Base directory missing: $BASE_DIR"
    pause_enter
  fi
}

open_ui_folder() {
  if [[ -d "$BASE_DIR/ui" ]]; then
    open "$BASE_DIR/ui"
  else
    ui_err "UI directory missing."
    pause_enter
  fi
}

open_dashboards_folder() {
  if [[ -d "$BASE_DIR/ui/dashboards" ]]; then
    open "$BASE_DIR/ui/dashboards"
  else
    ui_err "Dashboards directory missing."
    pause_enter
  fi
}

open_docs_site() {
  open "$GUIDE_URL"
}

run_system_check_screen() {
  if [[ -x "$SYSTEM_CHECK" ]]; then
    "$SYSTEM_CHECK"
  elif [[ -x "$MQ_SCRIPT" ]]; then
    bash "$MQ_SCRIPT" check
  else
    ui_err "No runnable system check found."
    pause_enter
  fi
}

show_git_changes_screen() {
  print_header
  row_bold "GIT CHANGES"
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

interactive_menu() {
  local choice

  while true; do
    show_dashboard
    echo
    row "MENU"
    row2 " 1. Refresh dashboard" " 2. Show git changes"
    row2 " 3. Run system check" " 4. Open repo folder"
    row2 " 5. Open UI folder" " 6. Open dashboards folder"
    row2 " 7. Open project page" " 0. Exit"
    print_footer
    read_menu_choice "Select option [0-7] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1)
        ;;
      2)
        show_git_changes_screen
        ;;
      3)
        run_system_check_screen
        ;;
      4)
        open_repo_folder
        ;;
      5)
        open_ui_folder
        ;;
      6)
        open_dashboards_folder
        ;;
      7)
        open_docs_site
        ;;
      0)
        ui_ok "Exiting."
        break
        ;;
      *)
        ui_err "Invalid option."
        pause_enter
        ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-dashboard.sh - project status dashboard

Usage:
  mq-dashboard.sh [command]

Commands:
  menu        Open interactive dashboard menu (default)
  show        Show dashboard once
  git         Show git status screen
  check       Run system check
  help        Show help
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu)
      interactive_menu
      ;;
    show)
      show_dashboard
      ;;
    git)
      show_git_changes_screen
      ;;
    check)
      run_system_check_screen
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

main "${1:-menu}"
