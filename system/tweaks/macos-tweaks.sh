#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
BACKUP_DIR="${HOME}/.macos-tweaks-backup"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/backup-${TIMESTAMP}.txt"

DRY_RUN=0
VERBOSE=0
COMMAND="menu"

APP_TITLE="macOS Tweaks Utility"
APP_SUBTITLE="MQLaunch Module"
APP_AUTHOR="Author Mattias Camner"

BOX_INNER=88

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RED='\033[31m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_BLUE='\033[34m'
C_CYAN='\033[36m'

log()  { printf "%b%s%b\n" "$C_BLUE" "$1" "$C_RESET"; }
ok()   { printf "%b%s%b\n" "$C_GREEN" "$1" "$C_RESET"; }
warn() { printf "%b%s%b\n" "$C_YELLOW" "$1" "$C_RESET"; }
err()  { printf "%b%s%b\n" "$C_RED" "$1" "$C_RESET" >&2; }

repeat_char() {
  local count="$1"
  local char="$2"
  printf '%*s' "$count" '' | tr ' ' "$char"
}

border() {
  printf '%s\n' "$(repeat_char "$BOX_INNER" "-")"
}

row() {
  local text="$1"
  printf "%-*.*s\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

row_bold() {
  local text="$1"
  printf "${C_BOLD}%-*.*s${C_RESET}\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

row2() {
  local c1="$1"
  local c2="$2"
  row "$(printf '%-40s %-40s' "$c1" "$c2")"
}

header_dual_row() {
  local left="$1"
  local right="$2"
  printf "%-54s %33s\n" "$left" "$right"
}

clear_screen() {
  if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
    tput clear
  else
    clear
  fi
}

short_host() {
  hostname -s 2>/dev/null || hostname
}

print_header() {
  clear_screen
  border
  header_dual_row "$APP_TITLE" "        .-."
  header_dual_row "$APP_SUBTITLE" "       (o o)"
  header_dual_row "$APP_AUTHOR" "       | O \\"
  header_dual_row "" "        \\   \\"
  header_dual_row "" "         \`~~~'"
  border
}

print_footer() {
  local now host user_name
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  host="$(short_host)"
  user_name="$USER"

  printf '\n'
  row "Host: ${host}   User: ${user_name}"
  row "Time: ${now}"
  border
}

pause_enter() {
  echo
  read -r -p "Press Enter to continue..." _
}

usage() {
  cat <<USAGE
$SCRIPT_NAME - macOS tweaks utility

Usage:
  $SCRIPT_NAME [command] [options]

Commands:
  menu            Open interactive menu
  status          Show current tweak status
  backup          Backup current values
  revert-latest   Revert using the latest backup
  dev             Apply developer tweaks
  clean           Apply clean UI tweaks
  fast            Apply speed/productivity tweaks
  workstation     Apply a balanced daily-driver setup
  all             Apply dev + clean + fast

Options:
  --dry-run       Preview only, do not change anything
  -v, --verbose   Show commands as they run
  -h, --help      Show help
USAGE
}

ensure_backup_dir() {
  mkdir -p "$BACKUP_DIR"
}

run_cmd() {
  local cmd="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "%b[dry-run]%b %s\n" "$C_YELLOW" "$C_RESET" "$cmd"
  else
    [[ "$VERBOSE" -eq 1 ]] && printf "%b[run]%b %s\n" "$C_CYAN" "$C_RESET" "$cmd"
    eval "$cmd"
  fi
}

read_pref() {
  local domain="$1"
  local key="$2"
  defaults read "$domain" "$key" 2>/dev/null || true
}

print_pref() {
  local label="$1"
  local domain="$2"
  local key="$3"
  local value
  value="$(read_pref "$domain" "$key")"
  [[ -z "$value" ]] && value="__UNSET__"
  printf "  %-28s %s\n" "$label" "$value"
}

backup_pref() {
  local domain="$1"
  local key="$2"
  local value
  value="$(defaults read "$domain" "$key" 2>/dev/null || echo "__UNSET__")"
  printf "%s\t%s\t%s\n" "$domain" "$key" "$value" >> "$BACKUP_FILE"
}

backup_selected() {
  ensure_backup_dir
  : > "$BACKUP_FILE"

  log "Creating backup: $BACKUP_FILE"

  backup_pref "com.apple.dock" "autohide"
  backup_pref "com.apple.dock" "autohide-delay"
  backup_pref "com.apple.dock" "autohide-time-modifier"
  backup_pref "com.apple.dock" "show-recents"
  backup_pref "com.apple.dock" "tilesize"
  backup_pref "com.apple.dock" "mineffect"
  backup_pref "com.apple.dock" "minimize-to-application"
  backup_pref "com.apple.dock" "showhidden"

  backup_pref "com.apple.finder" "AppleShowAllFiles"
  backup_pref "com.apple.finder" "ShowPathbar"
  backup_pref "com.apple.finder" "ShowStatusBar"
  backup_pref "com.apple.finder" "FXPreferredViewStyle"
  backup_pref "com.apple.finder" "_FXSortFoldersFirst"
  backup_pref "com.apple.finder" "FXEnableExtensionChangeWarning"

  backup_pref "NSGlobalDomain" "AppleShowAllExtensions"
  backup_pref "NSGlobalDomain" "KeyRepeat"
  backup_pref "NSGlobalDomain" "InitialKeyRepeat"

  backup_pref "com.apple.desktopservices" "DSDontWriteNetworkStores"
  backup_pref "com.apple.desktopservices" "DSDontWriteUSBStores"

  backup_pref "com.apple.screencapture" "location"
  backup_pref "com.apple.screencapture" "type"

  backup_pref "com.apple.screensaver" "askForPassword"
  backup_pref "com.apple.screensaver" "askForPasswordDelay"

  backup_pref "com.apple.AdLib" "allowApplePersonalizedAdvertising"

  ok "Backup saved."
}

latest_backup() {
  ls -t "$BACKUP_DIR"/backup-*.txt 2>/dev/null | head -n 1 || true
}

show_latest_backup() {
  local latest
  latest="$(latest_backup)"
  if [[ -z "$latest" ]]; then
    warn "No backup file found."
    return 1
  fi
  printf "%s\n" "$latest"
}

revert_from_file() {
  local file="$1"

  [[ -f "$file" ]] || { err "Backup file not found: $file"; return 1; }

  log "Reverting from backup: $file"

  while IFS=$'\t' read -r domain key value; do
    [[ -z "${domain:-}" || -z "${key:-}" ]] && continue

    if [[ "$value" == "__UNSET__" ]]; then
      run_cmd "defaults delete \"$domain\" \"$key\" >/dev/null 2>&1 || true"
      continue
    fi

    case "$value" in
      true|false)
        run_cmd "defaults write \"$domain\" \"$key\" -bool \"$value\""
        ;;
      ''|*[!0-9.-]*)
        run_cmd "defaults write \"$domain\" \"$key\" -string \"$value\""
        ;;
      *)
        if [[ "$value" == *.* ]]; then
          run_cmd "defaults write \"$domain\" \"$key\" -float \"$value\""
        else
          run_cmd "defaults write \"$domain\" \"$key\" -int \"$value\""
        fi
        ;;
    esac
  done < "$file"

  restart_affected_apps
  ok "Revert complete."
}

