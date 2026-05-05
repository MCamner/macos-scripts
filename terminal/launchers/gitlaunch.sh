#!/bin/zsh

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_MESSAGES=C.UTF-8

STATE_FILE=~/.gitlaunch_state
DEFAULT_REPO=~/macos-scripts
REQUESTED_REPO="${MQ_GIT_REPO:-${1:-}}"

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
  C_RESET=$'\e[0m'
  C_BOLD=$'\e[1m'
  C_DIM=$'\e[2m'
  C_BORDER=$'\e[38;5;229m'
  C_ACCENT=$'\e[38;5;220m'
  C_TITLE=$'\e[1;38;5;229m'
  C_LABEL=$'\e[38;5;229m'
  C_GOOD=$'\e[92m'
  C_WARN=$'\e[93m'
  C_BAD=$'\e[91m'
  C_DIM=$'\e[38;5;245m'
  C_CYAN=$'\e[36m'
  C_YELLOW=$'\e[33m'
  C_PINK=$'\e[95m'
  C_MAGENTA=$'\e[35m'
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
  C_PINK=""
  C_MAGENTA=""
fi

GUM_BIN="$(command -v gum 2>/dev/null || true)"
UI_WIDTH=62
UI_INNER=$((UI_WIDTH - 4))

# ------------------------
# ASCII ART
# ------------------------
function render_ascii() {
  printf "%b" "$C_CYAN"
  cat <<'EOF'
  ██████╗ ██╗████████╗
 ██╔════╝ ██║╚══██╔══╝
 ██║  ███╗██║   ██║
 ██║   ██║██║   ██║
 ╚██████╔╝██║   ██║
  ╚═════╝ ╚═╝   ╚═╝
EOF
  printf "%b" "$C_PINK"
  cat <<'EOF'
██╗      █████╗ ██╗   ██╗███╗  ██╗ ██████╗██╗  ██╗
██║     ██╔══██╗██║   ██║████╗ ██║██╔════╝██║  ██║
██║     ███████║██║   ██║██╔██╗██║██║     ███████║
██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║
╚██████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║
 ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝
EOF
  printf "%b" "$C_RESET"
}

# ------------------------
# STATE MANAGEMENT
# ------------------------
function save_state() {
  {
    print -r -- "REPO=${(qqq)REPO}"
    print -r -- "LAST_ACTION=${(qqq)1}"
    print -r -- "TIMESTAMP=${(qqq)$(date)}"
  } > "$STATE_FILE"
}

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

function set_repo() {
  local repo_path="$1"
  local save="${2:-}"
  local resolved_repo

  resolved_repo=$(resolve_repo_path "$repo_path") || {
    echo "Path not found: $repo_path"
    sleep 1
    return 1
  }

  resolved_repo=$(git -C "$resolved_repo" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$resolved_repo" ]; then
    echo "Not a git repo: $repo_path"
    sleep 1
    return 1
  fi

  REPO=$resolved_repo
  if [ "$save" = "save" ]; then
    save_state "set_repo"
  fi
}

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

  if [ -n "$REQUESTED_REPO" ]; then
    set_repo "$REQUESTED_REPO" || REPO=""
    REQUESTED_REPO=""
  fi

  if [ -z "$REPO" ]; then
    detected=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$detected" ]; then
      REPO=$detected
    fi
  fi

  if [ -z "$REPO" ]; then
    echo "⚠️ Not inside a git repo"
    echo "1. Go to default repo"
    echo "2. Exit"
    echo -n "Choose: "
    read choice

    case $choice in
      1) REPO=$DEFAULT_REPO ;;
      *) exit ;;
    esac
  fi

  cd "$REPO" || exit
}

# ------------------------
# UI
# ------------------------
function clear_screen() {
  printf "%b" "$C_RESET"
  clear
}

function use_gum_menu() {
  [[ -t 0 && -t 1 && -n "$GUM_BIN" ]]
}

