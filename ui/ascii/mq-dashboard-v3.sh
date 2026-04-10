#!/usr/bin/env bash

: "${C_RESET:=\033[0m}"
: "${C_BOLD:=\033[1m}"
: "${C_DIM:=\033[2m}"
: "${C_BLACK:=\033[30m}"
: "${C_RED:=\033[31m}"
: "${C_GREEN:=\033[32m}"
: "${C_YELLOW:=\033[33m}"
: "${C_BLUE:=\033[34m}"
: "${C_MAGENTA:=\033[35m}"
: "${C_CYAN:=\033[36m}"
: "${C_WHITE:=\033[37m}"

NEON_PINK="${C_MAGENTA}"
NEON_CYAN="${C_CYAN}"
NEON_GREEN="${C_GREEN}"
NEON_YELLOW="${C_YELLOW}"
NEON_RED="${C_RED}"

mq_strip_ansi() {
  printf '%s' "$1" | perl -pe 's/\e\[[0-9;]*m//g'
}

mq_repeat() {
  local char="${1:--}"
  local count="${2:-80}"
  local out=""
  local i
  for (( i=0; i<count; i++ )); do
    out+="$char"
  done
  printf '%s' "$out"
}

mq_len() {
  local s="$1"
  s="$(mq_strip_ansi "$s")"
  printf '%s' "${#s}"
}

mq_truncate() {
  local text="$1"
  local width="${2:-40}"
  local stripped
  stripped="$(mq_strip_ansi "$text")"
  if (( ${#stripped} <= width )); then
    printf '%s' "$text"
  else
    printf '%s' "${stripped:0:width-3}..."
  fi
}

mq_pad_right() {
  local text="$1"
  local width="${2:-40}"
  local len pad
  len="$(mq_len "$text")"
  pad=$(( width - len ))
  (( pad < 0 )) && pad=0
  printf '%s' "$text"
  printf "%*s" "$pad" ""
}

mq_git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git branch --show-current 2>/dev/null
}

mq_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || return 0
  basename "$(git rev-parse --show-toplevel 2>/dev/null)"
}

mq_git_dirty() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    printf '%s' "DIRTY"
  else
    printf '%s' "CLEAN"
  fi
}

mq_user() {
  printf '%s' "${USER:-unknown}"
}

mq_host() {
  hostname -s 2>/dev/null || hostname 2>/dev/null || printf '%s' "unknown"
}

mq_time() {
  date '+%Y-%m-%d %H:%M:%S'
}

mq_shell_name() {
  basename "${SHELL:-shell}"
}

mq_os_name() {
  uname -s
}

mq_box_line() {
  local left="$1"
  local fill="$2"
  local right="$3"
  local width="${4:-88}"
  printf '%s%s%s\n' "$left" "$(mq_repeat "$fill" $((width - 2)))" "$right"
}

mq_print_row() {
  local left="$1"
  local right="$2"
  local width="${3:-88}"
  local inner=$(( width - 4 ))
  local left_width=42
  local right_width=$(( inner - left_width - 3 ))

  left="$(mq_truncate "$left" "$left_width")"
  right="$(mq_truncate "$right" "$right_width")"

  printf "│ %s │ %s │\n" \
    "$(mq_pad_right "$left" "$left_width")" \
    "$(mq_pad_right "$right" "$right_width")"
}

