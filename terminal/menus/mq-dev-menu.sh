#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Menu header
source "$BASE_DIR/terminal/menus/mq-menu-header.sh"
APP_SUBTITLE="Repo-Aware Developer Tools"

# Menu header
source "$BASE_DIR/terminal/menus/mq-menu-header.sh"
APP_SUBTITLE="Repo-Aware Developer Tools"

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

repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    echo "$BASE_DIR"
  fi
}

project_root=""
project_root="$(repo_root)"

open_path() {
  local target="$1"
  if [[ -e "$target" ]]; then
    open "$target"
  else
    echo -e "${C_RED}Path not found:${C_RESET} $target"
  fi
}

open_in_code() {
  local target="$1"
  if command -v code >/dev/null 2>&1; then
    code "$target"
  else
    echo -e "${C_RED}VS Code CLI 'code' not found in PATH.${C_RESET}"
  fi
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

print_header_mode "MQLAUNCH" "$APP_SUBTITLE" "DEV MODE"_mode "MQLAUNCH" "$APP_SUBTITLE" "DEV MODE"_mode "MQLAUNCH" "$APP_SUBTITLE" "DEV MODE"_mode "MQLAUNCH" "$APP_SUBTITLE" "DEV MODE"() {
  clear_screen
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}              DEV MENU V2               ${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo
  echo "Developer tools for the current project"
  echo -e "${C_GREEN}Root:${C_RESET} $project_root"
  echo
}

show_repo_info() {
  echo -e "${C_GREEN}Project root:${C_RESET}"
  echo "$project_root"
  echo

  if git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${C_GREEN}Branch:${C_RESET}"
    git -C "$project_root" branch --show-current
    echo
    echo -e "${C_GREEN}Status:${C_RESET}"
    git -C "$project_root" status --short --branch
  else
    echo -e "${C_YELLOW}No Git repository detected.${C_RESET}"
  fi
}

open_repo_root() {
  echo -e "${C_GREEN}Opening repo root...${C_RESET}"
  open_path "$project_root"
}

open_terminal_menus() {
  echo -e "${C_GREEN}Opening terminal/menus...${C_RESET}"
  open_path "$project_root/terminal/menus"
}

open_terminal_launchers() {
  echo -e "${C_GREEN}Opening terminal/launchers...${C_RESET}"
  open_path "$project_root/terminal/launchers"
}

open_ai_prompts() {
  echo -e "${C_GREEN}Opening ai-prompts...${C_RESET}"
  open_path "$project_root/ai-prompts"
}

open_tools_dir() {
  echo -e "${C_GREEN}Opening tools...${C_RESET}"
  open_path "$project_root/tools"
}

open_ui_dir() {
  echo -e "${C_GREEN}Opening ui...${C_RESET}"
  open_path "$project_root/ui"
}

open_project_in_vscode() {
  echo -e "${C_GREEN}Opening project in VS Code...${C_RESET}"
  open_in_code "$project_root"
}

open_repo_remote() {
  local remote_url normalized_url

  if ! git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${C_RED}Not a Git repository.${C_RESET}"
    return
  fi

  remote_url="$(git -C "$project_root" remote get-url origin 2>/dev/null || true)"

  if [[ -z "$remote_url" ]]; then
    echo -e "${C_RED}No origin remote found.${C_RESET}"
    return
  fi

  normalized_url="$(normalize_remote_url "$remote_url")"

  echo -e "${C_GREEN}Opening GitHub remote:${C_RESET}"
  echo "$normalized_url"
  open "$normalized_url"
}

show_git_status() {
  if git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${C_GREEN}Git status:${C_RESET}"
    git -C "$project_root" status --short --branch
  else
    echo -e "${C_RED}Not a Git repository.${C_RESET}"
  fi
}

search_in_project() {
  local pattern

  read -r -p "Search text: " pattern

  if [[ -z "${pattern// }" ]]; then
    echo -e "${C_RED}Search text cannot be empty.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Searching whole project for:${C_RESET} $pattern"
  echo

  if command -v rg >/dev/null 2>&1; then
    rg -n --hidden --glob '!.git' "$pattern" "$project_root"
  else
    grep -RIn --exclude-dir=.git "$pattern" "$project_root"
  fi
}

search_mqlaunch() {
  local pattern
  local file="$project_root/terminal/launchers/mqlaunch.sh"

  if [[ ! -f "$file" ]]; then
    echo -e "${C_RED}mqlaunch.sh not found.${C_RESET}"
    return
  fi

  read -r -p "Search text in mqlaunch.sh: " pattern

  if [[ -z "${pattern// }" ]]; then
    echo -e "${C_RED}Search text cannot be empty.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Searching mqlaunch.sh for:${C_RESET} $pattern"
  echo

  grep -n "$pattern" "$file" || echo "No matches found."
}

search_menus_dir() {
  local pattern
  local dir="$project_root/terminal/menus"

  if [[ ! -d "$dir" ]]; then
    echo -e "${C_RED}terminal/menus not found.${C_RESET}"
    return
  fi

  read -r -p "Search text in terminal/menus: " pattern

  if [[ -z "${pattern// }" ]]; then
    echo -e "${C_RED}Search text cannot be empty.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Searching terminal/menus for:${C_RESET} $pattern"
  echo

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$dir"
  else
    grep -RIn "$pattern" "$dir"
  fi
}

find_file_in_project() {
  local name

  read -r -p "Filename or pattern: " name

  if [[ -z "${name// }" ]]; then
    echo -e "${C_RED}Filename cannot be empty.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Finding files matching:${C_RESET} $name"
  echo

  find "$project_root" -not -path '*/.git/*' -iname "*$name*" | sed -n '1,200p'
}

run_install_script() {
  local file="$project_root/install.sh"

  if [[ -f "$file" ]]; then
    echo -e "${C_YELLOW}Running install.sh...${C_RESET}"
    bash "$file"
  else
    echo -e "${C_RED}install.sh not found in project root.${C_RESET}"
  fi
}

run_system_check_script() {
  local file="$project_root/tools/scripts/system-check.sh"

  if [[ -f "$file" ]]; then
    echo -e "${C_YELLOW}Running system-check.sh...${C_RESET}"
    bash "$file"
  else
    echo -e "${C_RED}tools/scripts/system-check.sh not found.${C_RESET}"
  fi
}

edit_mqlaunch() {
  local file="$project_root/terminal/launchers/mqlaunch.sh"

  if [[ ! -f "$file" ]]; then
    echo -e "${C_RED}mqlaunch.sh not found.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Opening mqlaunch.sh...${C_RESET}"
  open_in_code "$file"
}

edit_git_menu() {
  local file="$project_root/terminal/menus/mq-git-menu.sh"

  if [[ ! -f "$file" ]]; then
    echo -e "${C_RED}mq-git-menu.sh not found.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Opening mq-git-menu.sh...${C_RESET}"
  open_in_code "$file"
}

edit_dev_menu() {
  local file="$project_root/terminal/menus/mq-dev-menu.sh"

  if [[ ! -f "$file" ]]; then
    echo -e "${C_RED}mq-dev-menu.sh not found.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Opening mq-dev-menu.sh...${C_RESET}"
  open_in_code "$file"
}

edit_tools_menu() {
  local file="$project_root/terminal/menus/mq-tools-menu.sh"

  if [[ ! -f "$file" ]]; then
    echo -e "${C_RED}mq-tools-menu.sh not found.${C_RESET}"
    return
  fi

  echo -e "${C_GREEN}Opening mq-tools-menu.sh...${C_RESET}"
  open_in_code "$file"
}

show_menu() {
  echo "1) Repo info"
  echo "2) Open repo root"
  echo "3) Open terminal/menus"
  echo "4) Open terminal/launchers"
  echo "5) Open ai-prompts"
  echo "6) Open tools"
  echo "7) Open ui"
  echo "8) Open project in VS Code"
  echo "9) Open GitHub remote"
  echo "10) Git status"
  echo "11) Search whole project"
  echo "12) Search mqlaunch.sh"
  echo "13) Search terminal/menus"
  echo "14) Find file in project"
  echo "15) Run install.sh"
  echo "16) Run system-check.sh"
  echo "17) Edit mqlaunch.sh"
  echo "18) Edit mq-git-menu.sh"
  echo "19) Edit mq-dev-menu.sh"
  echo "20) Edit mq-tools-menu.sh"
  echo "0) Back / Exit"
  echo
}

handle_choice() {
  local choice="$1"

  case "$choice" in
    1) show_repo_info ;;
    2) open_repo_root ;;
    3) open_terminal_menus ;;
    4) open_terminal_launchers ;;
    5) open_ai_prompts ;;
    6) open_tools_dir ;;
    7) open_ui_dir ;;
    8) open_project_in_vscode ;;
    9) open_repo_remote ;;
    10) show_git_status ;;
    11) search_in_project ;;
    12) search_mqlaunch ;;
    13) search_menus_dir ;;
    14) find_file_in_project ;;
    15) run_install_script ;;
    16) run_system_check_script ;;
    17) edit_mqlaunch ;;
    18) edit_git_menu ;;
    19) edit_dev_menu ;;
    20) edit_tools_menu ;;
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
