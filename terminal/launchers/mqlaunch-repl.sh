#!/usr/bin/env bash

set -uo pipefail

BASE_DIR="${BASE_DIR:-$HOME/macos-scripts}"
MQ_SHELL="${SHELL:-/bin/zsh}"
MQ_LINE="════════════════════════════════════════════════════"
PROMPT_LABEL="mqlaunch > "
MQ_LAST_STATUS=0
MQ_MODE="repl"

# --- COLORS (subtle) ---
C_RESET='\033[0m'
C_DIM='\033[2m'
C_ACCENT='\033[36m'     # cyan
C_OK='\033[32m'         # green
C_ERR='\033[31m'        # red

get_git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

get_status_symbol() {
  if [[ "$MQ_LAST_STATUS" -eq 0 ]]; then
    printf "%b✔%b" "$C_OK" "$C_RESET"
  else
    printf "%b✖ %d%b" "$C_ERR" "$MQ_LAST_STATUS" "$C_RESET"
  fi
}

get_context_line() {
  local cwd branch status context
  cwd="${PWD/#$HOME/~}"
  branch="$(get_git_branch)"
  status="$(get_status_symbol)"

  context="$cwd"
  [[ -n "$branch" ]] && context="$context · $branch"
  context="$context · $MQ_MODE · $status"

  printf "%b%s%b" "$C_DIM" "$context" "$C_RESET"
}

run_menu() {
  exec "$BASE_DIR/terminal/launchers/mqlaunch.sh"
}

run_doctor() { "$BASE_DIR/tools/scripts/doctor.sh"; }
run_perf() { "$BASE_DIR/terminal/bridges/performance-bridge.sh"; }
run_dev() { "$BASE_DIR/terminal/bridges/dev-bridge.sh"; }
run_tools() { "$BASE_DIR/terminal/menus/mq-tools-menu.sh"; }

run_system() {
  if [[ "${1:-}" == "check" ]]; then
    "$BASE_DIR/tools/scripts/system-check.sh"
  else
    "$BASE_DIR/terminal/menus/mq-system-menu.sh"
  fi
}

print_help() {
  cat <<'HELP'

Core: doctor, perf, dev, tools, system, system check, demo, menu, where
Built-in: help, clear, x
Aliases: d, p, t, sys, sc

HELP
}

print_where() {
  local cwd branch
  cwd="${PWD/#$HOME/~}"
  branch="$(get_git_branch)"

  echo "cwd:   $cwd"
  echo "mode:  $MQ_MODE"
  echo "shell: $MQ_SHELL"
  echo "git:   ${branch:-"-"}"
}

normalize_aliases() {
  case "$1" in
    h) echo "help" ;;
    d) echo "doctor" ;;
    p) echo "perf" ;;
    t) echo "tools" ;;
    sys) echo "system" ;;
    sc) echo "system check" ;;
    q|x) echo "exit" ;;
    *) echo "$1" ;;
  esac
}

run_shell_fallback() {
  local line="$1"
  echo
  echo -e "${C_DIM}[shell] $line${C_RESET}"
  echo
  "$MQ_SHELL" -lc "$line"
}

dispatch_command() {
  local line="$1"

  [[ -z "$line" ]] && return 0
  line="$(normalize_aliases "$line")"

  case "$line" in
    help) print_help ;;
    clear|cls) clear ;;
    exit|quit) return 99 ;;
    menu) run_menu ;;
    where) print_where ;;
    doctor) run_doctor ;;
    perf|performance) run_perf ;;
    dev) run_dev ;;
    tools) run_tools ;;
    demo) run_demo ;;
    "system check") run_system check ;;
    system) run_system ;;
    *) run_shell_fallback "$line" ;;
  esac
}

read_prompt_input() {
  local line context_line
  context_line="$(get_context_line)"

  {
    printf '%s\n' "$MQ_LINE"
    printf '%b%s%b\n' "$C_ACCENT" "$PROMPT_LABEL" "$C_RESET"
    printf '%s\n' "$MQ_LINE"
    printf 'MQLAUNCH — Command Surface\n'
    printf '%s\n' "$context_line"
    printf '%bhelp = commands · x = exit%b\n' "$C_DIM" "$C_RESET"

    printf '\033[5A'
    printf '\033[%dC' "${#PROMPT_LABEL}"
  } > /dev/tty

  IFS= read -r line < /dev/tty

  {
    printf '\033[5B'
    printf '\r'
  } > /dev/tty

  REPLY="$line"
}

main() {
  local line status

  while true; do
    read_prompt_input
    line="$REPLY"
    echo

    dispatch_command "$line"
    status=$?
    MQ_LAST_STATUS=$status

    if [[ $status -eq 99 ]]; then
      echo
      break
    fi

    echo
  done

  echo "[MQ] Bye."
}

main "$@"
