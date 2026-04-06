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

# ------------------------------------------------------------
# ANSI colors
# ------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_TITLE=$'\033[1;33m'
  C_ERR=$'\033[0;31m'
  C_OK=$'\033[0;32m'
  C_WARN=$'\033[0;33m'
  C_INFO=$'\033[0;34m'
  C_BOLD=$'\033[1m'
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
  read -r -p "Press Enter to continue..." _
}

set_terminal_title() {
  printf '\033]0;%s — %s\007' "$APP_TITLE" "$APP_SUBTITLE"
}

clear_screen() {
  if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
    tput clear
  else
    clear
  fi
  set_terminal_title
}

short_host() {
  hostname -s 2>/dev/null || hostname
}

print_header() {
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
