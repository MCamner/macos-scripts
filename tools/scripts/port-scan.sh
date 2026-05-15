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

# Prints header.
print_header() {
  clear 2>/dev/null || true
  printf '%b' "$CYAN"
  cat <<'BANNER'
  ██████╗  ██████╗ ██████╗ ████████╗
  ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
  ██████╔╝██║   ██║██████╔╝   ██║
  ██╔═══╝ ██║   ██║██╔══██╗   ██║
  ██║     ╚██████╔╝██║  ██║   ██║
  ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝
BANNER
  printf '       -- LOCAL PORT LISTENER SCAN --%b\n\n' "$NC"
}

# Prints column header.
print_col_header() {
  printf '%b%-7s %-25s %-8s %-s%b\n' \
    "$BOLD" "PORT" "PROCESS" "PID" "ADDRESS" "$NC"
  printf '%s\n' "────────────────────────────────────────────────────────"
}

# Gets listening ports via lsof.
list_ports() {
  local output
  if ! output="$(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)"; then
    printf '%b[ERROR] Could not read port list (try with sudo).%b\n' "$RED" "$NC"
    return 1
  fi

  print_col_header

  echo "$output" | tail -n +2 | sort -t: -k2 -n | \
  while read -r proc pid _ _ _ _ _ _ addr _; do
    local port host
    port="${addr##*:}"
    host="${addr%:*}"
    printf '%-7s %-25s %-8s %-s\n' \
      "$port" "${proc:0:24}" "$pid" "$host"
  done
}

# Searches for process on a specific port.
search_port() {
  local port="$1"
  local result

  if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    printf '%b[ERROR] Invalid port: %s%b\n' "$RED" "$port" "$NC"
    return 1
  fi

  printf '%b[SEARCH] Port %s...%b\n\n' "$CYAN" "$port" "$NC"
  result="$(lsof -iTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null || true)"

  if [[ -z "$result" ]]; then
    printf '%b  Nothing listening on port %s.%b\n' "$GREEN" "$port" "$NC"
    return 0
  fi

  print_col_header
  echo "$result" | tail -n +2 | while read -r proc pid _ _ _ _ _ _ addr _; do
    local p host
    p="${addr##*:}"
    host="${addr%:*}"
    printf '%-7s %-25s %-8s %-s\n' "$p" "${proc:0:24}" "$pid" "$host"
  done
}

# Searches ports by process name.
search_process() {
  local name="$1"
  local result

  printf '%b[SEARCH] Process "%s"...%b\n\n' "$CYAN" "$name" "$NC"
  result="$(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | grep -i "$name" || true)"

  if [[ -z "$result" ]]; then
    printf '%b  No listening ports found for "%s".%b\n' "$GREEN" "$name" "$NC"
    return 0
  fi

  print_col_header
  echo "$result" | while read -r proc pid _ _ _ _ _ _ addr _; do
    local port host
    port="${addr##*:}"
    host="${addr%:*}"
    printf '%-7s %-25s %-8s %-s\n' "$port" "${proc:0:24}" "$pid" "$host"
  done
}

# Prints interactive menu.
print_menu() {
  printf '\n%b--- PORT SCAN MENU ---%b\n' "$CYAN" "$NC"
  printf '  1. List all listening ports\n'
  printf '  2. Search by port number\n'
  printf '  3. Search by process name\n'
  printf '  q. Quit\n\n'
}

# Runs the main entry point.
main() {
  local cmd="${1:-}"
  print_header

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      list)    list_ports ;;
      port)    search_port "${2:-}" ;;
      proc)    search_process "${2:-}" ;;
      *) printf '%b[ERROR] Unknown command: %s%b\n' "$RED" "$cmd" "$NC"; exit 1 ;;
    esac
    return
  fi

  local choice
  while true; do
    print_menu
    read -r -p "port-scan > " choice
    echo
    case "$choice" in
      1)
        list_ports
        printf '\n'
        ;;
      2)
        read -r -p "Port number: " choice
        search_port "$choice"
        printf '\n'
        ;;
      3)
        read -r -p "Process name: " choice
        search_process "$choice"
        printf '\n'
        ;;
      q|Q|'') printf 'Exiting port-scan.\n'; break ;;
      *) printf '%b[?] Unknown option%b\n' "$YELLOW" "$NC" ;;
    esac
  done
}

main "${1:-}"
