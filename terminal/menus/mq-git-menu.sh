#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Menu header
source "$BASE_DIR/terminal/menus/mq-menu-header.sh"
APP_SUBTITLE="Safer Git Actions"

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

confirm_action() {
  local prompt="${1:-Are you sure?}"
  local reply
  read -r -p "$prompt [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

print_header_mode "MQLAUNCH" "$APP_SUBTITLE" "GIT MODE"_mode "MQLAUNCH" "$APP_SUBTITLE" "GIT MODE"() {
  clear_screen
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}               GIT MENU V3              ${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo
  echo "Safer Git actions for the current repository"
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

current_branch() {
  git branch --show-current 2>/dev/null
}

has_staged_changes() {
  ! git diff --cached --quiet
}

has_unstaged_changes() {
  ! git diff --quiet
}

has_untracked_files() {
  [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]
}

has_any_local_changes() {
  has_staged_changes || has_unstaged_changes || has_untracked_files
}

show_repo_info() {
  local root branch upstream ahead_behind

  require_git_repo || return

  root="$(git rev-parse --show-toplevel)"
  branch="$(current_branch)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  ahead_behind="$(git status --short --branch 2>/dev/null | head -n 1)"

  echo -e "${C_GREEN}Repository root:${C_RESET}"
  echo "$root"
  echo
  echo -e "${C_GREEN}Current branch:${C_RESET}"
  echo "${branch:-detached HEAD}"
  echo
  echo -e "${C_GREEN}Upstream:${C_RESET}"
  echo "${upstream:-No upstream set}"
  echo
  echo -e "${C_GREEN}Branch status:${C_RESET}"
  echo "${ahead_behind:-Unavailable}"
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
  git log --oneline --decorate -n 15
}

show_branches() {
  require_git_repo || return
  echo -e "${C_GREEN}Branches:${C_RESET}"
  git branch -a
}

show_upstream_status() {
  require_git_repo || return
  echo -e "${C_YELLOW}Fetching upstream status...${C_RESET}"
  git fetch --all --prune
  echo
  git status --short --branch
}

show_stash_list() {
  require_git_repo || return
  echo -e "${C_GREEN}Stash list:${C_RESET}"
  git stash list
}

git_fetch_all() {
  require_git_repo || return
  echo -e "${C_YELLOW}Fetching all remotes...${C_RESET}"
  git fetch --all --prune
}

git_pull_rebase() {
  require_git_repo || return

  if has_any_local_changes; then
    echo -e "${C_RED}Local changes detected. Commit, stash, or restore before pull --rebase.${C_RESET}"
    return
  fi

  echo -e "${C_YELLOW}Pulling latest changes with rebase...${C_RESET}"
  git pull --rebase
}

git_push_current() {
  require_git_repo || return
  echo -e "${C_YELLOW}Pushing current branch...${C_RESET}"
  git push
}

git_add_all() {
  require_git_repo || return
  echo -e "${C_YELLOW}Staging all changes...${C_RESET}"
  git add -A
  echo -e "${C_GREEN}Done.${C_RESET}"
}

git_stage_one_file() {
  local file

  require_git_repo || return

  echo -e "${C_GREEN}Changed/untracked files:${C_RESET}"
  git status --short
  echo

  read -r -p "File to stage: " file

  if [[ -z "${file// }" ]]; then
    echo -e "${C_RED}File path cannot be empty.${C_RESET}"
    return
  fi

  git add -- "$file"
}

git_commit_prompt() {
  local msg

  require_git_repo || return

  if ! has_staged_changes; then
    echo -e "${C_RED}No staged changes to commit.${C_RESET}"
    return
  fi

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
  git add -A

  if ! has_staged_changes; then
    echo -e "${C_RED}No changes to commit.${C_RESET}"
    return
  fi

  read -r -p "Commit message: " msg

  if [[ -z "${msg// }" ]]; then
    echo -e "${C_RED}Commit message cannot be empty.${C_RESET}"
    return
  fi

  git commit -m "$msg" && git push
}

git_stash_push() {
  local msg

  require_git_repo || return

  if ! has_any_local_changes; then
    echo -e "${C_RED}No local changes to stash.${C_RESET}"
    return
  fi

  read -r -p "Stash message (optional): " msg

  if ! confirm_action "Create stash with current local changes?"; then
    echo -e "${C_YELLOW}Cancelled.${C_RESET}"
    return
  fi

  if [[ -n "${msg// }" ]]; then
    git stash push -u -m "$msg"
  else
    git stash push -u
  fi
}

git_stash_pop() {
  require_git_repo || return

  if [[ -z "$(git stash list)" ]]; then
    echo -e "${C_RED}No stash entries found.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Latest stash:${C_RESET}"
  git stash list | head -n 1
  echo

  if ! confirm_action "Apply and drop the latest stash?"; then
    echo -e "${C_YELLOW}Cancelled.${C_RESET}"
    return
  fi

  git stash pop
}

git_switch_branch() {
  local branch

  require_git_repo || return

  echo -e "${C_GREEN}Available local branches:${C_RESET}"
  git branch --format='%(refname:short)'
  echo

  read -r -p "Branch to switch to: " branch

  if [[ -z "${branch// }" ]]; then
    echo -e "${C_RED}Branch name cannot be empty.${C_RESET}"
    return
  fi

  git switch "$branch"
}

git_create_branch() {
  local branch

  require_git_repo || return

  read -r -p "New branch name: " branch

  if [[ -z "${branch// }" ]]; then
    echo -e "${C_RED}Branch name cannot be empty.${C_RESET}"
    return
  fi

  git switch -c "$branch"
}

git_delete_branch() {
  local branch current

  require_git_repo || return

  current="$(current_branch)"

  echo -e "${C_GREEN}Local branches:${C_RESET}"
  git branch --format='%(refname:short)'
  echo

  read -r -p "Branch to delete: " branch

  if [[ -z "${branch// }" ]]; then
    echo -e "${C_RED}Branch name cannot be empty.${C_RESET}"
    return
  fi

  if [[ "$branch" == "$current" ]]; then
    echo -e "${C_RED}Cannot delete the current branch.${C_RESET}"
    return
  fi

  if ! confirm_action "Delete local branch '$branch'?"; then
    echo -e "${C_YELLOW}Cancelled.${C_RESET}"
    return
  fi

  git branch -d "$branch"
}

git_restore_worktree_file() {
  local file

  require_git_repo || return

  echo -e "${C_YELLOW}Modified files:${C_RESET}"
  git status --short
  echo

  read -r -p "File to discard changes for: " file

  if [[ -z "${file// }" ]]; then
    echo -e "${C_RED}File path cannot be empty.${C_RESET}"
    return
  fi

  if ! confirm_action "Discard unstaged changes in '$file'?"; then
    echo -e "${C_YELLOW}Cancelled.${C_RESET}"
    return
  fi

  git restore -- "$file"
}

git_unstage_file() {
  local file

  require_git_repo || return

  echo -e "${C_YELLOW}Staged files:${C_RESET}"
  git diff --cached --name-only
  echo

  read -r -p "File to unstage: " file

  if [[ -z "${file// }" ]]; then
    echo -e "${C_RED}File path cannot be empty.${C_RESET}"
    return
  fi

  git restore --staged -- "$file"
}

normalize_remote_url() {
  local remote_url="$1"

  if [[ "$remote_url" =~ ^git@github\.com:(.*)$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$remote_url" =~ ^https://github\.com/(.*)\.git$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$remote_url" =~ ^git@([^:]+):(.*)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return
  fi

  echo "${remote_url%.git}"
}

open_repo_remote() {
  local remote_url normalized_url

  require_git_repo || return

  remote_url="$(git remote get-url origin 2>/dev/null || true)"

  if [[ -z "$remote_url" ]]; then
    echo -e "${C_RED}No origin remote found.${C_RESET}"
    return
  fi

  normalized_url="$(normalize_remote_url "$remote_url")"

  echo -e "${C_GREEN}Opening origin remote:${C_RESET}"
  echo "$normalized_url"

  if command -v open >/dev/null 2>&1; then
    open "$normalized_url"
  else
    echo "$normalized_url"
  fi
}

show_menu() {
  echo "1) Repo info"
  echo "2) Git status"
  echo "3) Diff summary"
  echo "4) Recent log"
  echo "5) Show branches"
  echo "6) Fetch all"
  echo "7) Pull --rebase"
  echo "8) Push"
  echo "9) Add all"
  echo "10) Stage one file"
  echo "11) Commit staged changes"
  echo "12) Add + Commit + Push"
  echo "13) Open origin remote"
  echo "14) Upstream status"
  echo "15) Stash push"
  echo "16) Stash pop"
  echo "17) Show stash list"
  echo "18) Switch branch"
  echo "19) Create branch"
  echo "20) Delete local branch"
  echo "21) Discard changes in file"
  echo "22) Unstage file"
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
    7) git_pull_rebase ;;
    8) git_push_current ;;
    9) git_add_all ;;
    10) git_stage_one_file ;;
    11) git_commit_prompt ;;
    12) git_add_commit_push ;;
    13) open_repo_remote ;;
    14) show_upstream_status ;;
    15) git_stash_push ;;
    16) git_stash_pop ;;
    17) show_stash_list ;;
    18) git_switch_branch ;;
    19) git_create_branch ;;
    20) git_delete_branch ;;
    21) git_restore_worktree_file ;;
    22) git_unstage_file ;;
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
