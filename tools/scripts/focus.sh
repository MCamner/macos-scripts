#!/usr/bin/env bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

if [[ ! -t 1 ]]; then
  CYAN='' GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

LOG_DIR="${HOME}/.local/share/mq-focus"
LOG_FILE="${LOG_DIR}/sessions.log"

# Prints header.
print_header() {
  clear 2>/dev/null || true
  printf '%b' "$CYAN"
  cat <<'BANNER'
  ███████╗ ██████╗  ██████╗██╗   ██╗███████╗
  ██╔════╝██╔═══██╗██╔════╝██║   ██║██╔════╝
  █████╗  ██║   ██║██║     ██║   ██║███████╗
  ██╔══╝  ██║   ██║██║     ██║   ██║╚════██║
  ██║     ╚██████╔╝╚██████╗╚██████╔╝███████║
  ╚═╝      ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝
BANNER
  printf '       -- POMODORO FOCUS TIMER --%b\n\n' "$NC"
}

# Sends macOS notification.
notify() {
  local title="$1" msg="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
  fi
}

# Logs a completed session.
log_session() {
  local type="$1" duration="$2"
  mkdir -p "$LOG_DIR"
  printf '%s\t%s\t%dm\n' "$(date '+%Y-%m-%d %H:%M')" "$type" "$duration" >> "$LOG_FILE"
}

# Formats seconds as mm:ss.
format_time() {
  local secs="$1"
  printf '%02d:%02d' $(( secs / 60 )) $(( secs % 60 ))
}

# Runs a countdown timer.
run_timer() {
  local label="$1" total_secs="$2" color="$3"
  local remaining="$total_secs" interrupted=0

  printf '%b[%s] Starting — press Ctrl+C to skip%b\n\n' "$color" "$label" "$NC"

  trap 'interrupted=1' INT

  while (( remaining > 0 )); do
    printf '\r  %b%s%b  remaining: %b%s%b  ' \
      "$color" "$label" "$NC" \
      "$BOLD" "$(format_time "$remaining")" "$NC"
    sleep 1
    (( remaining-- )) || true
    if (( interrupted )); then
      break
    fi
  done

  trap - INT
  printf '\n\n'

  if (( interrupted )); then
    printf '%b[!] Session interrupted.%b\n\n' "$YELLOW" "$NC"
    return 1
  fi

  return 0
}

# Runs one pomodoro cycle.
run_cycle() {
  local work_mins="${1:-25}" break_mins="${2:-5}" session_label="${3:-Focus}"
  local work_secs=$(( work_mins * 60 ))
  local break_secs=$(( break_mins * 60 ))

  printf '%b[WORK] %s — %d minutes%b\n' "$GREEN" "$session_label" "$work_mins" "$NC"
  if run_timer "WORK" "$work_secs" "$GREEN"; then
    notify "Focus — Work Done" "Great work! Time for a ${break_mins}m break."
    log_session "work" "$work_mins"
    printf '%b[BREAK] %d minutes%b\n' "$CYAN" "$break_mins" "$NC"
    if run_timer "BREAK" "$break_secs" "$CYAN"; then
      notify "Focus — Break Over" "Back to work!"
      log_session "break" "$break_mins"
    fi
  fi
}

# Shows session log.
show_log() {
  printf '%b[SESSION LOG]%b\n' "$CYAN" "$NC"
  if [[ ! -f "$LOG_FILE" ]]; then
    printf '  No sessions logged yet.\n\n'
    return
  fi
  printf '%b%-18s %-10s %s%b\n' "$BOLD" "DATE" "TYPE" "DURATION" "$NC"
  printf '%s\n' "────────────────────────────────"
  tail -20 "$LOG_FILE" | while IFS=$'\t' read -r ts type dur; do
    printf '%-18s %-10s %s\n' "$ts" "$type" "$dur"
  done
  local total
  total="$(grep -c 'work' "$LOG_FILE" 2>/dev/null || echo 0)"
  printf '\n  Total work sessions logged: %b%s%b\n\n' "$BOLD" "$total" "$NC"
}

# Prints interactive menu.
print_menu() {
  printf '%b--- FOCUS MENU ---%b\n' "$CYAN" "$NC"
  printf '  1. Start 25/5 Pomodoro (standard)\n'
  printf '  2. Start 50/10 deep work session\n'
  printf '  3. Custom timer\n'
  printf '  4. View session log\n'
  printf '  q. Quit\n\n'
}

# Runs the main entry point.
main() {
  local cmd="${1:-}"
  print_header

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      start)  run_cycle 25 5 "Focus" ;;
      deep)   run_cycle 50 10 "Deep Work" ;;
      log)    show_log ;;
      *) printf '%b[ERROR] Unknown command: %s%b\n' "$RED" "$cmd" "$NC"; exit 1 ;;
    esac
    return
  fi

  local choice work_mins break_mins label
  while true; do
    print_menu
    read -r -p "focus > " choice
    echo
    case "$choice" in
      1) run_cycle 25 5 "Focus" ;;
      2) run_cycle 50 10 "Deep Work" ;;
      3)
        read -r -p "Work minutes [25]: " work_mins
        work_mins="${work_mins:-25}"
        read -r -p "Break minutes [5]: " break_mins
        break_mins="${break_mins:-5}"
        read -r -p "Label [Focus]: " label
        label="${label:-Focus}"
        run_cycle "$work_mins" "$break_mins" "$label"
        ;;
      4) show_log ;;
      q|Q|'') printf 'Exiting focus.\n'; break ;;
      *) printf '%b[?] Unknown option%b\n' "$YELLOW" "$NC" ;;
    esac
  done
}

main "${1:-}"
