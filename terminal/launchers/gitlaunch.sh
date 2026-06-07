#!/bin/zsh

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_MESSAGES=C.UTF-8

STATE_FILE=~/.gitlaunch_state
DEFAULT_REPO=~/macos-scripts
REQUESTED_REPO="${MQ_GIT_REPO:-${1:-}}"
WORK_DIR=""
_BANNER_SHOWN=0

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
  C_RESET=$'\e[0m'
  C_BOLD=$'\e[1m'
  C_DIM=$'\e[2m'
  C_BORDER=$'\e[1;97m'
  C_ACCENT=$'\e[38;5;178m'
  C_TITLE=$'\e[1;38;5;178m'
  C_LABEL=$'\e[38;5;179m'
  C_GOOD=$'\e[92m'
  C_WARN=$'\e[93m'
  C_BAD=$'\e[91m'
  C_DIM=$'\e[38;5;245m'
  C_CYAN=$'\e[1;97m'
  C_YELLOW=$'\e[33m'
  C_AMBER=$'\e[38;5;136m'
  C_DARK_YELLOW=$'\e[38;5;100m'
  C_PINK=$'\e[95m'
  C_MAGENTA=$'\e[35m'
  C_WHITE=$'\e[1;97m'
  C_BLINK=$'\e[5m'
else
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_BORDER=""
  C_ACCENT=""
  C_TITLE=""
  C_LABEL=""
  C_GOOD=""
  C_WARN=""
  C_BAD=""
  C_DIM=""
  C_CYAN=""
  C_YELLOW=""
  C_AMBER=""
  C_DARK_YELLOW=""
  C_PINK=""
  C_MAGENTA=""
  C_WHITE=""
  C_BLINK=""
fi

GUM_BIN="$(command -v gum 2>/dev/null || true)"
UI_WIDTH=88
UI_INNER=$((UI_WIDTH - 4))
STAGED_COUNT=0
UNSTAGED_COUNT=0
UNTRACKED_COUNT=0