mq_dashboard_v3() {
  local title="${1:-MQLaunch v3}"
  local subtitle="${2:-Cyberpunk CRT Control Surface}"
  local mode="${3:-ONLINE}"
  local width="${4:-88}"

  local user host now cwd shell_name os_name branch repo dirty
  local mode_color dirty_color
  local top_glow bot_glow

  user="$(mq_user)"
  host="$(mq_host)"
  now="$(mq_time)"
  cwd="$(pwd)"
  shell_name="$(mq_shell_name)"
  os_name="$(mq_os_name)"
  branch="$(mq_git_branch)"
  repo="$(mq_git_repo)"
  dirty="$(mq_git_dirty)"

  mode_color="$NEON_GREEN"
  [[ "$mode" =~ ERROR|FAIL|OFFLINE ]] && mode_color="$NEON_RED"
  [[ "$mode" =~ WARN|WARNING ]] && mode_color="$NEON_YELLOW"
  [[ "$mode" =~ DEV|DEBUG|GIT ]] && mode_color="$NEON_CYAN"

  dirty_color="$NEON_GREEN"
  [[ "$dirty" == "DIRTY" ]] && dirty_color="$NEON_RED"

  top_glow="${NEON_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
  bot_glow="${NEON_MAGENTA}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"

  clear 2>/dev/null || true

  echo -e "${NEON_CYAN}${C_DIM}:::: CRT-SCAN ACTIVE :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::${C_RESET}"
  echo -e "${NEON_CYAN}${C_BOLD}$(mq_repeat "▄" "$width")${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}███╗   ███╗ ██████╗     ${NEON_CYAN}██████╗  █████╗ ███████╗██╗  ██╗${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}████╗ ████║██╔═══██╗    ${NEON_CYAN}██╔══██╗██╔══██╗██╔════╝██║  ██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██╔████╔██║██║   ██║    ${NEON_CYAN}██║  ██║███████║███████╗███████║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██║╚██╔╝██║██║▄▄ ██║    ${NEON_CYAN}██║  ██║██╔══██║╚════██║██╔══██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██║ ╚═╝ ██║╚██████╔╝    ${NEON_CYAN}██████╔╝██║  ██║███████║██║  ██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}╚═╝     ╚═╝ ╚══▀▀═╝     ${NEON_CYAN}╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝${C_RESET}"
  echo -e "${NEON_CYAN}${C_BOLD}$(mq_repeat "▀" "$width")${C_RESET}"
  echo

  echo -e "${NEON_PINK}${C_BOLD}╔$(mq_repeat "═" $((width - 2)))╗${C_RESET}"
  mq_print_row "${NEON_GREEN}${C_BOLD}SYSTEM${C_RESET}  $title" "${NEON_YELLOW}${C_BOLD}MODE${C_RESET}  ${mode_color}${C_BOLD}${mode}${C_RESET}" "$width"
  mq_print_row "${NEON_CYAN}${C_BOLD}PROFILE${C_RESET} $subtitle" "${NEON_RED}${C_BOLD}STATE${C_RESET} ${dirty_color}${C_BOLD}${dirty:-N/A}${C_RESET}" "$width"
  echo -e "${NEON_PINK}${C_BOLD}╠$(mq_repeat "═" $((width - 2)))╣${C_RESET}"

  mq_print_row "${C_BOLD}USER${C_RESET}   $(mq_truncate "$user" 30)" "${C_BOLD}HOST${C_RESET}   $(mq_truncate "$host" 30)" "$width"
  mq_print_row "${C_BOLD}TIME${C_RESET}   $now" "${C_BOLD}SHELL${C_RESET}  $(mq_truncate "$shell_name" 30)" "$width"
  mq_print_row "${C_BOLD}OS${C_RESET}     $(mq_truncate "$os_name" 30)" "${C_BOLD}PATH${C_RESET}   $(mq_truncate "$cwd" 36)" "$width"

  if [[ -n "$repo" || -n "$branch" ]]; then
    echo -e "${NEON_PINK}${C_BOLD}╠$(mq_repeat "═" $((width - 2)))╣${C_RESET}"
    mq_print_row "${NEON_CYAN}${C_BOLD}REPO${C_RESET}   ${repo:-N/A}" "${NEON_GREEN}${C_BOLD}BRANCH${C_RESET} ${branch:-N/A}" "$width"
  fi

  echo -e "${NEON_PINK}${C_BOLD}╠$(mq_repeat "═" $((width - 2)))╣${C_RESET}"
  mq_print_row "${NEON_RED}${C_BOLD}SIGNAL${C_RESET} cyberpunk crt / neon / git-aware / modular" "${NEON_YELLOW}${C_BOLD}AURA${C_RESET} old-school utility" "$width"
  mq_print_row "${C_DIM}scanlines simulated // dashboard online // zero fluff${C_RESET}" "${C_DIM}author: Mattias Camner${C_RESET}" "$width"
  echo -e "${NEON_PINK}${C_BOLD}╚$(mq_repeat "═" $((width - 2)))╝${C_RESET}"

  echo
  echo -e "${NEON_CYAN}${C_DIM}>>> phosphor glow stable // command surface ready${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mq_dashboard_v3 "$@"
fi
