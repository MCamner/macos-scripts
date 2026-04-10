#!/usr/bin/env bash

: "${C_RESET:=\033[0m}"
: "${C_BOLD:=\033[1m}"
: "${C_DIM:=\033[2m}"
: "${C_RED:=\033[31m}"
: "${C_GREEN:=\033[32m}"
: "${C_YELLOW:=\033[33m}"
: "${C_BLUE:=\033[34m}"
: "${C_MAGENTA:=\033[35m}"
: "${C_CYAN:=\033[36m}"
: "${C_WHITE:=\033[37m}"

mq_strip_ansi() {
  printf '%s' "$1" | perl -pe 's/\e\[[0-9;]*m//g'
}

mq_repeat_char() {
  local char="${1:--}"
  local count="${2:-80}"
  local out=""
  local i
  for (( i=0; i<count; i++ )); do
    out+="$char"
  done
  printf '%s' "$out"
}

mq_fit_text() {
  local text="$1"
  local width="${2:-88}"
  local stripped len

  stripped="$(mq_strip_ansi "$text")"
  len=${#stripped}

  if (( len > width )); then
    printf '%s' "${stripped:0:width-3}..."
    return
  fi

  printf '%s' "$text"
}

mq_pad_right() {
  local text="$1"
  local width="${2:-88}"
  local stripped len pad
  stripped="$(mq_strip_ansi "$text")"
  len=${#stripped}
  pad=$(( width - len ))
  (( pad < 0 )) && pad=0
  printf '%s' "$text"
  printf "%*s" "$pad" ""
}

mq_git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git branch --show-current 2>/dev/null
}

mq_repo_root_name() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || return 0
  basename "$(git rev-parse --show-toplevel 2>/dev/null)"
}

mq_dashboard() {
  local title="${1:-MQLaunch}"
  local subtitle="${2:-Modular Terminal Framework}"
  local mode="${3:-READY}"
  local width="${4:-88}"

  local user host now cwd branch repo shell_name os_name
  local top line1 line2 line3 line4 info1 info2 info3 info4 info5
  local badge statusline

  user="${USER:-unknown}"
  host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  cwd="$(pwd)"
  branch="$(mq_git_branch)"
  repo="$(mq_repo_root_name)"
  shell_name="$(basename "${SHELL:-shell}")"
  os_name="$(uname -s)"

  top="$(mq_repeat_char "=" "$width")"

  badge="${C_RED}${C_BOLD}>>>${C_RESET} ${C_GREEN}${C_BOLD}${mode}${C_RESET}"
  statusline="${C_DIM}scanline // terminal online // no nonsense${C_RESET}"

  echo -e "${C_CYAN}${C_BOLD}${top}${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}███╗   ███╗ ██████╗ ${C_CYAN}██████╗  █████╗ ███████╗██╗  ██╗${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}████╗ ████║██╔═══██╗${C_CYAN}██╔══██╗██╔══██╗██╔════╝██║  ██║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}██╔████╔██║██║   ██║${C_CYAN}██║  ██║███████║███████╗███████║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}██║╚██╔╝██║██║▄▄ ██║${C_CYAN}██║  ██║██╔══██║╚════██║██╔══██║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}██║ ╚═╝ ██║╚██████╔╝${C_CYAN}██████╔╝██║  ██║███████║██║  ██║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}╚═╝     ╚═╝ ╚══▀▀═╝ ${C_CYAN}╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}${top}${C_RESET}"

  line1="${C_GREEN}${C_BOLD}SYSTEM${C_RESET}   $(mq_fit_text "$title" 60)"
  line2="${C_YELLOW}${C_BOLD}PROFILE${C_RESET}  $(mq_fit_text "$subtitle" 60)"
  line3="${C_BLUE}${C_BOLD}STATUS${C_RESET}   ${badge}"
  line4="${C_DIM}${statusline}${C_RESET}"

  echo -e "$line1"
  echo -e "$line2"
  echo -e "$line3"
  echo -e "$line4"
  echo -e "${C_CYAN}${mq_repeat_char "-" "$width"}${C_RESET}"

  info1="${C_BOLD}User:${C_RESET} ${user}"
  info2="${C_BOLD}Host:${C_RESET} ${host}"
  info3="${C_BOLD}Time:${C_RESET} ${now}"
  info4="${C_BOLD}Shell:${C_RESET} ${shell_name}"
  info5="${C_BOLD}OS:${C_RESET} ${os_name}"

  echo -e "$(mq_pad_right "$info1" 28)$(mq_pad_right "$info2" 24)$info3"
  echo -e "$(mq_pad_right "$info4" 28)$info5"

  if [[ -n "$repo" || -n "$branch" ]]; then
    echo -e "${C_CYAN}${mq_repeat_char "-" "$width"}${C_RESET}"
    [[ -n "$repo" ]] && echo -e "${C_BOLD}Repo:${C_RESET} ${repo}"
    [[ -n "$branch" ]] && echo -e "${C_BOLD}Branch:${C_RESET} ${C_GREEN}${branch}${C_RESET}"
  fi

  echo -e "${C_CYAN}${mq_repeat_char "-" "$width"}${C_RESET}"
  echo -e "${C_BOLD}Path:${C_RESET} $(mq_fit_text "$cwd" $((width - 6)))"
  echo -e "${C_RED}${C_BOLD}◢${C_RESET}${C_DIM} old school utility // modular menus // git-aware workflows ${C_RED}${C_BOLD}◣${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}${top}${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mq_dashboard "$@"
fi
