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

NEON_PINK="${C_MAGENTA}"
NEON_CYAN="${C_CYAN}"
NEON_GREEN="${C_GREEN}"
NEON_YELLOW="${C_YELLOW}"
NEON_RED="${C_RED}"

mq_strip_ansi() {
  printf '%s' "$1" | perl -pe 's/\e\[[0-9;]*m//g'
}

mq_len() {
  local s="$1"
  s="$(mq_strip_ansi "$s")"
  printf '%s' "${#s}"
}

mq_repeat() {
  local char="${1:--}"
  local count="${2:-10}"
  local out=""
  local i
  for (( i=0; i<count; i++ )); do
    out+="$char"
  done
  printf '%s' "$out"
}

mq_pad_right() {
  local text="$1"
  local width="$2"
  local len pad
  len="$(mq_len "$text")"
  pad=$(( width - len ))
  (( pad < 0 )) && pad=0
  printf '%s' "$text"
  printf "%*s" "$pad" ""
}

mq_truncate() {
  local text="$1"
  local width="${2:-20}"
  local stripped
  stripped="$(mq_strip_ansi "$text")"

  if (( ${#stripped} <= width )); then
    printf '%s' "$text"
  else
    printf '%s' "${stripped:0:width-3}..."
  fi
}

mq_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || return 0
  basename "$(git rev-parse --show-toplevel 2>/dev/null)"
}

mq_git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git branch --show-current 2>/dev/null
}

mq_git_dirty_state() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    printf '%s' "DIRTY"
  else
    printf '%s' "CLEAN"
  fi
}

mq_git_counts() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local staged unstaged untracked
  staged="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
  unstaged="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
  untracked="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"

  printf '%s|%s|%s' "$staged" "$unstaged" "$untracked"
}

mq_git_ahead_behind() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || {
    printf '%s' "no-upstream"
    return 0
  }

  local counts
  counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || true)"
  if [[ -n "$counts" ]]; then
    local ahead behind
    ahead="$(printf '%s' "$counts" | awk '{print $1}')"
    behind="$(printf '%s' "$counts" | awk '{print $2}')"
    printf '↑%s ↓%s' "$ahead" "$behind"
  else
    printf '%s' "unknown"
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

mq_cwd() {
  pwd
}

mq_memory_widget() {
  if command -v vm_stat >/dev/null 2>&1; then
    local page_size pages_free pages_active pages_inactive pages_speculative pages_wired total used pct
    page_size="$(vm_stat | head -n 1 | awk '{gsub("\\.","",$8); print $8}')"
    [[ -z "$page_size" ]] && page_size=4096

    pages_free="$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
    pages_active="$(vm_stat | awk '/Pages active/ {gsub("\\.","",$3); print $3}')"
    pages_inactive="$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
    pages_speculative="$(vm_stat | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')"
    pages_wired="$(vm_stat | awk '/Pages wired down/ {gsub("\\.","",$4); print $4}')"

    pages_free="${pages_free:-0}"
    pages_active="${pages_active:-0}"
    pages_inactive="${pages_inactive:-0}"
    pages_speculative="${pages_speculative:-0}"
    pages_wired="${pages_wired:-0}"

    total=$(( pages_free + pages_active + pages_inactive + pages_speculative + pages_wired ))
    used=$(( pages_active + pages_wired ))

    if (( total > 0 )); then
      pct=$(( used * 100 / total ))
      printf 'MEM %s%%' "$pct"
      return
    fi
  fi

  printf '%s' "MEM N/A"
}

mq_battery_widget() {
  if command -v pmset >/dev/null 2>&1; then
    local batt
    batt="$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -n 1 || true)"
    if [[ -n "$batt" ]]; then
      printf 'BAT %s' "$batt"
      return
    fi
  fi

  printf '%s' "BAT N/A"
}

mq_mode_color() {
  local mode="$1"
  if [[ "$mode" =~ ERROR|FAIL|OFFLINE ]]; then
    printf '%s' "$NEON_RED"
  elif [[ "$mode" =~ WARN|WARNING ]]; then
    printf '%s' "$NEON_YELLOW"
  elif [[ "$mode" =~ DEV|DEBUG|GIT ]]; then
    printf '%s' "$NEON_CYAN"
  else
    printf '%s' "$NEON_GREEN"
  fi
}

mq_state_color() {
  local state="$1"
  if [[ "$state" == "DIRTY" ]]; then
    printf '%s' "$NEON_RED"
  else
    printf '%s' "$NEON_GREEN"
  fi
}

mq_box_top() {
  local title="$1"
  local width="$2"
  local inner=$(( width - 4 ))
  printf "┌─ %s%s ─┐\n" \
    "$title" \
    "$(mq_repeat "─" $(( inner - ${#title} )))"
}

