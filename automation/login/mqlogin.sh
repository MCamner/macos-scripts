#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_PROJECT_ROOT="$HOME/macos-scripts"

if [[ ! -d "$PROJECT_ROOT/.git" && -d "$DEFAULT_PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$DEFAULT_PROJECT_ROOT"
fi

PROJECT_NAME="$(basename "$PROJECT_ROOT")"
HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)"
DATE_STAMP="$(date '+%Y-%m-%d %H:%M:%S')"
DATE_SAFE="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$HOME/.macos-scripts/logs/login"
LOG_FILE="$LOG_DIR/mqlogin_${DATE_SAFE}.log"

MODE="menu"
OPEN_FINDER=1
OPEN_CODE=1
OPEN_TERMINAL=1
INLINE=0

mkdir -p "$LOG_DIR"

usage() {
  cat <<'EOF'
mqlogin — stylish login/session boot for macos-scripts + mqlaunch

Usage:
  bash automation/login/mqlogin.sh [options]

Options:
  --menu         Open full `mqlaunch` menu in Terminal (default)
  --about        Show `mqlaunch about`, then return
  --check        Open `mqlaunch check` in Terminal
  --inline       Run in the current terminal instead of opening Terminal.app
  --no-finder    Do not open the project folder
  --no-code      Do not open Visual Studio Code
  --no-terminal  Do not open Terminal.app
  -h, --help     Show this help
EOF
}

info() {
  printf '==> %s\n' "$*"
}

note() {
  printf ' • %s\n' "$*"
}

log_line() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

command_for_terminal() {
  local mq_base_cmd="$1"
  local mq_cmd="$2"

  if [[ "$MODE" == "menu" ]]; then
    printf 'cd %q && clear && printf "\\n🚀 mqlogin booting %s\\n\\n" && %s' \
      "$PROJECT_ROOT" "$PROJECT_NAME" "$mq_cmd"
  else
    printf 'cd %q && clear && printf "\\n🚀 mqlogin booting %s\\n\\n" && %s; printf "\\n"; printf "Handing off to the full mqlaunch menu...\\n\\n"; %s' \
      "$PROJECT_ROOT" "$PROJECT_NAME" "$mq_cmd" "$mq_base_cmd"
  fi
}

detect_mqlaunch_base() {
  if command -v mqlaunch >/dev/null 2>&1; then
    command -v mqlaunch
    return 0
  fi

  if [[ -x "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh" ]]; then
    printf '%q' "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"
    return 0
  fi

  if [[ -x "$PROJECT_ROOT/terminal/launchers/mqlaunch.sh" ]]; then
    printf 'zsh %q' "$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
    return 0
  fi

  return 1
}

fallback_terminal_command() {
  printf 'cd %q && clear && printf "\\n🚀 mqlogin booting %s\\n\\n" && pwd && printf "\\n"; git status || true; printf "\\nTip: install or expose mqlaunch to unlock the full launcher.\\n"' \
    "$PROJECT_ROOT" "$PROJECT_NAME"
}

print_banner() {
  cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║                         MQLOGIN BOOT                        ║
╠══════════════════════════════════════════════════════════════╣
║ Project : $(printf '%-50s' "$PROJECT_NAME")║
║ Host    : $(printf '%-50s' "$HOST_NAME")║
║ Time    : $(printf '%-50s' "$DATE_STAMP")║
╚══════════════════════════════════════════════════════════════╝

EOF
}

run_inline() {
  local mq_base_cmd="$1"
  local mq_cmd="$2"

  print_banner
  info "Project root: $PROJECT_ROOT"
  echo

  if [[ -n "$mq_cmd" ]]; then
    if [[ "$MODE" == "menu" ]]; then
      bash -c "cd \"$PROJECT_ROOT\" && $mq_cmd"
    else
      printf '\n' | bash -c "cd \"$PROJECT_ROOT\" && $mq_cmd"
      echo
      note "Run \`$mq_base_cmd\` for the full menu."
    fi
  else
    bash -c "$(fallback_terminal_command)"
  fi
}

open_terminal_boot() {
  local terminal_command="$1"

  osascript <<OSA
tell application "Terminal"
  activate
  do script "$(printf '%s' "$terminal_command" | sed 's/\\/\\\\/g; s/"/\\"/g')"
end tell
OSA
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      menu)
        MODE="menu"
        shift
        ;;
      about)
        MODE="about"
        shift
        ;;
      check)
        MODE="check"
        shift
        ;;
      --about)
        MODE="about"
        shift
        ;;
      --menu)
        MODE="menu"
        shift
        ;;
      --check)
        MODE="check"
        shift
        ;;
      --inline)
        INLINE=1
        shift
        ;;
      --no-finder)
        OPEN_FINDER=0
        shift
        ;;
      --no-code)
        OPEN_CODE=0
        shift
        ;;
      --no-terminal)
        OPEN_TERMINAL=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  local mq_base_cmd=""
  local mq_cmd=""
  local terminal_payload=""

  parse_args "$@"

  log_line "========================================"
  log_line "MQLOGIN BOOT"
  log_line "Project  : $PROJECT_NAME"
  log_line "Root     : $PROJECT_ROOT"
  log_line "Host     : $HOST_NAME"
  log_line "Mode     : $MODE"
  log_line "Started  : $DATE_STAMP"
  log_line "========================================"

  if [[ ! -d "$PROJECT_ROOT" ]]; then
    log_line "Project directory not found: $PROJECT_ROOT"
    exit 1
  fi

  case "$MODE" in
    about) mq_base_cmd="$(detect_mqlaunch_base || true)"; [[ -n "$mq_base_cmd" ]] && mq_cmd="$mq_base_cmd about" ;;
    check) mq_base_cmd="$(detect_mqlaunch_base || true)"; [[ -n "$mq_base_cmd" ]] && mq_cmd="$mq_base_cmd check" ;;
    menu) mq_base_cmd="$(detect_mqlaunch_base || true)"; [[ -n "$mq_base_cmd" ]] && mq_cmd="$mq_base_cmd" ;;
  esac

  if [[ -n "$mq_cmd" ]]; then
    log_line "mqlaunch status: available"
    log_line "mqlaunch command: $mq_cmd"
    terminal_payload="$(command_for_terminal "$mq_base_cmd" "$mq_cmd")"
  else
    log_line "mqlaunch status: missing, using fallback"
    terminal_payload="$(fallback_terminal_command)"
  fi

  if [[ "$INLINE" -eq 1 ]]; then
    run_inline "$mq_base_cmd" "$mq_cmd"
    log_line "Mode: inline"
    log_line "Done"
    exit 0
  fi

  print_banner
  info "Starting your session flow..."
  echo

  if [[ "$OPEN_FINDER" -eq 1 ]]; then
    note "Opening project folder"
    open "$PROJECT_ROOT"
  fi

  if [[ "$OPEN_CODE" -eq 1 ]]; then
    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
      note "Opening Visual Studio Code"
      open -a "Visual Studio Code" "$PROJECT_ROOT"
    else
      note "Visual Studio Code not found, skipping"
    fi
  fi

  if [[ "$OPEN_TERMINAL" -eq 1 ]]; then
    note "Opening Terminal boot view"
    open_terminal_boot "$terminal_payload"
  fi

  echo
  info "Session ready."
  note "Log saved to $LOG_FILE"
}

main "$@"
