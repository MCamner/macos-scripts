#!/bin/zsh

set -u

APP_TITLE="MQ AI DASHBOARD"
REFRESH_DELAY=0.15
BASE_DIR="$HOME/macos-scripts"
AI_SCRIPT="$BASE_DIR/tools/cli/ai-mode.sh"
PROMPT_DIR="$BASE_DIR/ai-prompts"
REPO_URL="https://github.com/MCamner/macos-scripts"

# Colors
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'
C_BLUE=$'\033[34m'
C_CYAN=$'\033[36m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_MAGENTA=$'\033[35m'
C_WHITE=$'\033[37m'

set_terminal_title() {
  print -Pn "\e]0;${APP_TITLE}\a"
}

line() {
  echo "${C_BLUE}======================================================================${C_RESET}"
}

small_line() {
  echo "${C_DIM}----------------------------------------------------------------------${C_RESET}"
}

clear_screen() {
  clear
}

pause_enter() {
  read -r "?Press Enter to continue..."
}

pause_brief() {
  sleep "$REFRESH_DELAY"
}

bring_terminal_front() {
  osascript >/dev/null 2>&1 <<'APPLESCRIPT'
tell application "Terminal" to activate
APPLESCRIPT
}

safe_run_ai() {
  local mode="$1"
  if [ -x "$AI_SCRIPT" ]; then
    "$AI_SCRIPT" "$mode"
  else
    echo "${C_RED}AI script missing or not executable:${C_RESET} $AI_SCRIPT"
    pause_enter
  fi
}

show_status() {
  local now shell_name prompt_count ai_state
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  shell_name="$SHELL"

  if [ -d "$PROMPT_DIR" ]; then
    prompt_count="$(find "$PROMPT_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  else
    prompt_count="0"
  fi

  if [ -x "$AI_SCRIPT" ]; then
    ai_state="READY"
  else
    ai_state="MISSING"
  fi

  echo "${C_BOLD}${C_CYAN} ${APP_TITLE}${C_RESET}"
  echo "${C_DIM} Time:${C_RESET} $now"
  echo "${C_DIM} Shell:${C_RESET} $shell_name"
  echo "${C_DIM} AI Script:${C_RESET} $ai_state"
  echo "${C_DIM} Prompt Files:${C_RESET} $prompt_count"
}

show_quick_actions() {
  echo "${C_BOLD}${C_MAGENTA} AI MODES${C_RESET}"
  echo "${C_GREEN}  1)${C_RESET} Auto Mode"
  echo "${C_GREEN}  2)${C_RESET} Atlas One"
  echo "${C_GREEN}  3)${C_RESET} Atlas Router"
  echo "${C_GREEN}  4)${C_RESET} Decision"
  echo "${C_GREEN}  5)${C_RESET} Research"
  echo "${C_GREEN}  6)${C_RESET} Root Cause"
  echo "${C_GREEN}  7)${C_RESET} Problem Solving"
  echo "${C_GREEN}  8)${C_RESET} Prompt Debugger"
  echo "${C_GREEN}  9)${C_RESET} AI Menu"
}

show_system_actions() {
  echo "${C_BOLD}${C_YELLOW} SYSTEM${C_RESET}"
  echo "${C_YELLOW} 10)${C_RESET} Open ChatGPT"
  echo "${C_YELLOW} 11)${C_RESET} Open AI Prompts folder"
  echo "${C_YELLOW} 12)${C_RESET} Open macos-scripts repo"
  echo "${C_YELLOW} 13)${C_RESET} Show prompt files"
  echo "${C_YELLOW} 14)${C_RESET} Quick health check"
  echo "${C_YELLOW} 15)${C_RESET} Back to mqlaunch"
  echo "${C_YELLOW}  0)${C_RESET} Exit"
}

open_chatgpt() {
  open "https://chatgpt.com/"
}

open_prompt_dir() {
  if [ -d "$PROMPT_DIR" ]; then
    open "$PROMPT_DIR"
  else
    echo "${C_RED}Prompt directory not found:${C_RESET} $PROMPT_DIR"
    pause_enter
  fi
}

open_repo() {
  open "$REPO_URL"
}

show_prompt_files() {
  clear_screen
  line
  echo "${C_BOLD}${C_CYAN} PROMPT FILES${C_RESET}"
  line
  if [ -d "$PROMPT_DIR" ]; then
    find "$PROMPT_DIR" -maxdepth 1 -type f | sort | sed "s|$HOME|~|"
  else
    echo "${C_RED}Prompt directory not found.${C_RESET}"
  fi
  echo
  pause_enter
}

health_check() {
  clear_screen
  line
  echo "${C_BOLD}${C_CYAN} HEALTH CHECK${C_RESET}"
  line
  echo

  if [ -x "$AI_SCRIPT" ]; then
    echo "${C_GREEN}OK${C_RESET} ai-mode.sh is executable"
  else
    echo "${C_RED}FAIL${C_RESET} ai-mode.sh missing or not executable"
  fi

  if [ -d "$PROMPT_DIR" ]; then
    echo "${C_GREEN}OK${C_RESET} prompt directory exists"
  else
    echo "${C_RED}FAIL${C_RESET} prompt directory missing"
  fi

  if command -v pbcopy >/dev/null 2>&1; then
    echo "${C_GREEN}OK${C_RESET} pbcopy available"
  else
    echo "${C_RED}FAIL${C_RESET} pbcopy not available"
  fi

  if command -v open >/dev/null 2>&1; then
    echo "${C_GREEN}OK${C_RESET} open command available"
  else
    echo "${C_RED}FAIL${C_RESET} open command missing"
  fi

  echo
  pause_enter
}

print_dashboard() {
  clear_screen
  set_terminal_title
  line
  show_status
  line
  show_quick_actions
  small_line
  show_system_actions
  line
  echo
  echo "${C_BOLD}Choose a number and press Enter.${C_RESET}"
  echo
}

main_loop() {
  while true; do
    print_dashboard
    read -r "?Selection: " choice
    echo

    case "$choice" in
      1) safe_run_ai auto ;;
      2) safe_run_ai one ;;
      3) safe_run_ai atlas ;;
      4) safe_run_ai decide ;;
      5) safe_run_ai research ;;
      6) safe_run_ai root ;;
      7) safe_run_ai solve ;;
      8) safe_run_ai pdebug ;;
      9) safe_run_ai menu ;;
      10) open_chatgpt ;;
      11) open_prompt_dir ;;
      12) open_repo ;;
      13) show_prompt_files ;;
      14) health_check ;;
      15) "$BASE_DIR/terminal/launchers/mqlaunch.sh" ;;
      0) echo "${C_GREEN}Exiting dashboard...${C_RESET}"; exit 0 ;;
      *) echo "${C_RED}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac

    bring_terminal_front
    pause_brief
  done
}

main_loop

