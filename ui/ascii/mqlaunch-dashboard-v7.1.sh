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

MQ_PINK="\033[95m"
LAUNCH_PINK="\033[35m"
ACCENT_CYAN="${C_CYAN}"
ACCENT_GREEN="${C_GREEN}"
ACCENT_YELLOW="${C_YELLOW}"
ACCENT_RED="${C_RED}"
ACCENT_DIM="${C_DIM}"

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
  [[ -z "$cols" ]] && cols=92
  (( cols < 60 )) && cols=60
  printf '%s' "$cols"
}

mq_user() { printf '%s' "${USER:-unknown}"; }
mq_host() { hostname -s 2>/dev/null || hostname 2>/dev/null || printf '%s' "unknown"; }
mq_time() { date '+%Y-%m-%d %H:%M:%S'; }
mq_shell_name() { basename "${SHELL:-shell}"; }
mq_os_name() { uname -s; }
mq_cwd() { pwd; }

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
    printf '%s' "$ACCENT_RED"
  elif [[ "$mode" =~ WARN|WARNING ]]; then
    printf '%s' "$ACCENT_YELLOW"
  elif [[ "$mode" =~ DEV|DEBUG|GIT ]]; then
    printf '%s' "$ACCENT_CYAN"
  else
    printf '%s' "$ACCENT_GREEN"
  fi
}

mq_state_color() {
  local state="$1"
  if [[ "$state" == "DIRTY" ]]; then
    printf '%s' "$ACCENT_RED"
  else
    printf '%s' "$ACCENT_GREEN"
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
  local color="${5:-$ACCENT_GREEN}"

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

mq_dirty_severity() {
  local staged="${1:-0}"
  local unstaged="${2:-0}"
  local untracked="${3:-0}"
  local total=$(( staged + unstaged + untracked ))

  if (( total == 0 )); then
    printf '%s' "STABLE"
  elif (( total <= 2 )); then
    printf '%s' "LOW"
  elif (( total <= 6 )); then
    printf '%s' "MEDIUM"
  elif (( total <= 12 )); then
    printf '%s' "HIGH"
  else
    printf '%s' "CRITICAL"
  fi
}

mq_dirty_severity_color() {
  local severity="$1"
  case "$severity" in
    STABLE) printf '%s' "$ACCENT_GREEN" ;;
    LOW) printf '%s' "$ACCENT_CYAN" ;;
    MEDIUM) printf '%s' "$ACCENT_YELLOW" ;;
    HIGH|CRITICAL) printf '%s' "$ACCENT_RED" ;;
    *) printf '%s' "$C_WHITE" ;;
  esac
}

mq_severity_meter() {
  local severity="$1"
  local color="$2"
  local width="${3:-20}"
  local filled=0
  local i bar=""

  case "$severity" in
    STABLE) filled=2 ;;
    LOW) filled=6 ;;
    MEDIUM) filled=11 ;;
    HIGH) filled=16 ;;
    CRITICAL) filled=20 ;;
    *) filled=0 ;;
  esac

  (( filled > width )) && filled="$width"

  for (( i=0; i<filled; i++ )); do
    bar+="█"
  done
  for (( i=filled; i<width; i++ )); do
    bar+="░"
  done

  printf '%s%s%s %s' "$color" "$bar" "$C_RESET" "$severity"
}

