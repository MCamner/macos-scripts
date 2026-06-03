#!/usr/bin/env bash

set -euo pipefail

CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

if [[ ! -t 1 ]]; then
  CYAN=''
  RED=''
  YELLOW=''
  PURPLE=''
  GREEN=''
  BOLD=''
  NC=''
fi

# Prints header.
print_header() {
  clear 2>/dev/null || true
  printf '%b\n' "$PURPLE"
  cat <<'BANNER'
  ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗███████╗██████╗
  ██╔══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗
  ██║  ██║██║   ██║█████╗  ██████╔╝███████╗█████╗  █████╗  ██████╔╝
  ██║  ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══╝  ██╔══╝  ██╔══██╗
  ██████╔╝ ╚████╔╝ ███████╗██║  ██║███████║███████╗███████╗██║  ██║
  ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
BANNER
  printf '             -- SYSTEM PROCESS INTERROGATOR v2.0 --%b\n\n' "$NC"
}

# Coordinates process name behavior.
process_name() {
  local pid="$1"
  local comm
  comm="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
  comm="${comm##*/}"; printf '%s\n' "${comm:-unknown}"
}

# Coordinates process exists behavior.
process_exists() {
  local pid="$1"
  ps -p "$pid" >/dev/null 2>&1
}

# Prints column header.
print_col_header() {
  printf '%b%-7s %-20s %-10s %-10s %-10s%b\n' \
    "$BOLD" "PID" "PROCESS NAME" "CPU%" "MEM%" "STATUS" "$NC"
  printf '%s\n' "----------------------------------------------------------------------"
}

# Coordinates list processes behavior.
list_processes() {
  local rows count app_name

  print_col_header

  if ! rows="$(ps -Ao pid=,pcpu=,pmem=,state=,comm= 2>/dev/null | sort -k2 -nr -k3 -nr)"; then
    printf '%b[ERROR] Unable to read process list.%b\n' "$RED" "$NC" >&2
    return 1
  fi

  count=0
  while read -r pid cpu mem state comm; do
    [[ -n "${pid:-}" ]] || continue
    count=$(( count + 1 ))
    (( count <= 20 )) || break
    app_name="${comm##*/}"; app_name="${app_name:-unknown}"
    printf '%-7s %-20s %-10s %-10s %-10s\n' \
      "$pid" "${app_name:0:19}" "${cpu}%" "${mem}%" "$state"
  done <<< "$rows"
}

# Searches processes by name (case-insensitive).
search_by_name() {
  local query="$1"
  local rows app_name found=0

  if [[ -z "$query" ]]; then
    printf '%b[ERROR] No search term given.%b\n' "$RED" "$NC"
    return 1
  fi

  printf '%b[SEARCH] Processes matching "%s":%b\n\n' "$CYAN" "$query" "$NC"
  print_col_header

  if ! rows="$(ps -Ao pid=,pcpu=,pmem=,state=,comm= 2>/dev/null | sort -k2 -nr)"; then
    printf '%b[ERROR] Unable to read process list.%b\n' "$RED" "$NC" >&2
    return 1
  fi

  while read -r pid cpu mem state comm; do
    [[ -n "${pid:-}" ]] || continue
    app_name="${comm##*/}"; app_name="${app_name:-unknown}"
    if echo "$app_name" | grep -qi "$query" 2>/dev/null; then
      printf '%-7s %-20s %-10s %-10s %-10s\n' \
        "$pid" "${app_name:0:19}" "${cpu}%" "${mem}%" "$state"
      (( found++ )) || true
    fi
  done <<< "$rows"

  if (( found == 0 )); then
    printf '%b  No processes found matching "%s".%b\n' "$GREEN" "$query" "$NC"
  else
    printf '\n%b  %d match(es) found.%b\n' "$CYAN" "$found" "$NC"
  fi
}

# Checks whether safe pid applies.
is_safe_pid() {
  local pid="$1"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  (( pid > 1 )) || return 1
  (( pid != $$ )) || return 1
}

