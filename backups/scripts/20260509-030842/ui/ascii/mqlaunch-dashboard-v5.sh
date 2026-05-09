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

mq_term_width() {
  local cols
  cols="$(tput cols 2>/dev/null || true)"
  if [[ -z "$cols" ]]; then
    cols=92
  fi
  if (( cols < 60 )); then
    cols=60
  fi
  printf '%s' "$cols"
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

  local counts ahead behind
  counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || true)"
  if [[ -n "$counts" ]]; then
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
    local pages_free pages_active pages_inactive pages_speculative pages_wired total used pct
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
  local inner=$(( width - 6 - ${#title} ))
  (( inner < 0 )) && inner=0
  printf "┌─ %s %s┐\n" "$title" "$(mq_repeat "─" "$inner")"
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

  if (( right_width < 10 )); then
    left_width=$(( inner / 2 - 1 ))
    right_width=$(( inner - left_width - 3 ))
  fi

  left="$(mq_truncate "$left" "$left_width")"
  right="$(mq_truncate "$right" "$right_width")"

  printf "│ %s │ %s │\n" \
    "$(mq_pad_right "$left" "$left_width")" \
    "$(mq_pad_right "$right" "$right_width")"
}

mq_box_single() {
  local text="$1"
  local width="$2"
  local inner=$(( width - 4 ))
  text="$(mq_truncate "$text" "$inner")"
  printf "│ %s │\n" "$(mq_pad_right "$text" "$inner")"
}

mq_bar() {
  local label="$1"
  local value="${2:-0}"
  local max="${3:-10}"
  local width="${4:-24}"
  local color="${5:-$NEON_GREEN}"

  local filled empty safe_value i bar=""
  safe_value="$value"
  (( safe_value < 0 )) && safe_value=0
  (( max < 1 )) && max=1

  filled=$(( safe_value * width / max ))
  (( filled > width )) && filled="$width"
  empty=$(( width - filled ))

  for (( i=0; i<filled; i++ )); do
    bar+="█"
  done
  for (( i=0; i<empty; i++ )); do
    bar+="░"
  done

  printf '%s %s%s%s %s' "$label" "$color" "$bar" "$C_RESET" "$value"
}

mqlaunch_dashboard_v5() {
  local title="${1:-MQLAUNCH}"
  local subtitle="${2:-Adaptive Cyberpunk CRT Command Center}"
  local mode="${3:-ONLINE}"

  local width compact
  local mode_color state_color
  local user host now shell_name os_name cwd repo branch dirty counts staged unstaged untracked ahead_behind
  local mem_widget batt_widget
  local bar_max

  width="$(mq_term_width)"
  compact=0
  (( width < 86 )) && compact=1

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

  [[ -z "$staged" ]] && staged=0
  [[ -z "$unstaged" ]] && unstaged=0
  [[ -z "$untracked" ]] && untracked=0

  bar_max=$(( staged + unstaged + untracked ))
  (( bar_max < 5 )) && bar_max=5

  mode_color="$(mq_mode_color "$mode")"
  state_color="$(mq_state_color "$dirty")"

  clear 2>/dev/null || true

  echo -e "${NEON_CYAN}${C_DIM}::: PHOSPHOR GRID ACTIVE :::::::::::::::::::::::::::::::::::::::::::::::::::::::::${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}███╗   ███╗ ██████╗ ██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}████╗ ████║██╔═══██╗██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██╔████╔██║██║   ██║██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██║╚██╔╝██║██║▄▄ ██║██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}██║ ╚═╝ ██║╚██████╔╝███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║${C_RESET}"
  echo -e "${NEON_PINK}${C_BOLD}╚═╝     ╚═╝ ╚══▀▀═╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝${C_RESET}"
  echo -e "${NEON_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
  echo -e "${NEON_GREEN}${C_BOLD}${title}${C_RESET} ${C_DIM}// ${subtitle}${C_RESET}"
  echo -e "${mode_color}${C_BOLD}MODE: ${mode}${C_RESET}   ${state_color}${C_BOLD}STATE: ${dirty:-N/A}${C_RESET}   ${NEON_YELLOW}${C_BOLD}${mem_widget}${C_RESET}   ${NEON_CYAN}${C_BOLD}${batt_widget}${C_RESET}"
  echo

  mq_box_top "SYSTEM" "$width"
  if (( compact == 1 )); then
    mq_box_single "USER  ${user}" "$width"
    mq_box_single "HOST  ${host}" "$width"
    mq_box_single "TIME  ${now}" "$width"
    mq_box_single "SHELL ${shell_name}" "$width"
    mq_box_single "OS    ${os_name}" "$width"
    mq_box_single "PATH  ${cwd}" "$width"
  else
    mq_box_row "USER  ${user}" "HOST  ${host}" "$width"
    mq_box_row "TIME  ${now}" "SHELL ${shell_name}" "$width"
    mq_box_row "OS    ${os_name}" "PATH  ${cwd}" "$width"
  fi
  mq_box_bottom "$width"
  echo

  mq_box_top "GIT WIDGETS" "$width"
  if (( compact == 1 )); then
    mq_box_single "REPO     ${repo:-N/A}" "$width"
    mq_box_single "BRANCH   ${branch:-N/A}" "$width"
    mq_box_single "STATE    ${dirty:-N/A}" "$width"
    mq_box_single "UPSTREAM ${ahead_behind:-N/A}" "$width"
    mq_box_single "$(mq_bar "STAGED  " "$staged" "$bar_max" 18 "$NEON_GREEN")" "$width"
    mq_box_single "$(mq_bar "UNSTAGED" "$unstaged" "$bar_max" 18 "$NEON_YELLOW")" "$width"
    mq_box_single "$(mq_bar "UNTRACK " "$untracked" "$bar_max" 18 "$NEON_RED")" "$width"
  else
    mq_box_row "REPO     ${repo:-N/A}" "BRANCH   ${branch:-N/A}" "$width"
    mq_box_row "STATE    ${dirty:-N/A}" "UPSTREAM ${ahead_behind:-N/A}" "$width"
    mq_box_single "$(mq_bar "STAGED  " "$staged" "$bar_max" 34 "$NEON_GREEN")" "$width"
    mq_box_single "$(mq_bar "UNSTAGED" "$unstaged" "$bar_max" 34 "$NEON_YELLOW")" "$width"
    mq_box_single "$(mq_bar "UNTRACK " "$untracked" "$bar_max" 34 "$NEON_RED")" "$width"
  fi
  mq_box_bottom "$width"
  echo

  mq_box_top "SHORTCUTS" "$width"
  if (( compact == 1 )); then
    mq_box_single "git -> modular git menu" "$width"
    mq_box_single "gitlaunch -> legacy git menu" "$width"
    mq_box_single "dev -> dev tools menu" "$width"
    mq_box_single "tools -> tools menu" "$width"
  else
    mq_box_row "git        -> modular git menu" "gitlaunch  -> legacy git menu" "$width"
    mq_box_row "dev        -> dev tools menu" "tools      -> tools menu" "$width"
    mq_box_row "adaptive layout active" "brand: MQLAUNCH" "$width"
  fi
  mq_box_bottom "$width"
  echo

  echo -e "${NEON_RED}${C_BOLD}>>> READY${C_RESET} ${C_DIM}// adaptive neon command surface stable${C_RESET}"
  echo -e "${NEON_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mqlaunch_dashboard_v5 "$@"
fi
