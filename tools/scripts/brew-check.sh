#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source "$BASE_DIR/tools/cli/mq-ui.sh"

# Prints header with ASCII art.
print_header() {
  clear 2>/dev/null || true
  printf '%b' "$C_INFO"
  cat <<'BANNER'
  ██████╗ ██████╗ ███████╗██╗    ██╗
  ██╔══██╗██╔══██╗██╔════╝██║    ██║
  ██████╔╝██████╔╝█████╗  ██║ █╗ ██║
  ██╔══██╗██╔══██╗██╔══╝  ██║███╗██║
  ██████╔╝██║  ██║███████╗╚███╔███╔╝
  ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚══╝╚══╝
BANNER
  printf '       -- HOMEBREW HEALTH CHECK --%b\n\n' "$C_RESET"
}

# Checks brew is installed.
require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew not found. Install from https://brew.sh"
    exit 1
  fi
}

# Shows brew version and prefix.
show_brew_info() {
  local version prefix
  version="$(brew --version | head -1)"
  prefix="$(brew --prefix)"
  printf '%b%s%b  prefix: %s\n\n' "$C_BOLD" "$version" "$C_RESET" "$prefix"
}

# Shows outdated formulae.
show_outdated_formulae() {
  local output count
  section "FORMULAE"
  printf '%bChecking for outdated packages...%b\n' "$C_INFO" "$C_RESET"
  output="$(brew outdated --formula 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    ok "All formulae up to date."
  else
    count="$(echo "$output" | wc -l | tr -d ' ')"
    warn "$count outdated:"
    echo "$output" | while read -r line; do
      printf '  • %s\n' "$line"
    done
  fi
  printf '\n'
}

# Shows outdated casks.
show_outdated_casks() {
  local output count
  section "CASKS"
  printf '%bChecking for outdated casks...%b\n' "$C_INFO" "$C_RESET"
  output="$(brew outdated --cask 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    ok "All casks up to date."
  else
    count="$(echo "$output" | wc -l | tr -d ' ')"
    warn "$count outdated:"
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
  section "DISK"
  if size="$(du -sh "${prefix}/Cellar" 2>/dev/null | cut -f1)"; then
    printf '  Cellar:   %b%s%b\n' "$C_BOLD" "$size" "$C_RESET"
  fi
  if size="$(du -sh "${prefix}/Caskroom" 2>/dev/null | cut -f1)"; then
    printf '  Caskroom: %b%s%b\n' "$C_BOLD" "$size" "$C_RESET"
  fi
  printf '\n'
}

# Runs brew doctor.
run_doctor() {
  local output filtered
  section "DOCTOR"
  printf '%bRunning brew doctor...%b\n' "$C_INFO" "$C_RESET"
  output="$(brew doctor 2>&1 || true)"
  filtered="$(printf '%s\n' "$output" | grep -v '^Your system is ready to brew\.' | grep -v '^$' || true)"
  if [[ -n "$filtered" ]]; then
    printf '%s\n' "$filtered"
  else
    ok "Your system is ready to brew."
  fi
  printf '\n'
}

# Runs brew upgrade with confirmation.
run_upgrade() {
  local confirm
  section "UPGRADE"
  warn "This will upgrade all outdated formulae and casks."
  read -r -p "Proceed? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    brew upgrade
    ok "Upgrade complete."
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
    ok "Nothing to clean up."
    return
  fi
  section "CLEANUP"
  printf '%bWould remove:%b\n' "$C_INFO" "$C_RESET"
  echo "$dry_run" | head -20
  printf '\n'
  read -r -p "Run cleanup? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    brew cleanup
    ok "Cleanup complete."
  else
    printf 'Cleanup skipped.\n'
  fi
  printf '\n'
}

# Prints interactive menu.
print_menu() {
  header "BREW CHECK MENU"
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
      *) err "Unknown command: $cmd"; exit 1 ;;
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
      *) warn "Unknown option: $choice" ;;
    esac
  done
}

main "${1:-}"
