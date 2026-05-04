#!/bin/zsh

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_MESSAGES=C.UTF-8

STATE_FILE=~/.gitlaunch_state
DEFAULT_REPO=~/macos-scripts

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
  C_RESET=$'\e[0m'
  C_BORDER=$'\e[36m'
  C_TITLE=$'\e[1;96m'
  C_LABEL=$'\e[94m'
  C_GOOD=$'\e[92m'
  C_WARN=$'\e[93m'
  C_BAD=$'\e[91m'
  C_DIM=$'\e[2m'
else
  C_RESET=""
  C_BORDER=""
  C_TITLE=""
  C_LABEL=""
  C_GOOD=""
  C_WARN=""
  C_BAD=""
  C_DIM=""
fi

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
function switch_repo() {
  echo "Enter local repo path:"
  echo -n "> "
  read new_repo

  if [ -z "$new_repo" ]; then
    echo "No repo entered"
    sleep 1
    return
  fi

  new_repo=${~new_repo}

  if [ ! -d "$new_repo" ]; then
    echo "Path not found: $new_repo"
    sleep 1
    return
  fi

  resolved_repo=$(git -C "$new_repo" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$resolved_repo" ]; then
    echo "Not a git repo: $new_repo"
    sleep 1
    return
  fi

  REPO=$resolved_repo
  save_state "switch_repo"
  echo "Switched to: $REPO"
  sleep 1
}

# ------------------------
# REPO DETECTION
# ------------------------
function detect_repo() {
  REPO=$(git rev-parse --show-toplevel 2>/dev/null)

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
# STATUS
# ------------------------
function print_box_line() {
  printf "%b  %-36s  %b\n" "$C_BORDER" "$1" "$C_RESET"
}

function print_box_border() {
  printf "%b+--------------------------------------+%b\n" "$C_BORDER" "$C_RESET"
}

function get_status_label() {
  if [ "$1" -eq 0 ]; then
    echo "${C_GOOD}CLEAN${C_RESET} ($1 changes)"
  else
    echo "${C_WARN}DIRTY${C_RESET} ($1 changes)"
  fi
}

function status_check() {
  BRANCH=$(git branch --show-current)
  CHANGES=$(git status --porcelain | wc -l | xargs)
  STATUS_LABEL=$(get_status_label "$CHANGES")

  print_box_border
  print_box_line "${C_TITLE}GITLAUNCH DASHBOARD${C_RESET}"
  print_box_border
  print_box_line "${C_LABEL}Repo${C_RESET}   : $REPO"
  print_box_line "${C_LABEL}Branch${C_RESET} : $BRANCH"
  print_box_line "Status : $STATUS_LABEL"
  print_box_border
}

# ------------------------
# MENU
# ------------------------
function render_menu() {
  print_box_border
  print_box_line "${C_TITLE}ACTIONS${C_RESET}"
  print_box_border
  print_box_line "${C_LABEL}1)${C_RESET} Git status (full)"
  print_box_line "${C_LABEL}2)${C_RESET} Git pull"
  print_box_line "${C_LABEL}3)${C_RESET} AI commit + push"
  print_box_line "${C_LABEL}4)${C_RESET} Safe push"
  print_box_line "${C_LABEL}5)${C_RESET} Open repo"
  print_box_line "${C_LABEL}6)${C_RESET} Dev mode (PRO)"
  print_box_line "${C_LABEL}7)${C_RESET} Switch local repo"
  print_box_line "${C_LABEL}8)${C_RESET} Do next action (AUTO)"
  print_box_line "${C_LABEL}9)${C_RESET} Exit"
  print_box_border
}

function render_next_action() {
  print_box_border
  print_box_line "${C_TITLE}NEXT ACTION${C_RESET}"
  print_box_border
  print_box_line "$NEXT_ACTION_MESSAGE"
  print_box_border
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
    NEXT_ACTION_MESSAGE="${C_BAD}Resolve merge conflicts${C_RESET}"
    return
  fi

  if [ -n "$CHANGES" ] && [ -z "$STAGED" ]; then
    NEXT_ACTION_MESSAGE="${C_WARN}Stage your changes${C_RESET} (git add .)"
    return
  fi

  if [ -n "$STAGED" ]; then
    NEXT_ACTION_MESSAGE="${C_WARN}Commit your changes${C_RESET}"
    return
  fi

  if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then
    NEXT_ACTION_MESSAGE="${C_WARN}Pull latest changes${C_RESET}"
    return
  fi

  if [ -n "$AHEAD" ] && [ "$AHEAD" -gt 0 ]; then
    NEXT_ACTION_MESSAGE="${C_GOOD}Push your commits${C_RESET}"
    return
  fi

  NEXT_ACTION_MESSAGE="${C_GOOD}Nothing to do${C_RESET}"
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
  fi
fi

# ------------------------
# MAIN LOOP
# ------------------------
while true; do
  detect_repo
  clear
  status_check
  next_action
  render_next_action

  if [ -n "$(git status --porcelain)" ]; then
    analyze_diff
  fi

  echo ""
  render_menu

  printf "%bChoose [1-9]: %b" "$C_LABEL" "$C_RESET"
  read choice

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