revert_latest() {
  local latest
  latest="$(latest_backup)"
  if [[ -z "$latest" ]]; then
    warn "No backup file found."
    return 1
  fi
  revert_from_file "$latest"
}

restart_affected_apps() {
  log "Restarting affected apps..."
  run_cmd "killall Dock >/dev/null 2>&1 || true"
  run_cmd "killall Finder >/dev/null 2>&1 || true"
  run_cmd "killall SystemUIServer >/dev/null 2>&1 || true"
  ok "Done."
}

apply_dev_tweaks() {
  log "${C_BOLD}Applying developer tweaks...${C_RESET}"

  run_cmd 'defaults write com.apple.finder AppleShowAllFiles -bool true'
  run_cmd 'defaults write NSGlobalDomain AppleShowAllExtensions -bool true'
  run_cmd 'defaults write com.apple.finder ShowPathbar -bool true'
  run_cmd 'defaults write com.apple.finder ShowStatusBar -bool true'
  run_cmd 'defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"'

  run_cmd 'defaults write NSGlobalDomain KeyRepeat -int 2'
  run_cmd 'defaults write NSGlobalDomain InitialKeyRepeat -int 15'

  run_cmd 'defaults write com.apple.dock show-recents -bool false'
  run_cmd 'defaults write com.apple.dock autohide -bool true'
  run_cmd 'defaults write com.apple.dock autohide-delay -float 0'
  run_cmd 'defaults write com.apple.dock autohide-time-modifier -float 0.15'
  run_cmd 'defaults write com.apple.dock tilesize -int 36'

  ok "Developer tweaks applied."
}