mq_box_bottom() {
  local width="$1"
  printf "└%s┘\n" "$(mq_repeat "─" $(( width - 2 )))"
}

mq_box_row() {
  local left="$1"
  local right="$2"
  local width="$3"
  local inner=$(( width - 4 ))
  local left_width=24
  local right_width=$(( inner - left_width - 3 ))

  left="$(mq_truncate "$left" "$left_width")"
  right="$(mq_truncate "$right" "$right_width")"

  printf "│ %s │ %s │\n" \
    "$(mq_pad_right "$left" "$left_width")" \
    "$(mq_pad_right "$right" "$right_width")"
}

mqlaunch_dashboard_v4() {
  local title="${1:-MQLAUNCH}"
  local subtitle="${2:-Cyberpunk CRT Command Center}"
  local mode="${3:-ONLINE}"

  local width=92
  local mode_color state_color
  local user host now shell_name os_name cwd repo branch dirty counts staged unstaged untracked ahead_behind
  local mem_widget batt_widget

  user="$(mq_user)"
  host="$(mq_host)"
  now="$(mq_time)"
  shell_name="$(mq_shell_name)"
  os_name="$(mq_os_name)"
  cwd="$(mq_cwd)"
  repo="$(mq_git_repo)"
  branch="$(mq_git_branch)"
  dirty="$(mq_git_dirty_state)"
  counts="$(mq_git_counts)"
  staged="$(printf '%s' "$counts" | cut -d'|' -f1)"
  unstaged="$(printf '%s' "$counts" | cut -d'|' -f2)"
  untracked="$(printf '%s' "$counts" | cut -d'|' -f3)"
  ahead_behind="$(mq_git_ahead_behind)"
  mem_widget="$(mq_memory_widget)"
  batt_widget="$(mq_battery_widget)"

  mode_color="$(mq_mode_color "$mode")"
  state_color="$(mq_state_color "$dirty")"

  clear 2>/dev/null || true

  echo -e "${NEON_CYAN}${C_DIM}::: PHOSPHOR GRID ACTIVE :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}███╗   ███╗ ██████╗ ██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}████╗ ████║██╔═══██╗██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██╔████╔██║██║   ██║██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██║╚██╔╝██║██║▄▄ ██║██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██║ ╚═╝ ██║╚██████╔╝███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}╚═╝     ╚═╝ ╚══▀▀═╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝${C_RESET}"
  echo -e "${NEON_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
  echo -e "${NEON_GREEN}${C_BOLD}${title}${C_RESET} ${C_DIM}// ${subtitle}${C_RESET}"
  echo -e "${mode_color}${C_BOLD}MODE: ${mode}${C_RESET}   ${state_color}${C_BOLD}STATE: ${dirty:-N/A}${C_RESET}   ${NEON_YELLOW}${C_BOLD}${mem_widget}${C_RESET}   ${NEON_CYAN}${C_BOLD}${batt_widget}${C_RESET}"
  echo -e "${NEON_CYAN}${C_DIM}scanlines online // widget surface active // zero fluff${C_RESET}"
  echo

  mq_box_top "SYSTEM" 92
  mq_box_row "USER  ${user}" "HOST  ${host}" 92
  mq_box_row "TIME  ${now}" "SHELL ${shell_name}" 92
  mq_box_row "OS    ${os_name}" "PATH  ${cwd}" 92
  mq_box_bottom 92
  echo

  mq_box_top "GIT WIDGETS" 92
  mq_box_row "REPO     ${repo:-N/A}" "BRANCH   ${branch:-N/A}" 92
  mq_box_row "STATE    ${dirty:-N/A}" "UPSTREAM ${ahead_behind:-N/A}" 92
  mq_box_row "STAGED   ${staged:-0}" "UNSTAGED ${unstaged:-0}" 92
  mq_box_row "UNTRACKD ${untracked:-0}" "MODE     ${mode}" 92
  mq_box_bottom 92
  echo

  mq_box_top "SHORTCUTS" 92
  mq_box_row "git        -> modular git menu" "gitlaunch  -> legacy git menu" 92
  mq_box_row "dev        -> dev tools menu" "tools      -> tools menu" 92
  mq_box_row "Use this dashboard in launcher + menus" "Brand: MQLAUNCH" 92
  mq_box_bottom 92
  echo

  echo -e "${NEON_RED}${C_BOLD}>>> READY${C_RESET} ${C_DIM}// neon command surface stable${C_RESET}"
  echo -e "${NEON_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mqlaunch_dashboard_v4 "$@"
fi
