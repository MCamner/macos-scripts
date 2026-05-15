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
  ██████╗ ██████╗ ███████╗██╗    ██╗
  ██╔══██╗██╔══██╗██╔════╝██║    ██║
  ██████╔╝██████╔╝█████╗  ██║ █╗ ██║
  ██╔══██╗██╔══██╗██╔══╝  ██║███╗██║
  ██████╔╝██║  ██║███████╗╚███╔███╔╝
  ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚══╝╚══╝
BANNER
  printf '       -- HOMEBREW HEALTH CHECK --%b\n\n' "$NC"
}

# Checks brew is installed.
require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    printf '%b[ERROR] Homebrew not found. Install from https://brew.sh%b\n' "$RED" "$NC"
    exit 1
  fi
}

# Shows brew version and prefix.
show_brew_info() {
  local version prefix
  version="$(brew --version | head -1)"
  prefix="$(brew --prefix)"
  printf '%b%s%b  prefix: %s\n\n' "$BOLD" "$version" "$NC" "$prefix"
}

# Shows outdated formulae.
show_outdated_formulae() {
  local output count
  printf '%b[FORMULAE] Checking for outdated packages...%b\n' "$CYAN" "$NC"
  output="$(brew outdated --formula 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    printf '%b  All formulae up to date.%b\n' "$GREEN" "$NC"
  else
    count="$(echo "$output" | wc -l | tr -d ' ')"
    printf '%b  %s outdated:%b\n' "$YELLOW" "$count" "$NC"
    echo "$output" | while read -r line; do
      printf '  • %s\n' "$line"
    done
  fi
  printf '\n'
}

# Shows outdated casks.
show_outdated_casks() {
  local output count
  printf '%b[CASKS] Checking for outdated casks...%b\n' "$CYAN" "$NC"
  output="$(brew outdated --cask 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    printf '%b  All casks up to date.%b\n' "$GREEN" "$NC"
  else
    count="$(echo "$output" | wc -l | tr -d ' ')"
    printf '%b  %s outdated:%b\n' "$YELLOW" "$count" "$NC"
    echo "$output" | while read -r line; do
      printf '  • %s\n' "$line"
    done
  fi
  printf '\n'
}

# Shows brew disk usage.
show_disk_usage() {
  local prefix size
  prefix="$(brew --prefix)"
  printf '%b[DISK] Cellar size...%b\n' "$CYAN" "$NC"
  if size="$(du -sh "${prefix}/Cellar" 2>/dev/null | cut -f1)"; then
    printf '  Cellar: %b%s%b\n' "$BOLD" "$size" "$NC"
  fi
  if size="$(du -sh "${prefix}/Caskroom" 2>/dev/null | cut -f1)"; then
    printf '  Caskroom: %b%s%b\n' "$BOLD" "$size" "$NC"
  fi
  printf '\n'
}

# Runs brew doctor.
run_doctor() {
  printf '%b[DOCTOR] Running brew doctor...%b\n' "$CYAN" "$NC"
  if brew doctor 2>&1 | grep -v '^Your system is ready to brew\.' | grep -v '^$'; then
    true
  else
    printf '%b  Your system is ready to brew.%b\n' "$GREEN" "$NC"
  fi
  printf '\n'
}

# Runs brew upgrade with confirmation.
run_upgrade() {
  local confirm
  printf '%b[UPGRADE] This will upgrade all outdated formulae and casks.%b\n' "$YELLOW" "$NC"
  read -r -p "Proceed? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    brew upgrade
    printf '%b[+] Upgrade complete.%b\n' "$GREEN" "$NC"
  else
    printf 'Upgrade skipped.\n'
  fi
  printf '\n'
}

# Runs brew cleanup with confirmation.
run_cleanup() {
  local confirm dry_run
  dry_run="$(brew cleanup --dry-run 2>/dev/null || true)"
  if [[ -z "$dry_run" ]]; then
    printf '%b  Nothing to clean up.%b\n' "$GREEN" "$NC"
    return
  fi
  printf '%b[CLEANUP] Would remove:%b\n' "$CYAN" "$NC"
  echo "$dry_run" | head -20
  printf '\n'
  read -r -p "Run cleanup? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    brew cleanup
    printf '%b[+] Cleanup complete.%b\n' "$GREEN" "$NC"
  else
    printf 'Cleanup skipped.\n'
  fi
  printf '\n'
}

# Prints interactive menu.
print_menu() {
  printf '%b--- BREW CHECK MENU ---%b\n' "$CYAN" "$NC"
  printf '  1. Show outdated formulae + casks\n'
  printf '  2. Disk usage\n'
  printf '  3. Run brew doctor\n'
  printf '  4. Upgrade all\n'
  printf '  5. Cleanup old versions\n'
  printf '  6. Full check (1+2+3)\n'
  printf '  q. Quit\n\n'
}

# Runs full check.
run_full_check() {
  show_outdated_formulae
  show_outdated_casks
  show_disk_usage
  run_doctor
}

# Runs the main entry point.
main() {
  local cmd="${1:-}"
  require_brew
  print_header
  show_brew_info

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      outdated) show_outdated_formulae; show_outdated_casks ;;
      disk)     show_disk_usage ;;
      doctor)   run_doctor ;;
      upgrade)  run_upgrade ;;
      cleanup)  run_cleanup ;;
      full)     run_full_check ;;
      *) printf '%b[ERROR] Unknown command: %s%b\n' "$RED" "$cmd" "$NC"; exit 1 ;;
    esac
    return
  fi

  local choice
  while true; do
    print_menu
    read -r -p "brew-check > " choice
    echo
    case "$choice" in
      1) show_outdated_formulae; show_outdated_casks ;;
      2) show_disk_usage ;;
      3) run_doctor ;;
      4) run_upgrade ;;
      5) run_cleanup ;;
      6) run_full_check ;;
      q|Q|'') printf 'Exiting brew-check.\n'; break ;;
      *) printf '%b[?] Unknown option: %s%b\n' "$YELLOW" "$choice" "$NC" ;;
    esac
  done
}

main "${1:-}"
