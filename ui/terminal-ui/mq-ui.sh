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
# Command Surface (v3) styling
# ------------------------------------------------------------
surface_terminal_width() {
  local cols width
  cols="$(tput cols 2>/dev/null || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="${BOX_INNER:-92}"

  width="$cols"
  (( width > 112 )) && width=112
  (( width < 60 )) && width=60
  printf "%s" "$width"
}

# Handles surface visible len.
surface_visible_len() {
  local esc stripped
  esc="$(printf '\033')"
  stripped="$(printf '%s' "$1" | sed "s/${esc}\[[0-9;]*[mKHJsu]//g")"
  printf '%d' "${#stripped}"
}

# Handles surface pad.
surface_pad() {
  local text="$1"
  local width="$2"
  local visible pad
  visible="$(surface_visible_len "$text")"
  pad=$(( width - visible ))
  (( pad < 0 )) && pad=0
  printf "%s%*s" "$text" "$pad" ""
}

# Handles surface top.
surface_top() {
  local title="$1"
  local width="$2"
  local color="$3"
  local fill=$(( width - 5 - ${#title} ))
  (( fill < 0 )) && fill=0
  printf "%b┌─ %s %s┐%b\n" "$color" "$title" "$(repeat_char "$fill" "─")" "$C_RESET"
}

# Handles surface bottom.
surface_bottom() {
  local width="$1"
  local color="$2"
  printf "%b└%s┘%b\n" "$color" "$(repeat_char $(( width - 2 )) "─")" "$C_RESET"
}

# Handles surface row.
surface_row() {
  local text="$1"
  local width="$2"
  local color="$3"
  local inner=$(( width - 4 ))
  printf "%b│ %s │%b\n" "$color" "$(surface_pad "$text" "$inner")" "$C_RESET"
}

# Handles surface split row.
surface_split_row() {
  local left="$1"
  local right="$2"
  local width="$3"
  local color="$4"
  local inner left_width right_width
  inner=$(( width - 4 ))
  left_width=$(( inner / 2 ))
  right_width=$(( inner - left_width - 1 ))
  printf "%b│ %s %s │%b\n" \
    "$color" \
    "$(surface_pad "$left" "$left_width")" \
    "$(surface_pad "$right" "$right_width")" \
    "$C_RESET"
}

# Returns the canonical Git status snapshot used by mqlaunch surfaces.
# Format: staged|unstaged|untracked|changes|state|severity|next_action
mq_git_status_snapshot() {
  local repo="${1:-.}"
  local porcelain staged unstaged untracked changes state severity next_action

  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '0|0|0|0|NO_REPO|UNKNOWN|Open a Git repository'
    return 0
  fi

  porcelain="$(git -C "$repo" status --porcelain=v1 --untracked-files=normal 2>/dev/null || true)"
  staged="$(printf '%s\n' "$porcelain" | awk 'length($0) >= 2 && substr($0, 1, 1) != " " && substr($0, 1, 1) != "?" {count++} END {print count + 0}')"
  unstaged="$(printf '%s\n' "$porcelain" | awk 'length($0) >= 2 && substr($0, 1, 2) != "??" && substr($0, 2, 1) != " " {count++} END {print count + 0}')"
  untracked="$(printf '%s\n' "$porcelain" | awk 'substr($0, 1, 2) == "??" {count++} END {print count + 0}')"
  changes="$(printf '%s\n' "$porcelain" | awk 'length($0) >= 2 {count++} END {print count + 0}')"

  if (( changes == 0 )); then
    state="CLEAN"
    severity="STABLE"
    next_action="Nothing to commit"
  else
    state="DIRTY"
    if (( changes <= 2 )); then
      severity="LOW"
    elif (( changes <= 6 )); then
      severity="MEDIUM"
    elif (( changes <= 12 )); then
      severity="HIGH"
    else
      severity="CRITICAL"
    fi

    if (( unstaged > 0 || untracked > 0 )); then
      next_action="Review diff, then stage selected files"
    elif (( staged > 0 )); then
      next_action="Commit staged changes"
    else
      next_action="Review git status"
    fi
  fi

  printf '%s|%s|%s|%s|%s|%s|%s' \
    "$staged" "$unstaged" "$untracked" "$changes" "$state" "$severity" "$next_action"
}

# Handles surface git state.
surface_git_state() {
  local repo="${1:-.}"
  local snapshot count state
  snapshot="$(mq_git_status_snapshot "$repo")"
  count="$(printf '%s' "$snapshot" | cut -d'|' -f4)"
  state="$(printf '%s' "$snapshot" | cut -d'|' -f5)"

  if [[ "$state" == "CLEAN" ]]; then
    printf "Clean"
  elif [[ "$state" == "NO_REPO" ]]; then
    printf "No Git"
  else
    printf "Dirty (%s)" "$count"
  fi
}

# Handles surface panel color.
surface_panel_color() {
  if [[ -t 1 ]]; then
    printf '\033[0;37m'
  fi
}

# Handles surface panel header.
surface_panel_header() {
  local title="$1"
  local mode="${2:-$1}"
  local width="$3"
  local color="$4"
  local host user git_state

  host="$(hostname -s 2>/dev/null || echo unknown)"
  user="${USER:-unknown}"
  git_state="$(surface_git_state)"

  surface_top "$title" "$width" "$color"
  surface_row "Host: $host   User: $user   Mode: $mode   Git: $git_state" "$width" "$color"
  surface_row "" "$width" "$color"
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
repeat_char() {
  local count="$1"
  local char="$2"
  local i out=""
  # Build by concatenation, not `tr`: tr is byte-based, so under a non-UTF-8
  # locale it splits a multibyte box glyph (─ = E2 94 80) into lone bytes that
  # render as vertical replacement marks. Appending the char preserves it.
  (( count < 0 )) && count=0
  for (( i = 0; i < count; i++ )); do
    out+="$char"
  done
  printf '%s' "$out"
}

# Handles border.
border() {
  printf '%s\n' "$(repeat_char "$BOX_INNER" "-")"
}

# Handles row.
row() {
  local text="$1"
  printf "%-*.*s\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

# Handles row bold.
row_bold() {
  local text="$1"
  printf "${C_BOLD}%-*.*s${C_RESET}\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

# Handles row menu title.
row_menu_title() {
  local text="$1"
  if [[ -t 1 ]]; then
    printf "\033[1m%-*.*s\033[0m\n" "$BOX_INNER" "$BOX_INNER" "$text"
  else
    row "$text"
  fi
}

# Handles row2.
row2() {
  local c1="$1"
  local c2="$2"
  row "$(printf '%-40s %-40s' "$c1" "$c2")"
}

# Handles row3.
row3() {
  local c1="$1"
  local c2="$2"
  local c3="$3"
  row "$(printf '%-26s %-26s %-26s' "$c1" "$c2" "$c3")"
}

# Handles empty row.
empty_row() {
  printf '\n'
}

# Handles header dual row.
header_dual_row() {
  local left="$1"
  local right="$2"
  printf "%-54s %33s\n" "$left" "$right"
}

# Handles pause enter.
pause_enter() {
  if [[ -n "${MQ_NO_TUI:-}" || ! -t 0 || ! -t 1 ]]; then
    return 0
  fi
  echo
  printf 'Press Enter to continue...'
  read -r _
}

# Handles read prompt.
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

# Handles read menu choice.
read_menu_choice() {
  local label="${2:-mqlaunch}"
  local sep_width sep sep_color

  sep_width="$(surface_terminal_width)"
  sep="$(repeat_char "$sep_width" "─")"
  sep_color="$(surface_panel_color)"

  printf "\n%b%s%b\n" "$sep_color" "$sep" "${C_RESET:-}"
  printf "%b%s > %b\n" "${C_TITLE:-}" "$label" "${C_RESET:-}"
  printf "%b%s%b\n" "$sep_color" "$sep" "${C_RESET:-}"
  printf "%b>> option, mqlaunch command, shell command, or x to exit%b\n" "${C_DIM:-}" "${C_RESET:-}"
  if [[ -t 0 && -t 1 ]]; then
    printf "\033[3A\r"
    printf "%b%s > %b" "${C_TITLE:-}" "$label" "${C_RESET:-}"
  fi

  REPLY=""
  if [[ -n "${MQ_NO_TUI:-}" || ! -t 0 || ! -t 1 ]]; then
    return 1
  fi
  IFS= read -r REPLY
  if [[ -t 0 && -t 1 ]]; then
    printf "\033[2B\r\n"
  fi
}

# Sets terminal title.
set_terminal_title() {
  printf '\033]0;%s — %s\007' "$APP_TITLE" "$APP_SUBTITLE"
}

# Handles clear screen.
clear_screen() {
  if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
    tput clear 2>/dev/null || printf '\033[H\033[2J'
  else
    printf '\033[H\033[2J'
  fi
  set_terminal_title
}

# Handles short host.
short_host() {
  hostname -s 2>/dev/null || hostname
}

# Gets nickname.
get_nickname() {
  if [[ -f "$HOME/.mqlaunch_nickname" ]]; then
    cat "$HOME/.mqlaunch_nickname"
  else
    echo "${USER:-Användare}"
  fi
}

# Prints header.
# Cached dashboard header state. Rapid menu transitions — returning from a
# sub-menu (Back) or re-rendering after invalid input — would otherwise re-fork
# the dashboard subprocess (pmset + several git calls) on every loop tick. The
# cache reuses the last render within a short TTL so only genuinely fresh ticks
# pay the cost.
MQ_DASHBOARD_CACHE_OUTPUT=""
MQ_DASHBOARD_CACHE_KEY=""
MQ_DASHBOARD_CACHE_TS=0

# Invalidates the cached dashboard header. Call after an action that changes
# what the header reports (e.g. a commit) so the next render recomputes.
mq_dashboard_cache_invalidate() {
  MQ_DASHBOARD_CACHE_OUTPUT=""
  MQ_DASHBOARD_CACHE_KEY=""
  MQ_DASHBOARD_CACHE_TS=0
}

# Renders the dashboard header, reusing a cached render within MQ_DASHBOARD_CACHE_TTL
# seconds (default 5; set to 0 to disable caching). The cache key includes the
# working directory because the dashboard's git status depends on it.
print_dashboard_header() {
  local dashboard="$1"
  local ttl now key
  ttl="${MQ_DASHBOARD_CACHE_TTL:-5}"
  now="$(date +%s)"
  key="${APP_TITLE}|${APP_SUBTITLE}|${PWD}"

  if [[ "$ttl" != "0" \
        && -n "$MQ_DASHBOARD_CACHE_OUTPUT" \
        && "$MQ_DASHBOARD_CACHE_KEY" == "$key" \
        && $(( now - MQ_DASHBOARD_CACHE_TS )) -lt "$ttl" ]]; then
    printf '%s\n' "$MQ_DASHBOARD_CACHE_OUTPUT"
    return
  fi

  MQ_DASHBOARD_CACHE_OUTPUT="$(bash "$dashboard" "$APP_TITLE" "$APP_SUBTITLE" "ONLINE")"
  MQ_DASHBOARD_CACHE_KEY="$key"
  MQ_DASHBOARD_CACHE_TS="$now"
  printf '%s\n' "$MQ_DASHBOARD_CACHE_OUTPUT"
}

# Prints header.
print_header() {
  local dashboard nickname

  if [[ "${MQ_USE_DASHBOARD_HEADER:-0}" == "1" ]]; then
    dashboard="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}/ui/ascii/mqlaunch-dashboard-v7.1.sh"
    if [[ -f "$dashboard" ]]; then
      print_dashboard_header "$dashboard"
      printf '\n'
      return
    fi
  fi

  nickname="$(get_nickname)"

  clear_screen
  border
  header_dual_row "$APP_TITLE" "        .-."
  header_dual_row "$APP_SUBTITLE" "       (o o)"
  header_dual_row "$APP_AUTHOR" "       | O \\"
  header_dual_row "Hej, $nickname!" "        \\   \\"
  header_dual_row "" "         \`~~~'"
  border
}

# Prints footer.
print_footer() {
  local now host user_name
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  host="$(short_host)"
  user_name="${USER:-unknown}"

  printf '\n'
  row "Host: ${host}   User: ${user_name}"
  row "Time: ${now}"
}

# Prints main footer.
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

# Diagnostic logger for observability. Silent unless MQ_DEBUG is set to a
# non-empty, non-"0"/"false"/"no"/"off" value. Writes to stderr so it never
# corrupts rendered stdout, and always returns 0 — so it is safe as an
# `... || mq_debug "why"` tail on a best-effort command without changing that
# command's (non-fatal) control flow. Use it instead of swallowing an
# *unexpected* failure with `2>/dev/null || true`. Expected-empty results
# (no upstream, no tags) should stay silent.
mq_debug() {
  case "${MQ_DEBUG:-}" in
    ''|0|false|no|off) return 0 ;;
  esac
  printf '%b[mq-debug %s]%b %s\n' "${C_DIM:-}" "$(date '+%H:%M:%S')" "${C_RESET:-}" "$*" >&2
  return 0
}

# Handles ui ok.
ui_ok() {
  printf "%b%s%b\n" "$C_OK" "$1" "$C_RESET"
}

# Handles ui warn.
ui_warn() {
  printf "%b%s%b\n" "$C_WARN" "$1" "$C_RESET"
}

# Handles ui err.
ui_err() {
  printf "%b%s%b\n" "$C_ERR" "$1" "$C_RESET" >&2
}

# Handles ui info.
ui_info() {
  printf "%b%s%b\n" "$C_INFO" "$1" "$C_RESET"
}
