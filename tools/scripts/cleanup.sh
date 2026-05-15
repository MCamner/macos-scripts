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
   ██████╗██╗     ███████╗ █████╗ ███╗   ██╗██╗   ██╗██████╗
  ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██║   ██║██╔══██╗
  ██║     ██║     █████╗  ███████║██╔██╗ ██║██║   ██║██████╔╝
  ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██║   ██║██╔═══╝
  ╚██████╗███████╗███████╗██║  ██║██║ ╚████║╚██████╔╝██║
   ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝
BANNER
  printf '       -- MACOS CLEANUP TOOL --%b\n\n' "$NC"
}

# Returns human-readable size of a path.
dir_size() {
  du -sh "$1" 2>/dev/null | cut -f1 || echo '?'
}

# Counts files older than N days in a directory.
count_old_files() {
  local dir="$1" days="$2"
  find "$dir" -maxdepth 1 -type f -mtime +"$days" 2>/dev/null | wc -l | tr -d ' '
}

# Empties trash with confirmation.
clean_trash() {
  local trash_path="${HOME}/.Trash"
  local size count confirm

  size="$(dir_size "$trash_path")"
  count="$(find "$trash_path" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"

  printf '%b[TRASH] %s items, %s%b\n' "$CYAN" "$count" "$size" "$NC"

  if [[ "$count" -eq 0 ]]; then
    printf '%b  Trash is already empty.%b\n\n' "$GREEN" "$NC"
    return
  fi

  read -r -p "  Empty Trash? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "${trash_path:?}"/* 2>/dev/null || true
    printf '%b  [+] Trash emptied.%b\n' "$GREEN" "$NC"
  else
    printf '  Skipped.\n'
  fi
  printf '\n'
}

# Cleans old Downloads files.
clean_downloads() {
  local days="${1:-30}"
  local downloads="${HOME}/Downloads"
  local count confirm

  count="$(count_old_files "$downloads" "$days")"
  printf '%b[DOWNLOADS] Files older than %d days: %s%b\n' "$CYAN" "$days" "$count" "$NC"

  if [[ "$count" -eq 0 ]]; then
    printf '%b  Nothing to clean.%b\n\n' "$GREEN" "$NC"
    return
  fi

  printf '  Preview:\n'
  find "$downloads" -maxdepth 1 -type f -mtime +"$days" 2>/dev/null | head -10 | \
    while read -r f; do printf '    %s\n' "$(basename "$f")"; done
  printf '\n'

  read -r -p "  Delete these ${count} files? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    find "$downloads" -maxdepth 1 -type f -mtime +"$days" -delete 2>/dev/null || true
    printf '%b  [+] Done.%b\n' "$GREEN" "$NC"
  else
    printf '  Skipped.\n'
  fi
  printf '\n'
}

# Cleans Xcode derived data.
clean_xcode() {
  local derived="${HOME}/Library/Developer/Xcode/DerivedData"
  local size confirm

  if [[ ! -d "$derived" ]]; then
    printf '%b[XCODE] DerivedData not found — skipping.%b\n\n' "$YELLOW" "$NC"
    return
  fi

  size="$(dir_size "$derived")"
  printf '%b[XCODE] DerivedData: %s%b\n' "$CYAN" "$size" "$NC"

  read -r -p "  Clear DerivedData? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "${derived:?}"/* 2>/dev/null || true
    printf '%b  [+] Cleared.%b\n' "$GREEN" "$NC"
  else
    printf '  Skipped.\n'
  fi
  printf '\n'
}

# Cleans npm cache.
clean_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    printf '%b[NPM] npm not found — skipping.%b\n\n' "$YELLOW" "$NC"
    return
  fi
  local size confirm
  local cache_dir
  cache_dir="$(npm config get cache 2>/dev/null || echo "${HOME}/.npm")"
  size="$(dir_size "$cache_dir")"
  printf '%b[NPM] Cache: %s%b\n' "$CYAN" "$size" "$NC"
  read -r -p "  Clean npm cache? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    npm cache clean --force 2>/dev/null || true
    printf '%b  [+] npm cache cleaned.%b\n' "$GREEN" "$NC"
  else
    printf '  Skipped.\n'
  fi
  printf '\n'
}

# Cleans pip cache.
clean_pip() {
  if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
    printf '%b[PIP] pip not found — skipping.%b\n\n' "$YELLOW" "$NC"
    return
  fi
  local pip_cmd confirm
  pip_cmd="$(command -v pip3 2>/dev/null || echo pip)"
  local cache_dir
  cache_dir="$($pip_cmd cache dir 2>/dev/null || echo "${HOME}/Library/Caches/pip")"
  local size
  size="$(dir_size "$cache_dir")"
  printf '%b[PIP] Cache: %s%b\n' "$CYAN" "$size" "$NC"
  read -r -p "  Clean pip cache? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    "$pip_cmd" cache purge 2>/dev/null || true
    printf '%b  [+] pip cache cleaned.%b\n' "$GREEN" "$NC"
  else
    printf '  Skipped.\n'
  fi
  printf '\n'
}

# Shows current free disk space.
show_disk_free() {
  local free used total pct
  read -r _ total used free pct _ < <(df -h / | tail -1)
  printf '%b[DISK] / — %s used of %s (%s full), %s free%b\n\n' \
    "$BOLD" "$used" "$total" "$pct" "$free" "$NC"
}

# Runs full cleanup.
run_full_cleanup() {
  show_disk_free
  clean_trash
  clean_downloads 30
  clean_xcode
  clean_npm
  clean_pip
  printf '%b[DONE] Cleanup complete.%b\n' "$GREEN" "$NC"
  show_disk_free
}

# Prints interactive menu.
print_menu() {
  printf '%b--- CLEANUP MENU ---%b\n' "$CYAN" "$NC"
  printf '  1. Empty Trash\n'
  printf '  2. Old Downloads (>30 days)\n'
  printf '  3. Xcode DerivedData\n'
  printf '  4. npm cache\n'
  printf '  5. pip cache\n'
  printf '  6. Full cleanup (all of the above)\n'
  printf '  d. Show disk space\n'
  printf '  q. Quit\n\n'
}

# Runs the main entry point.
main() {
  local cmd="${1:-}"
  print_header

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      trash)     clean_trash ;;
      downloads) clean_downloads "${2:-30}" ;;
      xcode)     clean_xcode ;;
      npm)       clean_npm ;;
      pip)       clean_pip ;;
      full)      run_full_cleanup ;;
      disk)      show_disk_free ;;
      *) printf '%b[ERROR] Unknown command: %s%b\n' "$RED" "$cmd" "$NC"; exit 1 ;;
    esac
    return
  fi

  local choice
  while true; do
    show_disk_free
    print_menu
    read -r -p "cleanup > " choice
    echo
    case "$choice" in
      1) clean_trash ;;
      2) clean_downloads 30 ;;
      3) clean_xcode ;;
      4) clean_npm ;;
      5) clean_pip ;;
      6) run_full_cleanup ;;
      d|D) show_disk_free ;;
      q|Q|'') printf 'Exiting cleanup.\n'; break ;;
      *) printf '%b[?] Unknown option%b\n' "$YELLOW" "$NC" ;;
    esac
  done
}

main "${1:-}"
