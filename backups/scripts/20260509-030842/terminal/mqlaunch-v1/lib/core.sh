#!/usr/bin/env bash

set -u

MQ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$MQ_ROOT/../.." && pwd)"

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RED='\033[31m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_BLUE='\033[34m'
C_MAGENTA='\033[35m'
C_CYAN='\033[36m'

msg() {
  printf "%b\n" "$*"
}

info() {
  msg "${C_CYAN}$*${C_RESET}"
}

ok() {
  msg "${C_GREEN}$*${C_RESET}"
}

warn() {
  msg "${C_YELLOW}$*${C_RESET}"
}

err() {
  msg "${C_RED}$*${C_RESET}" >&2
}

die() {
  err "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  command_exists "$1" || die "Missing required command: $1"
}

pause_enter() {
  printf "\nPress Enter to continue..."
  read -r _
}

clear_screen() {
  clear
}

project_path() {
  printf "%s/%s\n" "$PROJECT_ROOT" "$1"
}

open_path() {
  local target="$1"

  if [[ ! -e "$target" ]]; then
    err "Path not found: $target"
    return 1
  fi

  open "$target"
}

run_script_if_exists() {
  local script="$1"

  if [[ -f "$script" ]]; then
    bash "$script"
  else
    err "Script not found: $script"
    return 1
  fi
}
