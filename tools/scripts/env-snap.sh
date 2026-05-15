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

SNAP_DIR="${HOME}/.local/share/mq-env-snap"

# Prints header.
print_header() {
  clear 2>/dev/null || true
  printf '%b' "$CYAN"
  cat <<'BANNER'
  ███████╗███╗   ██╗██╗   ██╗    ███████╗███╗   ██╗ █████╗ ██████╗
  ██╔════╝████╗  ██║██║   ██║    ██╔════╝████╗  ██║██╔══██╗██╔══██╗
  █████╗  ██╔██╗ ██║██║   ██║    ███████╗██╔██╗ ██║███████║██████╔╝
  ██╔══╝  ██║╚██╗██║╚██╗ ██╔╝    ╚════██║██║╚██╗██║██╔══██║██╔═══╝
  ███████╗██║ ╚████║ ╚████╔╝     ███████║██║ ╚████║██║  ██║██║
  ╚══════╝╚═╝  ╚═══╝  ╚═══╝      ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝
BANNER
  printf '       -- ENVIRONMENT SNAPSHOT --%b\n\n' "$NC"
}

# Returns snapshot filename for given label.
snap_file() {
  local label="${1:-snap}"
  printf '%s/%s_%s.env\n' "$SNAP_DIR" "$label" "$(date '+%Y%m%d_%H%M%S')"
}

# Captures environment to file.
capture_snap() {
  local label="${1:-snap}"
  local file
  file="$(snap_file "$label")"
  mkdir -p "$SNAP_DIR"

  {
    printf '# env-snap: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '# label: %s\n' "$label"
    printf '# host: %s\n\n' "$(hostname -s 2>/dev/null || echo unknown)"

    printf '## PATH\n'
    echo "$PATH" | tr ':' '\n' | while read -r p; do printf '  %s\n' "$p"; done
    printf '\n'

    printf '## ENV VARS\n'
    env | grep -v -E '^(ANTHROPIC_API_KEY|AWS_|GITHUB_TOKEN|SECRET|PASSWORD|PASS=|TOKEN=|KEY=)' \
      | sort \
      | while IFS='=' read -r k v; do
          printf '  %s=%s\n' "$k" "${v:0:120}"
        done
    printf '\n'

    printf '## SHELL\n'
    printf '  SHELL=%s\n' "${SHELL:-unknown}"
    printf '  ZSH_VERSION=%s\n' "${ZSH_VERSION:-n/a}"
    printf '  BASH_VERSION=%s\n' "${BASH_VERSION:-n/a}"
    printf '\n'

    printf '## TOP PROCESSES (by CPU)\n'
    ps -Ao pcpu=,comm= 2>/dev/null | sort -rn | head -10 | \
      while read -r cpu comm; do
        printf '  %s%%  %s\n' "$cpu" "$(basename "$comm")"
      done
    printf '\n'

    printf '## DISK\n'
    df -h / 2>/dev/null | tail -1 | awk '{printf "  /: %s used of %s (%s full)\n", $3, $2, $5}'
    printf '\n'

    printf '## NETWORK\n'
    local ip
    ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 'n/a')"
    printf '  IP: %s\n' "$ip"
    printf '\n'

    printf '## GIT (if in repo)\n'
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '  branch: %s\n' "$(git branch --show-current 2>/dev/null || echo unknown)"
      printf '  status: %s changes\n' "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    else
      printf '  not in a git repo\n'
    fi

  } > "$file"

  printf '%b[+] Snapshot saved:%b %s\n' "$GREEN" "$NC" "$file"
  echo "$file"
}

# Lists saved snapshots.
list_snaps() {
  printf '%b[SNAPSHOTS] in %s:%b\n\n' "$CYAN" "$SNAP_DIR" "$NC"
  if [[ ! -d "$SNAP_DIR" ]] || [[ -z "$(ls -A "$SNAP_DIR" 2>/dev/null)" ]]; then
    printf '  No snapshots yet.\n\n'
    return
  fi
  local i=1
  ls -t "$SNAP_DIR"/*.env 2>/dev/null | while read -r f; do
    printf '  %d. %s\n' "$i" "$(basename "$f")"
    (( i++ )) || true
  done
  printf '\n'
}

# Views a snapshot.
view_snap() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf '%b[ERROR] File not found: %s%b\n' "$RED" "$file" "$NC"
    return 1
  fi
  printf '%b=== %s ===%b\n\n' "$CYAN" "$(basename "$file")" "$NC"
  cat "$file"
  printf '\n'
}

# Diffs two snapshot files.
diff_snaps() {
  local a="$1" b="$2"
  if [[ ! -f "$a" ]]; then
    printf '%b[ERROR] File not found: %s%b\n' "$RED" "$a" "$NC"; return 1
  fi
  if [[ ! -f "$b" ]]; then
    printf '%b[ERROR] File not found: %s%b\n' "$RED" "$b" "$NC"; return 1
  fi
  printf '%b[DIFF] %s vs %s%b\n\n' "$CYAN" "$(basename "$a")" "$(basename "$b")" "$NC"
  diff --color=always "$a" "$b" || true
  printf '\n'
}

# Picks a snapshot interactively.
pick_snap() {
  local prompt="${1:-Select snapshot}"
  list_snaps
  local files
  mapfile -t files < <(ls -t "$SNAP_DIR"/*.env 2>/dev/null || true)
  if [[ ${#files[@]} -eq 0 ]]; then
    printf '%b  No snapshots available.%b\n' "$YELLOW" "$NC"
    return 1
  fi
  local n
  read -r -p "$prompt [1-${#files[@]}]: " n
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > ${#files[@]} )); then
    printf '%b[ERROR] Invalid selection.%b\n' "$RED" "$NC"
    return 1
  fi
  PICKED_SNAP="${files[$(( n - 1 ))]}"
}

# Prints interactive menu.
print_menu() {
  printf '%b--- ENV SNAP MENU ---%b\n' "$CYAN" "$NC"
  printf '  1. Capture snapshot\n'
  printf '  2. List snapshots\n'
  printf '  3. View snapshot\n'
  printf '  4. Diff two snapshots\n'
  printf '  q. Quit\n\n'
}

# Runs the main entry point.
main() {
  local cmd="${1:-}"
  print_header

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      capture) capture_snap "${2:-snap}" ;;
      list)    list_snaps ;;
      view)    view_snap "${2:-}" ;;
      diff)    diff_snaps "${2:-}" "${3:-}" ;;
      *) printf '%b[ERROR] Unknown command: %s%b\n' "$RED" "$cmd" "$NC"; exit 1 ;;
    esac
    return
  fi

  local choice label
  while true; do
    print_menu
    read -r -p "env-snap > " choice
    echo
    case "$choice" in
      1)
        read -r -p "Label [snap]: " label
        capture_snap "${label:-snap}"
        printf '\n'
        ;;
      2)
        list_snaps
        ;;
      3)
        if pick_snap "View which snapshot"; then
          view_snap "$PICKED_SNAP"
        fi
        ;;
      4)
        local snap_a snap_b
        printf 'First snapshot:\n'
        if pick_snap "Snapshot A"; then snap_a="$PICKED_SNAP"; else continue; fi
        printf 'Second snapshot:\n'
        if pick_snap "Snapshot B"; then snap_b="$PICKED_SNAP"; else continue; fi
        diff_snaps "$snap_a" "$snap_b"
        ;;
      q|Q|'') printf 'Exiting env-snap.\n'; break ;;
      *) printf '%b[?] Unknown option%b\n' "$YELLOW" "$NC" ;;
    esac
  done
}

main "${1:-}"