function repeat_char() {
  local char="$1"
  local count="$2"
  printf "%${count}s" "" | tr " " "$char"
}

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

function frame_top() {
  printf "%b┌%s┐%b\n" "$C_BORDER" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

function frame_mid() {
  printf "%b├%s┤%b\n" "$C_BORDER" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

function frame_bottom() {
  printf "%b└%s┘%b\n" "$C_BORDER" "$(repeat_char "─" "$((UI_WIDTH - 2))")" "$C_RESET"
}

function frame_blank() {
  printf "%b│%b %-${UI_INNER}s %b│%b\n" "$C_BORDER" "$C_RESET" "" "$C_BORDER" "$C_RESET"
}

function frame_row() {
  local text
  text=$(truncate_text "$1" "$UI_INNER")
  printf "%b│%b %-${UI_INNER}s %b│%b\n" "$C_BORDER" "$C_RESET" "$text" "$C_BORDER" "$C_RESET"
}

function frame_row_colored() {
  local text color
  text=$(truncate_text "$1" "$UI_INNER")
  color="$2"
  printf "%b│%b %b%-${UI_INNER}s%b %b│%b\n" "$C_BORDER" "$C_RESET" "$color" "$text" "$C_RESET" "$C_BORDER" "$C_RESET"
}

function frame_two_col() {
  local left right col_width
  col_width=$(((UI_INNER - 3) / 2))
  left=$(truncate_text "$1" "$col_width")
  right=$(truncate_text "$2" "$col_width")
  printf "%b│%b %-${col_width}s %b│%b %-${col_width}s %b│%b\n" \
    "$C_BORDER" "$C_RESET" "$left" "$C_BORDER" "$C_RESET" "$right" "$C_BORDER" "$C_RESET"
}

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

function render_banner() {
  render_ascii
  echo
  frame_top
  frame_title "MQ REPO LAUNCHER"
  frame_mid
  frame_row_colored "  ★  PHOSPHOR GRID ACTIVE  ★" "$C_PINK"
  frame_blank
  frame_mid
}

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

function fallback_border_top() {
  printf "%b┌────────────────────────────────────────────────────────────────────────┐%b\n" "$C_CYAN" "$C_RESET"
}

function fallback_border_mid() {
  printf "%b├────────────────────────────────────────────────────────────────────────┤%b\n" "$C_CYAN" "$C_RESET"
}

function fallback_border_bottom() {
  printf "%b└────────────────────────────────────────────────────────────────────────┘%b\n" "$C_CYAN" "$C_RESET"
}

function fallback_row() {
  local text
  text=$(truncate_text "$1" 70)
  printf "%b│%b %-70s %b│%b\n" "$C_CYAN" "$C_RESET" "$text" "$C_CYAN" "$C_RESET"
}

function fallback_row_colored() {
  local text color
  text=$(truncate_text "$1" 70)
  color="$2"
  printf "%b│%b %b%-70s%b %b│%b\n" "$C_CYAN" "$C_RESET" "$color" "$text" "$C_RESET" "$C_CYAN" "$C_RESET"
}

function fallback_status_row() {
  local label="$1"
  local value="$2"
  local color="${3:-}"
  value=$(truncate_text "$value" 61)
  printf "%b│%b %b%-7s%b: %b%-61s%b %b│%b\n" \
    "$C_CYAN" "$C_RESET" "$C_TITLE" "$label" "$C_RESET" "$color" "$value" "$C_RESET" "$C_CYAN" "$C_RESET"
}

# ------------------------
# STATUS
# ------------------------

function status_check() {
  BRANCH=$(git branch --show-current)
  CHANGES=$(git status --porcelain | wc -l | xargs)
  REMOTE=$(remote_state)

  if ! use_gum_menu; then
    fallback_border_top
    fallback_row_colored "GITHUB LAUNCHPAD" "$C_TITLE"
    fallback_row_colored "REPO COMMAND DECK" "$C_YELLOW"
    fallback_border_mid
    fallback_status_row "Repo" "$REPO"
    fallback_status_row "Branch" "$BRANCH"
    fallback_status_row "Status" "${CHANGES} change(s)"
    if [ "$CHANGES" -eq 0 ]; then
      fallback_status_row "State" "CLEAN" "$C_GOOD"
    else
      fallback_status_row "State" "DIRTY" "$C_BAD"
    fi
    fallback_status_row "Remote" "$REMOTE"
    return
  fi

  render_banner
  frame_row "PATH   : $REPO"
  frame_row "BRANCH : ${BRANCH:u}"
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
  echo
  frame_top
  frame_row_colored "1. GIT STATUS" "$C_LABEL"
  frame_row_colored "2. GIT PULL" "$C_LABEL"
  frame_row_colored "3. AI COMMIT" "$C_LABEL"
  frame_row_colored "4. SAFE PUSH" "$C_LABEL"
  frame_row_colored "5. OPEN REPO" "$C_LABEL"
  frame_row_colored "6. DEV MODE" "$C_LABEL"
  frame_row_colored "7. SWITCH REPO" "$C_LABEL"
  frame_row_colored "8. AUTO ACTION" "$C_LABEL"
  frame_row_colored "9. EXIT" "$C_BAD"
  frame_bottom
}

function render_next_action() {
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

function prompt_choice() {
  local prompt_sep input old_stty
  prompt_sep="$(repeat_char "─" "$UI_WIDTH")"

  printf "%b%s%b\n" "$C_BORDER" "$prompt_sep" "$C_RESET"
  printf "%bgitlaunch > %b\n" "$C_TITLE" "$C_RESET"
  printf "%b%s%b\n" "$C_BORDER" "$prompt_sep" "$C_RESET"
  printf "%b>> press 1-9%b\n" "$C_DIM" "$C_RESET"
  printf "\033[3A"
  printf "%bgitlaunch > %b" "$C_TITLE" "$C_RESET"

  old_stty="$(stty -g)"
  stty -echo -icanon min 1 time 0 2>/dev/null || true
  IFS= read -r -k 1 input 2>/dev/null || input=""
  stty "$old_stty" 2>/dev/null || true

  printf "%s\n" "$input"
  printf "\033[2B"

  choice="$input"
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
function safe_push() {
  git fetch
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse @{u} 2>/dev/null)

  if [ -z "$REMOTE" ]; then
    echo "⚠️ No upstream branch set."
    return
  fi

  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "⚠️ Repo not up to date. Run pull first."
    return
  fi

  git push
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

# ------------------------
# WORKSPACE RESUME
# ------------------------
if load_state; then
  echo "🔁 Resume last workspace?"
  echo "Repo: $REPO"
  echo -n "(y/n): "
  read resume

  if [[ "$resume" == "y" ]]; then
    cd "$REPO"
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
      read
      ;;
    2)
      git pull
      read
      ;;
    3)
      SUGGESTED=$(suggest_commit)

      echo ""
      printf "%b💡 Suggested commit message:%b\n" "$C_TITLE" "$C_RESET"
      echo "$SUGGESTED"

      analyze_diff

      printf "%bProceed with commit? (y/n): %b" "$C_LABEL" "$C_RESET"
      read proceed

      if [[ "$proceed" != "y" ]]; then
        echo "❌ Commit cancelled"
        read
        continue
      fi

      git add .
      git commit -m "$SUGGESTED"
      git push
      read
      ;;
    4)
      safe_push
      read
      ;;
    5)
      open .
      ;;
    6)
      echo "🚀 Starting Dev Mode..."
      save_state "dev_mode"

      open -a "ChatGPT Atlas"
      open -a Terminal "$REPO"

      if command -v code >/dev/null 2>&1; then
        code "$REPO"
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
      git commit -m "$SUGGESTED"
      git push
      read
      ;;
    9)
      exit
      ;;
    *)
      echo "Invalid"
      sleep 1
      ;;
  esac
done