apply_clean_tweaks() {
  log "${C_BOLD}Applying clean UI tweaks...${C_RESET}"

  run_cmd 'defaults write com.apple.dock mineffect -string "scale"'
  run_cmd 'defaults write com.apple.dock minimize-to-application -bool true'
  run_cmd 'defaults write com.apple.dock showhidden -bool true'

  run_cmd 'defaults write com.apple.finder _FXSortFoldersFirst -bool true'
  run_cmd 'defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false'

  run_cmd 'defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
  run_cmd 'defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true'

  ok "Clean tweaks applied."
}

apply_fast_tweaks() {
  log "${C_BOLD}Applying speed/productivity tweaks...${C_RESET}"

  run_cmd 'defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false'
  run_cmd 'defaults write com.apple.screensaver askForPassword -int 1'
  run_cmd 'defaults write com.apple.screensaver askForPasswordDelay -int 0'
  run_cmd 'mkdir -p "${HOME}/Screenshots"'
  run_cmd 'defaults write com.apple.screencapture location -string "${HOME}/Screenshots"'
  run_cmd 'defaults write com.apple.screencapture type -string "png"'

  ok "Fast tweaks applied."
}

apply_workstation_tweaks() {
  log "${C_BOLD}Applying workstation profile...${C_RESET}"

  run_cmd 'defaults write com.apple.finder ShowPathbar -bool true'
  run_cmd 'defaults write com.apple.finder ShowStatusBar -bool true'
  run_cmd 'defaults write NSGlobalDomain AppleShowAllExtensions -bool true'
  run_cmd 'defaults write com.apple.finder _FXSortFoldersFirst -bool true'

  run_cmd 'defaults write com.apple.dock autohide -bool true'
  run_cmd 'defaults write com.apple.dock show-recents -bool false'
  run_cmd 'defaults write com.apple.dock tilesize -int 42'
  run_cmd 'defaults write com.apple.dock minimize-to-application -bool true'

  run_cmd 'defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
  run_cmd 'defaults write com.apple.screensaver askForPassword -int 1'
  run_cmd 'defaults write com.apple.screensaver askForPasswordDelay -int 0'

  ok "Workstation tweaks applied."
}