mqlaunch_dashboard_v71() {
  local title="${1:-MQLAUNCH}"
  local subtitle="${2:-Branded Neon Command Surface}"
  local mode="${3:-ONLINE}"

  local width compact
  local mode_color state_color severity severity_color
  local user host now shell_name os_name cwd repo branch dirty counts staged unstaged untracked ahead_behind
  local mem_widget batt_widget bar_max

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

  severity="$(mq_dirty_severity "$staged" "$unstaged" "$untracked")"
  severity_color="$(mq_dirty_severity_color "$severity")"

  mode_color="$(mq_mode_color "$mode")"
  state_color="$(mq_state_color "$dirty")"

  clear 2>/dev/null || true

  echo -e "${ACCENT_CYAN}${ACCENT_DIM}::: PHOSPHOR GRID ACTIVE :::::::::::::::::::::::::::::::::::::::::::::::::::::::::${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}███╗   ███╗ ██████╗ ${LAUNCH_PINK}██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}████╗ ████║██╔═══██╗${LAUNCH_PINK}██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}██╔████╔██║██║   ██║${LAUNCH_PINK}██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}██║╚██╔╝██║██║▄▄ ██║${LAUNCH_PINK}██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}██║ ╚═╝ ██║╚██████╔╝${LAUNCH_PINK}███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}╚═╝     ╚═╝ ╚══▀▀═╝ ${LAUNCH_PINK}╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝${C_RESET}"
  echo -e "${ACCENT_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
  echo -e "${MQ_PINK}${C_BOLD}MQ${C_RESET}${LAUNCH_PINK}${C_BOLD}LAUNCH${C_RESET} ${C_DIM}// ${subtitle}${C_RESET}"
  echo -e "${mode_color}${C_BOLD}MODE: ${mode}${C_RESET}   ${state_color}${C_BOLD}STATE: ${dirty:-N/A}${C_RESET}   ${severity_color}${C_BOLD}SEVERITY: ${severity}${C_RESET}"
  echo -e "${ACCENT_YELLOW}${C_BOLD}${mem_widget}${C_RESET}   ${ACCENT_CYAN}${C_BOLD}${batt_widget}${C_RESET}   ${C_DIM}adaptive layout active${C_RESET}"
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
    mq_box_single "SEVERITY $(mq_severity_meter "$severity" "$severity_color" 18)" "$width"
    mq_box_single "$(mq_bar "STAGED  " "$staged" "$bar_max" 18 "$ACCENT_GREEN")" "$width"
    mq_box_single "$(mq_bar "UNSTAGED" "$unstaged" "$bar_max" 18 "$ACCENT_YELLOW")" "$width"
    mq_box_single "$(mq_bar "UNTRACK " "$untracked" "$bar_max" 18 "$ACCENT_RED")" "$width"
  else
    mq_box_row "REPO     ${repo:-N/A}" "BRANCH   ${branch:-N/A}" "$width"
    mq_box_row "STATE    ${dirty:-N/A}" "UPSTREAM ${ahead_behind:-N/A}" "$width"
    mq_box_single "SEVERITY $(mq_severity_meter "$severity" "$severity_color" 34)" "$width"
    mq_box_single "$(mq_bar "STAGED  " "$staged" "$bar_max" 34 "$ACCENT_GREEN")" "$width"
    mq_box_single "$(mq_bar "UNSTAGED" "$unstaged" "$bar_max" 34 "$ACCENT_YELLOW")" "$width"
    mq_box_single "$(mq_bar "UNTRACK " "$untracked" "$bar_max" 34 "$ACCENT_RED")" "$width"
  fi
  mq_box_bottom "$width"
  echo

  mq_box_top "LIVE SHORTCUTS" "$width"
  if [[ "$mode" =~ GIT ]]; then
    if (( compact == 1 )); then
      mq_box_single "git status / git pull --rebase / git push" "$width"
      mq_box_single "mqlaunch workflows / mqlaunch system / mqlaunch git" "$width"
      mq_box_single "Try: mqlaunch system check / release notes / git" "$width"
    else
      mq_box_row "git status / git pull --rebase" "git push / git fetch --all" "$width"
      mq_box_row "mqlaunch workflows / system / git" "mqlaunch release / dev / help" "$width"
      mq_box_row "Try: mqlaunch system check" "Try: mqlaunch release notes" "$width"
    fi
  elif [[ "$mode" =~ DEV ]]; then
    if (( compact == 1 )); then
      mq_box_single "mqlaunch workflows / mqlaunch system / mqlaunch git" "$width"
      mq_box_single "mqlaunch release / mqlaunch dev / mqlaunch help" "$width"
      mq_box_single "Try: mqlaunch system check / release notes / git" "$width"
    else
      mq_box_row "mqlaunch workflows / system / git" "mqlaunch release / dev / help" "$width"
      mq_box_row "Try: mqlaunch system check" "Try: mqlaunch release notes" "$width"
      mq_box_row "Try: mqlaunch git" "direct command mode enabled" "$width"
    fi
  else
    if (( compact == 1 )); then
      mq_box_single "mqlaunch workflows / mqlaunch system / mqlaunch git" "$width"
      mq_box_single "mqlaunch release / mqlaunch dev / mqlaunch help" "$width"
      mq_box_single "Try: mqlaunch system check / release notes / git" "$width"
    else
      mq_box_row "mqlaunch workflows / system / git" "mqlaunch release / dev / help" "$width"
      mq_box_row "Try: mqlaunch system check" "Try: mqlaunch release notes" "$width"
      mq_box_row "Try: mqlaunch git" "direct command mode enabled" "$width"
    fi
  fi
  mq_box_bottom "$width"
  echo

  echo -e "${ACCENT_RED}${C_BOLD}>>> READY${C_RESET} ${C_DIM}// polished branded command surface stable${C_RESET}"
  echo -e "${ACCENT_CYAN}${C_BOLD}$(mq_repeat "═" "$width")${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mqlaunch_dashboard_v71 "$@"
fi
