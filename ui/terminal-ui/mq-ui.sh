#!/usr/bin/env bash

# Shared terminal UI helpers for macos-scripts
# Intended to be sourced from bash or zsh scripts.

# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------
: "${APP_TITLE:=MQLaunch}"
: "${APP_SUBTITLE:=Terminal Utility}"
: "${APP_AUTHOR:=Author Mattias Camner}"
: "${BOX_INNER:=88}"
: "${MQ_THEME_FILE:=$HOME/.mq-theme}"

# ------------------------------------------------------------
# Optional theme file
# ------------------------------------------------------------
if [[ -f "$MQ_THEME_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$MQ_THEME_FILE"
fi

# ------------------------------------------------------------
# ANSI colors
# ------------------------------------------------------------
if [[ -t 1 ]]; then
  _MQ_DEFAULT_RESET=$'\033[0m'
  _MQ_DEFAULT_TITLE=$'\033[1;33m'
  _MQ_DEFAULT_ERR=$'\033[0;31m'
  _MQ_DEFAULT_OK=$'\033[0;32m'
  _MQ_DEFAULT_WARN=$'\033[0;33m'
  _MQ_DEFAULT_INFO=$'\033[0;34m'
  _MQ_DEFAULT_BOLD=$'\033[1m'

  C_RESET="${MQ_COLOR_RESET:-$_MQ_DEFAULT_RESET}"
  C_TITLE="${MQ_COLOR_TITLE:-$_MQ_DEFAULT_TITLE}"
  C_ERR="${MQ_COLOR_ERR:-$_MQ_DEFAULT_ERR}"
  C_OK="${MQ_COLOR_OK:-$_MQ_DEFAULT_OK}"
  C_WARN="${MQ_COLOR_WARN:-$_MQ_DEFAULT_WARN}"
  C_INFO="${MQ_COLOR_INFO:-$_MQ_DEFAULT_INFO}"
  C_BOLD="${MQ_COLOR_BOLD:-$_MQ_DEFAULT_BOLD}"
else
  C_RESET=''
  C_TITLE=''
  C_ERR=''
  C_OK=''
  C_WARN=''
  C_INFO=''
  C_BOLD=''
fi

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
repeat_char() {
  local count="$1"
  local char="$2"
  printf '%*s' "$count" '' | tr ' ' "$char"
}

border() {
  printf '%s\n' "$(repeat_char "$BOX_INNER" "-")"
}

row() {
  local text="$1"
  printf "%-*.*s\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

row_bold() {
  local text="$1"
  printf "${C_BOLD}%-*.*s${C_RESET}\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

row_menu_title() {
  local text="$1"
  if [[ -t 1 ]]; then
    printf "\033[1m%-*.*s\033[0m\n" "$BOX_INNER" "$BOX_INNER" "$text"
  else
    row "$text"
  fi
}

row2() {
  local c1="$1"
  local c2="$2"
  row "$(printf '%-40s %-40s' "$c1" "$c2")"
}

row3() {
  local c1="$1"
  local c2="$2"
  local c3="$3"
  row "$(printf '%-26s %-26s %-26s' "$c1" "$c2" "$c3")"
}

empty_row() {
  printf '\n'
}

header_dual_row() {
  local left="$1"
  local right="$2"
  printf "%-54s %33s\n" "$left" "$right"
}

pause_enter() {
  echo
  printf 'Press Enter to continue...'
  read -r _
}

read_prompt() {
  local color_prompt="$1"
  local plain_prompt="${2:-$1}"

  REPLY=""
  if [[ -n "${ZSH_VERSION:-}" && -t 0 && -t 1 ]]; then
    vared -p "$plain_prompt" -c REPLY
  else
    printf "%b" "$color_prompt"
    IFS= read -r REPLY
  fi
}

read_menu_choice() {
  local prompt="$1"
  read_prompt "${C_TITLE}${prompt}${C_RESET}" "$prompt"
}

set_terminal_title() {
  printf '\033]0;%s — %s\007' "$APP_TITLE" "$APP_SUBTITLE"
}

clear_screen() {
  if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
    tput clear 2>/dev/null || printf '\033[H\033[2J'
  else
    printf '\033[H\033[2J'
  fi
  set_terminal_title
}

short_host() {
  hostname -s 2>/dev/null || hostname
}

print_header() {
  local dashboard

  if [[ "${MQ_USE_DASHBOARD_HEADER:-0}" == "1" ]]; then
    dashboard="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}/ui/ascii/mqlaunch-dashboard-v7.1.sh"
    if [[ -f "$dashboard" ]]; then
      bash "$dashboard" "$APP_TITLE" "$APP_SUBTITLE" "ONLINE"
      printf '\n'
      return
    fi
  fi

  clear_screen
  border
  header_dual_row "$APP_TITLE" "        .-."
  header_dual_row "$APP_SUBTITLE" "       (o o)"
  header_dual_row "$APP_AUTHOR" "       | O \\"
  header_dual_row "" "        \\   \\"
  header_dual_row "" "         \`~~~'"
  border
}

print_footer() {
  local now host user_name
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  host="$(short_host)"
  user_name="${USER:-unknown}"

  printf '\n'
  row "Host: ${host}   User: ${user_name}"
  row "Time: ${now}"
  border
}

print_main_footer() {
  local now host user_name
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  host="$(short_host)"
  user_name="${USER:-unknown}"

  printf '\n'
  row "Host: ${host}   User: ${user_name}"
  row "Time: ${now}"
  row "X. Exit launcher"
  border
}

ui_ok() {
  printf "%b%s%b\n" "$C_OK" "$1" "$C_RESET"
}

ui_warn() {
  printf "%b%s%b\n" "$C_WARN" "$1" "$C_RESET"
}

ui_err() {
  printf "%b%s%b\n" "$C_ERR" "$1" "$C_RESET" >&2
}

ui_info() {
  printf "%b%s%b\n" "$C_INFO" "$1" "$C_RESET"
}