show_status() {
  print_header
  row_bold "TWEAKS STATUS"
  printf '\n'

  print_pref "Dock autohide"                "com.apple.dock"            "autohide"
  print_pref "Dock show recents"            "com.apple.dock"            "show-recents"
  print_pref "Dock tile size"               "com.apple.dock"            "tilesize"
  print_pref "Dock minimize effect"         "com.apple.dock"            "mineffect"
  print_pref "Dock minimize to app"         "com.apple.dock"            "minimize-to-application"
  print_pref "Dock hidden translucency"     "com.apple.dock"            "showhidden"

  print_pref "Finder show hidden files"     "com.apple.finder"          "AppleShowAllFiles"
  print_pref "Finder show path bar"         "com.apple.finder"          "ShowPathbar"
  print_pref "Finder show status bar"       "com.apple.finder"          "ShowStatusBar"
  print_pref "Finder folders first"         "com.apple.finder"          "_FXSortFoldersFirst"

  print_pref "Show all extensions"          "NSGlobalDomain"            "AppleShowAllExtensions"
  print_pref "Key repeat"                   "NSGlobalDomain"            "KeyRepeat"
  print_pref "Initial key repeat"           "NSGlobalDomain"            "InitialKeyRepeat"

  print_pref "No .DS_Store on network"      "com.apple.desktopservices" "DSDontWriteNetworkStores"
  print_pref "No .DS_Store on USB"          "com.apple.desktopservices" "DSDontWriteUSBStores"

  print_pref "Screenshot location"          "com.apple.screencapture"   "location"
  print_pref "Screenshot type"              "com.apple.screencapture"   "type"

  print_pref "Require password after saver" "com.apple.screensaver"     "askForPassword"
  print_pref "Password delay"               "com.apple.screensaver"     "askForPasswordDelay"

  print_pref "Personalized ads"             "com.apple.AdLib"           "allowApplePersonalizedAdvertising"

  print_footer
}

print_tweaks_menu() {
  print_header
  row_bold "TWEAKS MENU"
  printf '\n'

  row2 " 1. Status" " 2. Backup current values"
  row2 " 3. Apply developer tweaks" " 4. Apply clean tweaks"
  row2 " 5. Apply fast tweaks" " 6. Apply workstation profile"
  row2 " 7. Apply all tweaks" " 8. Revert latest backup"
  row2 " 9. Show latest backup path" " 0. Exit"

  print_footer
  printf "${C_BLUE}Select option [0-9]: ${C_RESET}"
}

interactive_menu() {
  while true; do
    print_tweaks_menu
    read -r choice
    echo

    case "$choice" in
      1)
        show_status
        pause_enter
        ;;
      2)
        backup_selected
        pause_enter
        ;;
      3)
        backup_selected
        apply_dev_tweaks
        restart_affected_apps
        pause_enter
        ;;
      4)
        backup_selected
        apply_clean_tweaks
        restart_affected_apps
        pause_enter
        ;;
      5)
        backup_selected
        apply_fast_tweaks
        restart_affected_apps
        pause_enter
        ;;
      6)
        backup_selected
        apply_workstation_tweaks
        restart_affected_apps
        pause_enter
        ;;
      7)
        backup_selected
        apply_dev_tweaks
        apply_clean_tweaks
        apply_fast_tweaks
        restart_affected_apps
        pause_enter
        ;;
      8)
        revert_latest
        pause_enter
        ;;
      9)
        show_latest_backup
        pause_enter
        ;;
      0)
        ok "Exiting."
        break
        ;;
      *)
        err "Invalid option."
        pause_enter
        ;;
    esac
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      menu|status|backup|revert-latest|dev|clean|fast|workstation|all)
        COMMAND="$1"
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  ensure_backup_dir
  parse_args "$@"

  case "$COMMAND" in
    menu)
      interactive_menu
      ;;
    status)
      show_status
      ;;
    backup)
      backup_selected
      ;;
    revert-latest)
      revert_latest
      ;;
    dev)
      backup_selected
      apply_dev_tweaks
      restart_affected_apps
      ;;
    clean)
      backup_selected
      apply_clean_tweaks
      restart_affected_apps
      ;;
    fast)
      backup_selected
      apply_fast_tweaks
      restart_affected_apps
      ;;
    workstation)
      backup_selected
      apply_workstation_tweaks
      restart_affected_apps
      ;;
    all)
      backup_selected
      apply_dev_tweaks
      apply_clean_tweaks
      apply_fast_tweaks
      restart_affected_apps
      ;;
    *)
      err "Unknown command."
      usage
      exit 1
      ;;
  esac
}

main "$@"
