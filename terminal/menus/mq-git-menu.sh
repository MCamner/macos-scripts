#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
UI_FILE="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

if [[ -f "$UI_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$UI_FILE"
fi

: "${C_RESET:=\033[0m}"
: "${C_BOLD:=\033[1m}"
: "${C_CYAN:=\033[36m}"
: "${C_GREEN:=\033[32m}"
: "${C_YELLOW:=\033[33m}"
: "${C_RED:=\033[31m}"

clear_screen() {
  command -v clear >/dev/null 2>&1 && clear
}

pause_menu() {
  echo
  read -r -p "Press Enter to continue..."
}

print_header() {
  clear_screen
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}               GIT MENU                 ${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo
  echo "Quick Git actions for the current repository"
  echo
}

in_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

require_git_repo() {
  if ! in_git_repo; then
    echo -e "${C_RED}Not inside a Git repository.${C_RESET}"
    return 1
  fi
  return 0
}

show_repo_info() {
  require_git_repo || return
  echo -e "${C_GREEN}Repository root:${C_RESET}"
  git rev-parse --show-toplevel
  echo
  echo -e "${C_GREEN}Current branch:${C_RESET}"
  git branch --show-current
}

show_status() {
  require_git_repo || return
  echo -e "${C_GREEN}Git status:${C_RESET}"
  git status --short --branch
}

show_diff_summary() {
  require_git_repo || return
  echo -e "${C_GREEN}Diff summary:${C_RESET}"
  git diff --stat
  echo
  echo -e "${C_GREEN}Staged diff summary:${C_RESET}"
  git diff --cached --stat
}

show_log() {
  require_git_repo || return
  echo -e "${C_GREEN}Recent commits:${C_RESET}"
  git log --oneline --decorate -n 12
}

show_branches() {
  require_git_repo || return
  echo -e "${C_GREEN}Branches:${C_RESET}"
  git branch -a
}

git_fetch_all() {
  require_git_repo || return
  echo -e "${C_YELLOW}Fetching all remotes...${C_RESET}"
  git fetch --all --prune
}

git_pull_current() {
  require_git_repo || return
  echo -e "${C_YELLOW}Pulling latest changes...${C_RESET}"
  git pull
}

git_push_current() {
  require_git_repo || return
  echo -e "${C_YELLOW}Pushing current branch...${C_RESET}"
  git push
}

git_add_all() {
  require_git_repo || return
  echo -e "${C_YELLOW}Staging all changes...${C_RESET}"
  git add .
  echo -e "${C_GREEN}Done.${C_RESET}"
}

git_commit_prompt() {
  local msg

  require_git_repo || return

  read -r -p "Commit message: " msg

  if [[ -z "${msg// }" ]]; then
    echo -e "${C_RED}Commit message cannot be empty.${C_RESET}"
    return
  fi

  git commit -m "$msg"
}

git_add_commit_push() {
  local msg

  require_git_repo || return

  echo -e "${C_YELLOW}Staging all changes...${C_RESET}"
  git add .

  read -r -p "Commit message: " msg

  if [[ -z "${msg// }" ]]; then
    echo -e "${C_RED}Commit message cannot be empty.${C_RESET}"
    return
  fi

  git commit -m "$msg" && git push
}

open_repo_remote() {
  local remote_url

  require_git_repo || return

  remote_url="$(git remote get-url origin 2>/dev/null || true)"

  if [[ -z "$remote_url" ]]; then
    echo -e "${C_RED}No origin remote found.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Opening origin remote...${C_RESET}"

  if command -v open >/dev/null 2>&1; then
    open "$remote_url"
  else
    echo "$remote_url"
  fi
}

show_menu() {
  echo "1) Repo info"
  echo "2) Git status"
  echo "3) Diff summary"
  echo "4) Recent log"
  echo "5) Show branches"
  echo "6) Fetch all"
  echo "7) Pull"
  echo "8) Push"
  echo "9) Add all"
  echo "10) Commit"
  echo "11) Add + Commit + Push"
  echo "12) Open origin remote"
  echo "0) Back / Exit"
  echo
}

handle_choice() {
  local choice="$1"

  case "$choice" in
    1) show_repo_info ;;
    2) show_status ;;
    3) show_diff_summary ;;
    4) show_log ;;
    5) show_branches ;;
    6) git_fetch_all ;;
    7) git_pull_current ;;
    8) git_push_current ;;
    9) git_add_all ;;
    10) git_commit_prompt ;;
    11) git_add_commit_push ;;
    12) open_repo_remote ;;
    0|q|quit|exit) return 1 ;;
    *)
      echo -e "${C_RED}Invalid selection.${C_RESET}"
      ;;
  esac

  return 0
}

menu_loop() {
  local choice

  while true; do
    print_header
    show_menu
    read -r -p "Choose an option: " choice

    if ! handle_choice "$choice"; then
      break
    fi

    pause_menu
  done
}

menu_loop