# Coordinates terminate process behavior.
terminate_process() {
  local pid="$1"
  local name="$2"
  local confirm force_confirm

  printf '%b[!] TARGET ACQUIRED:%b %s (%s)\n' "$RED" "$NC" "$name" "$pid"
  read -r -p "Send TERM to this process? [y/N]: " confirm

  [[ "$confirm" =~ ^[Yy]$ ]] || {
    printf 'Target spared.\n'
    return 0
  }

  kill -TERM "$pid"
  sleep 1

  if ! process_exists "$pid"; then
    printf '%b[+] PROCESS %s TERMINATED.%b\n' "$PURPLE" "$pid" "$NC"
    return 0
  fi

  printf '%b[!] PROCESS STILL RUNNING.%b\n' "$YELLOW" "$NC"
  read -r -p "Force kill with KILL? [y/N]: " force_confirm

  [[ "$force_confirm" =~ ^[Yy]$ ]] || {
    printf 'Force kill skipped.\n'
    return 0
  }

  kill -KILL "$pid"
  sleep 0.2
  printf '%b[+] PROCESS %s FORCE KILLED.%b\n' "$PURPLE" "$pid" "$NC"
}

# Handles kill flow: prompt for PID then terminate.
kill_flow() {
  local target_pid name

  printf '\n%b[?] ENTER PID TO TERMINATE OR q TO ABORT:%b\n' "$YELLOW" "$NC"
  read -r -p "OVERSEER > " target_pid

  case "$target_pid" in
    q|Q|'')
      printf 'Aborted.\n'
      return 0
      ;;
  esac

  if ! is_safe_pid "$target_pid"; then
    printf '%b[ERROR] Invalid or protected PID: %s%b\n' "$RED" "$target_pid" "$NC"
    return 1
  fi

  if ! process_exists "$target_pid"; then
    printf '%b[ERROR] PID %s NOT FOUND.%b\n' "$RED" "$target_pid" "$NC"
    return 1
  fi

  name="$(process_name "$target_pid")"
  terminate_process "$target_pid" "$name"
}

# Handles search then kill flow.
search_and_kill_flow() {
  local query target_pid name

  printf '\n%b[?] SEARCH BY NAME (or q to abort):%b\n' "$YELLOW" "$NC"
  read -r -p "OVERSEER > " query

  case "$query" in q|Q|'') printf 'Aborted.\n'; return 0 ;; esac

  printf '\n'
  search_by_name "$query"
  printf '\n'
  kill_flow
}

# Prints interactive menu.
print_menu() {
  printf '%b--- OVERSEER MENU ---%b\n' "$PURPLE" "$NC"
  printf '  1. List top processes\n'
  printf '  2. Search by name\n'
  printf '  3. Kill by PID\n'
  printf '  4. Search then kill\n'
  printf '  q. Quit\n\n'
}

# Runs the main entry point.
main() {
  local cmd="${1:-}"
  print_header

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      list)   list_processes ;;
      search) search_by_name "${2:-}" ;;
      kill)   kill_flow ;;
      *)
        list_processes || return 1
        kill_flow
        ;;
    esac
    return
  fi

  local choice
  while true; do
    print_menu
    read -r -p "OVERSEER > " choice
    echo
    case "$choice" in
      1)
        list_processes
        printf '\n'
        ;;
      2)
        local q
        read -r -p "Name to search: " q
        printf '\n'
        search_by_name "$q"
        printf '\n'
        ;;
      3)
        list_processes
        kill_flow
        printf '\n'
        ;;
      4)
        search_and_kill_flow
        printf '\n'
        ;;
      q|Q|'')
        printf 'Exiting Overseer...\n'
        break
        ;;
      *)
        printf '%b[?] Unknown option%b\n' "$YELLOW" "$NC"
        ;;
    esac
  done
}

main "${1:-}"