# ------------------------
# ASCII ART
# ------------------------
function render_ascii() {
  local i
  local -a pulses figure labels

  figure=(
    "    ████████    "
    "    ██    ██    "
    "    ████████    "
    "  ████████████  "
    "  ██        ██  "
    "  ████    ████  "
  )
  labels=(
    ""
    "  Gitlaunch"
    ""
    ""
    ""
    ""
  )

  if [[ "$_BANNER_SHOWN" -eq 0 ]]; then
    _BANNER_SHOWN=1
    pulses=(
      "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓"
      "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
      "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
    )
    for pulse in "${pulses[@]}"; do
      printf "%b  %s%b\r" "$C_AMBER" "$pulse" "$C_RESET"
      sleep 0.05
    done
    printf "\033[2K"
    for (( i=1; i<=${#figure[@]}; i++ )); do
      printf "%b  %s%b%s%b\n" "$C_AMBER" "${figure[$i]}" "$C_TITLE" "${labels[$i]}" "$C_RESET"
      sleep 0.06
    done
  else
    for (( i=1; i<=${#figure[@]}; i++ )); do
      printf "%b  %s%b%s%b\n" "$C_AMBER" "${figure[$i]}" "$C_TITLE" "${labels[$i]}" "$C_RESET"
    done
  fi

  printf "%b" "$C_RESET"
}

# ------------------------
# STATE MANAGEMENT
# ------------------------
function save_state() {
  {
    print -r -- "REPO=${(qqq)REPO}"
    print -r -- "WORK_DIR=${(qqq)WORK_DIR}"
    print -r -- "LAST_ACTION=${(qqq)1}"
    print -r -- "TIMESTAMP=${(qqq)$(date)}"
  } > "$STATE_FILE"
}

# Loads state into the current script state.
function load_state() {
  if [ -f "$STATE_FILE" ]; then
    source $STATE_FILE
    return 0
  else
    return 1
  fi
}

# ------------------------
# REPO SWITCHING
# ------------------------
function resolve_repo_path() {
  local repo_path="$1"

  case "$repo_path" in
    \~) repo_path="$HOME" ;;
    \~/*) repo_path="$HOME/${repo_path#\~/}" ;;
  esac

  if [[ "$repo_path" != /* ]]; then
    repo_path="$(pwd)/$repo_path"
  fi

  (cd "$repo_path" 2>/dev/null && pwd) || return 1
}

# Sets repo.
function set_repo() {
  local repo_path="$1"
  local save="${2:-}"
  local resolved_path resolved_repo

  resolved_path=$(resolve_repo_path "$repo_path") || {
    echo "Path not found: $repo_path"
    sleep 1
    return 1
  }

  resolved_repo=$(git -C "$resolved_path" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$resolved_repo" ]; then
    echo "Not a git repo: $repo_path"
    sleep 1
    return 1
  fi

  REPO=$resolved_repo
  WORK_DIR=$resolved_path
  if [ "$save" = "save" ]; then
    save_state "set_repo"
  fi
}

# Coordinates switch repo behavior.
function switch_repo() {
  echo "Enter local repo path:"
  echo -n "> "
  read new_repo

  if [ -z "$new_repo" ]; then
    echo "No repo entered"
    sleep 1
    return
  fi

  set_repo "$new_repo" save || return
  echo "Switched to: $REPO"
  sleep 1
}

# ------------------------
# REPO DETECTION
# ------------------------
function detect_repo() {
  local detected=""
  local detected_path=""

  if [ -n "$REQUESTED_REPO" ]; then
    set_repo "$REQUESTED_REPO" || REPO=""
    REQUESTED_REPO=""
  fi

  if [ -z "$REPO" ]; then
    detected=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$detected" ]; then
      REPO=$detected
      detected_path=$(pwd)
      WORK_DIR=$detected_path
    fi
  fi

  if [ -z "$REPO" ]; then
    echo "⚠️ Not inside a git repo"
    echo "1. Go to default repo"
    echo "2. Exit"
    echo -n "Choose: "
    read choice

    case $choice in
      1)
        REPO=$DEFAULT_REPO
        WORK_DIR=$DEFAULT_REPO
        ;;
      *) exit ;;
    esac
  fi

  [ -n "$WORK_DIR" ] || WORK_DIR="$REPO"
  cd "$WORK_DIR" || exit
}

# ------------------------
# UI
# ------------------------
function clear_screen() {
  printf "%b" "$C_RESET"
  clear
}

# Coordinates use gum menu behavior.
function use_gum_menu() {
  [[ -t 0 && -t 1 && -n "$GUM_BIN" ]]
}

# Coordinates repeat char behavior.
function repeat_char() {
  local char="$1"
  local count="$2"
  printf "%${count}s" "" | tr " " "$char"
}

# Matches mqlaunch surface width so nested gitlaunch panels align visually.
function gitlaunch_terminal_width() {
  local cols width
  cols="$(tput cols 2>/dev/null || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=92

  width="$cols"
  (( width > 112 )) && width=112
  (( width < 60 )) && width=60
  print -r -- "$width"
}

# Refreshes frame dimensions before rendering or prompting.
function update_ui_width() {
  UI_WIDTH="$(gitlaunch_terminal_width)"
  UI_INNER=$((UI_WIDTH - 4))
}

# Coordinates truncate text behavior.
function truncate_text() {
  local text="$1"
  local max="$2"

  if [ ${#text} -le "$max" ]; then
    print -r -- "$text"
  elif [ "$max" -le 3 ]; then
    print -r -- "${text[1,$max]}"
  else
    print -r -- "${text[1,$((max - 3))]}..."
  fi
}

# Formats the top border element for terminal output.
function frame_top() {
  printf "%b┌%s┐%b\n" "$C_BORDER" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

# Formats the top titled border element for terminal output.
function frame_top_titled() {
  local title="$1"
  local rest=$(( UI_WIDTH - 5 - ${#title} ))
  (( rest < 0 )) && rest=0
  printf "%b┌─ %b%s%b %s┐%b\n" "$C_BORDER" "$C_TITLE" "$title" "$C_BORDER" "$(repeat_char "─" "$rest")" "$C_RESET"
}

# Formats the mid border element for terminal output.
function frame_mid() {
  printf "%b├%s┤%b\n" "$C_BORDER" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

# Formats the bottom border element for terminal output.
function frame_bottom() {
  printf "%b└%s┘%b\n" "$C_BORDER" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

# Formats the blank border element for terminal output.
function frame_blank() {
  printf "%b│%b %-${UI_INNER}s %b│%b\n" "$C_BORDER" "$C_RESET" "" "$C_BORDER" "$C_RESET"
}

# Formats the row border element for terminal output.
function frame_row() {
  local text
  text=$(truncate_text "$1" "$UI_INNER")
  printf "%b│%b %-${UI_INNER}s %b│%b\n" "$C_BORDER" "$C_RESET" "$text" "$C_BORDER" "$C_RESET"
}

# Formats the row colored border element for terminal output.
function frame_row_colored() {
  local text color
  text=$(truncate_text "$1" "$UI_INNER")
  color="$2"
  printf "%b│%b %b%-${UI_INNER}s%b %b│%b\n" "$C_BORDER" "$C_RESET" "$color" "$text" "$C_RESET" "$C_BORDER" "$C_RESET"
}

# Formats the two col border element for terminal output.
function frame_two_col() {
  local left right left_width right_width
  left_width=$((UI_INNER / 2))
  right_width=$((UI_INNER - left_width - 1))
  left=$(truncate_text "$1" "$left_width")
  right=$(truncate_text "$2" "$right_width")
  printf "%b│%b %-${left_width}s %-${right_width}s %b│%b\n" \
    "$C_BORDER" "$C_RESET" "$left" "$right" "$C_BORDER" "$C_RESET"
}

# Formats the title border element for terminal output.
function frame_title() {
  local title="$1"
  local title_len=${#title}
  local inner=$((UI_WIDTH - 2))
  local pad_left=$(((inner - title_len) / 2))
  local pad_right=$((inner - title_len - pad_left))
  [ "$pad_left" -lt 0 ] && pad_left=0
  [ "$pad_right" -lt 0 ] && pad_right=0

  printf "%b│%b%${pad_left}s%b%s%b%${pad_right}s%b│%b\n" \
    "$C_BORDER" "$C_RESET" "" "$C_TITLE" "$title" "$C_RESET" "" "$C_BORDER" "$C_RESET"
}

# Renders the banner view for terminal output.
function render_banner() {
  render_ascii
  echo
  frame_top
  frame_title "MQ REPO LAUNCHER"
  frame_mid
  frame_row_colored "  ★  AMBER COMMIT DECK ACTIVE  ★" "$C_ACCENT"
  frame_blank
  frame_mid
}

# Coordinates remote state behavior.
function remote_state() {
  local ahead behind

  ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
  behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)

  if [ -z "$ahead" ] || [ -z "$behind" ]; then
    echo "NO UPSTREAM"
  elif [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    echo "DIVERGED"
  elif [ "$ahead" -gt 0 ]; then
    echo "AHEAD $ahead"
  elif [ "$behind" -gt 0 ]; then
    echo "BEHIND $behind"
  else
    echo "OK"
  fi
}

# Refreshes git status counters used by the status and menu panels.
function refresh_git_counters() {
  local git_status staged unstaged untracked
  git_status="$(git status --porcelain 2>/dev/null || true)"

  staged="$(printf "%s\n" "$git_status" | awk 'length($0) >= 2 && substr($0, 1, 1) != " " && substr($0, 1, 1) != "?" {count++} END {print count + 0}')"
  unstaged="$(printf "%s\n" "$git_status" | awk 'length($0) >= 2 && substr($0, 2, 1) != " " {count++} END {print count + 0}')"
  untracked="$(printf "%s\n" "$git_status" | awk '$0 ~ /^\?\?/ {count++} END {print count + 0}')"

  STAGED_COUNT="$staged"
  UNSTAGED_COUNT="$unstaged"
  UNTRACKED_COUNT="$untracked"
}

# Renders fallback border top output when richer UI helpers are unavailable.
function fallback_border_top() {
  update_ui_width
  printf "%b┌%s┐%b\n" "$C_CYAN" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

# Renders fallback border mid output when richer UI helpers are unavailable.
function fallback_border_mid() {
  update_ui_width
  printf "%b├%s┤%b\n" "$C_CYAN" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

# Renders fallback border bottom output when richer UI helpers are unavailable.
function fallback_border_bottom() {
  update_ui_width
  printf "%b└%s┘%b\n" "$C_CYAN" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

# Renders fallback row output when richer UI helpers are unavailable.
function fallback_row() {
  local text
  update_ui_width
  text=$(truncate_text "$1" "$UI_INNER")
  printf "%b│%b %-${UI_INNER}s %b│%b\n" "$C_CYAN" "$C_RESET" "$text" "$C_CYAN" "$C_RESET"
}

# Renders fallback row colored output when richer UI helpers are unavailable.
function fallback_row_colored() {
  local text color
  update_ui_width
  text=$(truncate_text "$1" "$UI_INNER")
  color="$2"
  printf "%b│%b %b%-${UI_INNER}s%b %b│%b\n" "$C_CYAN" "$C_RESET" "$color" "$text" "$C_RESET" "$C_CYAN" "$C_RESET"
}

# Renders fallback status row output when richer UI helpers are unavailable.
function fallback_status_row() {
  local label="$1"
  local value="$2"
  local color="${3:-}"
  local label_width=8
  local value_width
  update_ui_width
  value_width=$((UI_INNER - 10))
  (( value_width < 1 )) && value_width=1
  value=$(truncate_text "$value" "$value_width")
  printf "%b│%b %b%-${label_width}s%b: %b%-${value_width}s%b %b│%b\n" \
    "$C_CYAN" "$C_RESET" "$C_TITLE" "$label" "$C_RESET" "$color" "$value" "$C_RESET" "$C_CYAN" "$C_RESET"
}

# ------------------------
# STATUS
# ------------------------

# Coordinates status check behavior.
function status_check() {
  BRANCH=$(git branch --show-current)
  CHANGES=$(git status --porcelain | wc -l | xargs)
  REMOTE=$(remote_state)
  refresh_git_counters
  update_ui_width

  if ! use_gum_menu; then
    fallback_border_top
    fallback_row_colored "GITHUB LAUNCHPAD" "$C_TITLE"
    fallback_row_colored "REPO COMMAND DECK" "$C_YELLOW"
    fallback_border_mid
    fallback_status_row "Repo" "$REPO"
    fallback_status_row "Path" "${WORK_DIR:-$REPO}"
    fallback_status_row "Branch" "$BRANCH"
    fallback_status_row "Status" "${CHANGES} change(s)"
    fallback_status_row "Staged" "$STAGED_COUNT"
    fallback_status_row "Unstaged" "$UNSTAGED_COUNT"
    fallback_status_row "Untrack" "$UNTRACKED_COUNT"
    if [ "$CHANGES" -eq 0 ]; then
      fallback_status_row "State" "CLEAN" "$C_GOOD"
    else
      fallback_status_row "State" "DIRTY" "$C_BAD"
    fi
    fallback_status_row "Remote" "$REMOTE"
    return
  fi

  render_banner
  frame_row "PATH   : ${WORK_DIR:-$REPO}"
  frame_row "BRANCH : ${BRANCH:u}"
  frame_row "COUNTS : STAGED $STAGED_COUNT  UNSTAGED $UNSTAGED_COUNT  UNTRACKED $UNTRACKED_COUNT"
  if [ "$CHANGES" -eq 0 ]; then
    frame_row_colored "STATE  : CLEAN" "$C_GOOD"
  else
    frame_row_colored "STATE  : DIRTY (${CHANGES} CHANGES)" "$C_WARN"
  fi
  frame_row "REMOTE : $REMOTE"
  frame_bottom
}

# ------------------------
# MENU
# ------------------------
function render_menu() {
  local git_state host_name
  local repo_label branch_label
  update_ui_width
  refresh_git_counters
  host_name="$(hostname -s 2>/dev/null || echo unknown)"
  repo_label="$(basename "${REPO:-${WORK_DIR:-repo}}")"
  branch_label="$(git branch --show-current 2>/dev/null || echo unknown)"
  if [[ -z "${CHANGES}" ]]; then
    git_state="Clean"
  else
    git_state="Dirty"
  fi

  frame_top_titled "Gitlaunch"
  frame_row "Host: $host_name   User: ${USER:-mansys}   Repo: $repo_label   Branch: $branch_label"
  frame_row "Git: $git_state   Staged: $STAGED_COUNT   Unstaged: $UNSTAGED_COUNT   Untracked: $UNTRACKED_COUNT"
  frame_mid
  frame_two_col "1. Git status" "2. Pull"
  frame_two_col "3. Commit with suggested message" "4. Safe push"
  frame_two_col "5. Open repo" "6. Dev mode"
  frame_two_col "7. Switch repo" "8. Auto commit + push"
  frame_two_col "9. Recent log" "b. Back"
  frame_bottom
}

# Renders the next action view for terminal output.
function render_next_action() {
  update_ui_width

  if ! use_gum_menu; then
    fallback_border_mid
    fallback_row_colored "NEXT ACTION: $NEXT_ACTION_MESSAGE" "$NEXT_ACTION_COLOR"
    fallback_border_bottom
    return
  fi

  frame_top
  frame_row_colored "$NEXT_ACTION_MESSAGE" "$NEXT_ACTION_COLOR"
  frame_bottom
}

# Prompts for choice with script-level validation.
function prompt_choice() {
  local sep input
  update_ui_width
  sep="$(repeat_char "─" "$UI_WIDTH")"

  printf "\n%b%s%b\n" "$C_BORDER" "$sep" "$C_RESET"
  printf "%bgitlaunch > %b\n" "$C_TITLE" "$C_RESET"
  printf "%b%s%b\n" "$C_BORDER" "$sep" "$C_RESET"
  printf "%b>> press 1-9 or b%b\n" "$C_DIM" "$C_RESET"
  if [[ -t 0 && -t 1 ]]; then
    printf "\033[3A\r"
    printf "%bgitlaunch > %b" "$C_TITLE" "$C_RESET"
  fi

  input=""
  IFS= read -r input </dev/tty || true

  if [[ -t 0 && -t 1 ]]; then
    printf "\033[2B\r\n"
  fi

  input="${input[1,1]}"
  choice="$input"
}

# Pauses inside gitlaunch without changing menu level.
function pause_git_menu() {
  local pause_reply="" _drain=""
  stty sane </dev/tty 2>/dev/null || true
  # drain any newlines buffered during git operations or prior reads
  read -t 0.1 -k 999 _drain </dev/tty 2>/dev/null || true
  echo ""
  printf "%bPress Enter to return to Gitlaunch menu...%b" "$C_DIM" "$C_RESET"
  IFS= read -r pause_reply </dev/tty || true
  choice=""
}

# ------------------------
# NEXT ACTION ENGINE
# ------------------------
function next_action() {

  CHANGES=$(git status --porcelain)
  STAGED=$(git diff --cached --name-only)
  AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null)
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null)

  if echo "$CHANGES" | grep -q "UU"; then
    NEXT_ACTION_MESSAGE="Resolve merge conflicts"
    NEXT_ACTION_COLOR="$C_BAD"
    return
  fi

  if [ -n "$CHANGES" ] && [ -z "$STAGED" ]; then
    NEXT_ACTION_MESSAGE="Stage your changes (git add .)"
    NEXT_ACTION_COLOR="$C_WARN"
    return
  fi

  if [ -n "$STAGED" ]; then
    NEXT_ACTION_MESSAGE="Commit your changes"
    NEXT_ACTION_COLOR="$C_WARN"
    return
  fi

  if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then
    NEXT_ACTION_MESSAGE="Pull latest changes"
    NEXT_ACTION_COLOR="$C_WARN"
    return
  fi

  if [ -n "$AHEAD" ] && [ "$AHEAD" -gt 0 ]; then
    NEXT_ACTION_MESSAGE="Push your commits"
    NEXT_ACTION_COLOR="$C_GOOD"
    return
  fi

  NEXT_ACTION_MESSAGE="Nothing to do"
  NEXT_ACTION_COLOR="$C_GOOD"
}

# ------------------------
# DIFF INTELLIGENCE (v6)
# ------------------------
function analyze_diff() {

  DIFF=$(git diff)
  FILES=$(git diff --name-only)

  echo ""
  echo "🔍 Diff analysis:"

  RISK_LEVEL="LOW"
  WARNINGS=()

  # Sensitive files
  if echo "$FILES" | grep -E "\.env|\.key|\.pem" >/dev/null; then
    WARNINGS+=("Possible secrets in sensitive files")
    RISK_LEVEL="HIGH"
  fi

  # Credentials
  if echo "$DIFF" | grep -iE "password=|token=|secret=" >/dev/null; then
    WARNINGS+=("Hardcoded credentials detected")
    RISK_LEVEL="HIGH"
  fi

  # Dangerous commands
  if echo "$DIFF" | grep -E "rm -rf" >/dev/null; then
    WARNINGS+=("Destructive command: rm -rf")
    RISK_LEVEL="HIGH"
  fi

  if echo "$DIFF" | grep -E "sudo " >/dev/null; then
    WARNINGS+=("Use of sudo detected")
    [ "$RISK_LEVEL" != "HIGH" ] && RISK_LEVEL="MEDIUM"
  fi

  # Large diff
  LINES=$(echo "$DIFF" | wc -l | xargs)
  if [ "$LINES" -gt 300 ]; then
    WARNINGS+=("Large diff: $LINES lines")
    [ "$RISK_LEVEL" = "LOW" ] && RISK_LEVEL="MEDIUM"
  fi

  # Script changes
  if echo "$FILES" | grep -E "\.sh$" >/dev/null; then
    WARNINGS+=("Shell script modified")
    [ "$RISK_LEVEL" = "LOW" ] && RISK_LEVEL="MEDIUM"
  fi

  if [ ${#WARNINGS[@]} -eq 0 ]; then
    printf "%b✅ No obvious risks%b\n" "$C_GOOD" "$C_RESET"
  else
    case "$RISK_LEVEL" in
      HIGH) RISK_COLOR=$C_BAD ;;
      MEDIUM) RISK_COLOR=$C_WARN ;;
      *) RISK_COLOR=$C_GOOD ;;
    esac
    printf "%b⚠️ Risk level: %s%b\n" "$RISK_COLOR" "$RISK_LEVEL" "$C_RESET"
    for w in "${WARNINGS[@]}"; do
      printf "%b- %s%b\n" "$C_DIM" "$w" "$C_RESET"
    done
  fi

  echo ""
}

# ------------------------
# SAFE PUSH
# ------------------------
function protected_branch_names() {
  echo "${MQLAUNCH_PROTECTED_BRANCHES:-main master}"
}

# Checks whether protected branch applies.
function is_protected_branch() {
  local branch="$1"
  local protected

  protected=" $(protected_branch_names) "
  [[ "$protected" == *" $branch "* ]]
}

# Coordinates branch slug behavior.
function branch_slug() {
  local text="$1"
  local slug

  slug=$(echo "$text" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  if [[ -z "$slug" ]]; then
    slug="update-project-files"
  fi

  echo "${slug:0:48}"
}

# Creates pr branch for push through the configured workflow.
function create_pr_branch_for_push() {
  local base_branch="$1"
  local commit_message="$2"
  local slug pr_branch confirm output status

  slug="$(branch_slug "$commit_message")"
  pr_branch="mq/${slug}-$(date +%Y%m%d-%H%M%S)"

  echo ""
  printf "%b🔒 Branch '%s' is protected.%b\n" "$C_WARN" "$base_branch" "$C_RESET"
  echo "GitHub requires these changes to go through a pull request."
  echo "Suggested PR branch: $pr_branch"
  printf "%bCreate and push this PR branch? [Y/n]: %b" "$C_LABEL" "$C_RESET"
  read confirm </dev/tty

  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Push cancelled. Commit remains local on $base_branch."
    return 1
  fi

  git switch -c "$pr_branch" 2>/dev/null || git checkout -b "$pr_branch"
  output=$(git push -u origin "$pr_branch" 2>&1)
  status=$?
  echo "$output"

  if [[ "$status" -ne 0 ]]; then
    return "$status"
  fi

  if command -v gh >/dev/null 2>&1; then
    echo ""
    echo "Next: gh pr create --base $base_branch --head $pr_branch --fill"
  fi
}

# Coordinates pr aware push behavior.
function pr_aware_push() {
  local commit_message="${1:-update project files}"
  local branch output status
  local -a push_args

  push_args=("${@:2}")

  branch="$(git branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "⚠️ Detached HEAD. Push blocked."
    return 1
  fi

  if is_protected_branch "$branch"; then
    create_pr_branch_for_push "$branch" "$commit_message"
    return $?
  fi

  if [[ "${#push_args[@]}" -gt 0 ]]; then
    output=$(git push "${push_args[@]}" 2>&1)
  else
    output=$(git push 2>&1)
  fi
  status=$?
  echo "$output"

  if [[ "$status" -ne 0 ]] && echo "$output" | grep -E "GH013|Changes must be made through a pull request" >/dev/null; then
    create_pr_branch_for_push "$branch" "$commit_message"
    return $?
  fi

  return "$status"
}

# Runs push through guardrails before acting.
function safe_push() {
  git fetch
  BRANCH=$(git branch --show-current)
  UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)

  if [ -z "$UPSTREAM" ]; then
    echo "⚠️ No upstream branch set."
    pr_aware_push "update project files" -u origin "$BRANCH"
    return
  fi

  AHEAD=$(git rev-list --count "$UPSTREAM"..HEAD 2>/dev/null || echo 0)
  BEHIND=$(git rev-list --count HEAD.."$UPSTREAM" 2>/dev/null || echo 0)

  if [ "$BEHIND" -gt 0 ]; then
    echo "⚠️ Repo not up to date. Run pull first."
    return
  fi

  if [ "$AHEAD" -eq 0 ]; then
    echo "✅ Nothing to push."
    return
  fi

  pr_aware_push "update project files"
}

# ------------------------
# COMMIT SUGGESTION
# ------------------------
function suggest_commit() {
  FILES=$(git diff --name-only)

  if [[ "$FILES" == *"install.sh"* && "$FILES" == *"system-check.sh"* ]]; then
    echo "improve install and system-check scripts"
  elif [[ "$FILES" == *.sh* ]]; then
    echo "update shell scripts"
  elif [[ "$FILES" == *.md* ]]; then
    echo "update documentation"
  else
    echo "update project files"
  fi
}

# Shows recent git history without leaving the Gitlaunch flow.
function show_recent_log() {
  echo ""
  printf "%bRecent commits:%b\n" "$C_TITLE" "$C_RESET"
  git log --oneline --decorate --graph -12 || true
  echo ""
  pause_git_menu
}

# Handles AI-assisted commit flow and always returns to the Git menu loop.
function run_ai_commit() {
  local SUGGESTED proceed

  SUGGESTED=$(suggest_commit)

  echo ""
  printf "%b💡 Suggested commit message:%b\n" "$C_TITLE" "$C_RESET"
  echo "$SUGGESTED"

  analyze_diff

  printf "%bProceed with commit? (y/n): %b" "$C_LABEL" "$C_RESET"
  read proceed </dev/tty

  if [[ "$proceed" != "y" ]]; then
    echo "❌ Commit cancelled"
    return 0
  fi

  git add .
  if git commit -m "$SUGGESTED"; then
    pr_aware_push "$SUGGESTED"
  fi
  pause_git_menu
}

# ------------------------
# WORKSPACE RESUME
# ------------------------
if [[ -z "$REQUESTED_REPO" ]] && load_state; then
  echo "🔁 Resume last workspace?"
  echo "Repo: $REPO"
  echo -n "(y/n): "
  read resume

  if [[ "$resume" == "y" ]]; then
    cd "${WORK_DIR:-$REPO}"
    echo "🚀 Restoring workspace..."

    echo "Workspace restored"
    sleep 1
  else
    REPO=""
  fi
fi

# ------------------------
# MAIN LOOP
# ------------------------
trap 'printf "%b" "$C_RESET"' EXIT

while true; do
  detect_repo
  clear_screen

  status_check
  next_action
  render_next_action

  if use_gum_menu && [ -n "$(git status --porcelain)" ]; then
    analyze_diff
  fi

  echo ""
  render_menu

  prompt_choice

  case $choice in
    1)
      git status
      pause_git_menu
      ;;
    2)
      git pull
      pause_git_menu
      ;;
    3)
      run_ai_commit
      continue
      ;;
    4)
      safe_push
      pause_git_menu
      ;;
    5)
      open .
      ;;
    6)
      echo "🚀 Starting Dev Mode..."
      save_state "dev_mode"

      open -a "ChatGPT Atlas"
      open -a Terminal "${WORK_DIR:-$REPO}"

      if command -v code >/dev/null 2>&1; then
        code "${WORK_DIR:-$REPO}"
      fi

      REPO_NAME=$(basename "$REPO")
      open "https://github.com/MCamner/$REPO_NAME"

      echo "✅ Dev environment ready"
      sleep 1
      ;;
    7)
      switch_repo
      ;;
    8)
      git add .
      SUGGESTED=$(suggest_commit)
      if git commit -m "$SUGGESTED"; then
        pr_aware_push "$SUGGESTED"
      fi
      pause_git_menu
      ;;
    9)
      show_recent_log
      ;;
    b|B)
      break
      ;;
    *)
      echo "Invalid"
      sleep 1
      ;;
  esac
done
