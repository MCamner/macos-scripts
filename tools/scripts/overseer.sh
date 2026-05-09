#!/usr/bin/env bash

set -euo pipefail

CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

if [[ ! -t 1 ]]; then
  CYAN=''
  RED=''
  YELLOW=''
  PURPLE=''
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
  printf '             -- SYSTEM PROCESS INTERROGATOR v1.1 --%b\n\n' "$NC"
}

# Handles process name.
process_name() {
  local pid="$1"
  local comm
  comm="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
  basename "${comm:-unknown}"
}

# Handles process exists.
process_exists() {
  local pid="$1"
  ps -p "$pid" >/dev/null 2>&1
}

# Handles list processes.
list_processes() {
  local rows count app_name

  printf '%b%-7s %-20s %-10s %-10s %-10s%b\n' \
    "$CYAN" "PID" "PROCESS NAME" "CPU%" "MEM%" "STATUS" "$NC"
  printf '%s\n' "----------------------------------------------------------------------"

  if ! rows="$(ps -Ao pid=,pcpu=,pmem=,state=,comm= 2>/dev/null | sort -k2 -nr -k3 -nr)"; then
    printf '%b[ERROR] Unable to read process list.%b\n' "$RED" "$NC" >&2
    return 1
  fi

  count=0
  while read -r pid cpu mem state comm; do
    [[ -n "${pid:-}" ]] || continue
    (( count++ ))
    (( count <= 10 )) || break
    app_name="$(basename "${comm:-unknown}")"
    printf '%-7s %-20s %-10s %-10s %-10s\n' \
      "$pid" "${app_name:0:19}" "${cpu}%" "${mem}%" "$state"
  done <<< "$rows"
}

# Checks whether safe pid applies.
is_safe_pid() {
  local pid="$1"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  (( pid > 1 )) || return 1
  (( pid != $$ )) || return 1
}

# Handles terminate process.
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

# Runs the main entry point.
main() {
  local target_pid name

  print_header
  list_processes || return 1

  printf '\n%b[?] ENTER PID TO TERMINATE OR q TO ABORT:%b\n' "$YELLOW" "$NC"
  read -r -p "OVERSEER > " target_pid

  case "$target_pid" in
    q|Q|'')
      printf 'Exiting Overseer...\n'
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

main "$@"
