#!/bin/zsh

set -u

APP_TERM_TITLE="mqlaunch"
REFRESH_DELAY=0.2

clear_screen() { clear; }

print_header() { cat <<'MENU'
========================================================
                    MQ LAUNCHER (macOS)
========================================================
  1) Finder
  2) Safari
  3) Google Chrome
  4) Spotify
  5) Visual Studio Code
  6) System Settings
  7) Activity Monitor
  8) Downloads folder
  9) Home folder
 10) Show IP + network info
 11) Exit launcher

 Extra:
 12) Lock screen
 13) Sleep display
 14) Open Utilities folder
 15) Open Applications folder
 16) Restart Finder
========================================================
MENU
}

print_footer() {
  echo
  echo "Choose a number and press Enter."
  echo
}

pause_brief() { sleep "$REFRESH_DELAY"; }

app_exists() {
  [ -d "/Applications/${1}.app" ] || [ -d "/System/Applications/${1}.app" ]
}

open_app() {
  local app_name="$1"
  if app_exists "$app_name"; then
    open -a "$app_name"
  else
    echo "App not found: $app_name"
    read -r "?Press Enter..."
  fi
}

open_path() {
  local target_path="$1"
  if [ -e "$target_path" ]; then
    open "$target_path"
  else
    echo "Path not found: $target_path"
    read -r "?Press Enter..."
  fi
}

show_network_info() {
  clear_screen
  echo "========================================================"
  echo "                 NETWORK / IP INFORMATION"
  echo "========================================================"
  echo

  echo "Local hostname:"
  scutil --get LocalHostName 2>/dev/null || echo "Unavailable"
  echo

  echo "Computer name:"
  scutil --get ComputerName 2>/dev/null || echo "Unavailable"
  echo

  echo "Primary IP addresses:"
  ifconfig | awk '
    /^[a-z0-9]/ { iface=$1; sub(":", "", iface) }
    /inet / && $2 != "127.0.0.1" { print iface ": " $2 }
  '
  echo

  echo "Wi-Fi info:"
  local airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  if [ -x "$airport_bin" ]; then
    "$airport_bin" -I 2>/dev/null | grep -E " SSID|BSSID|agrCtlRSSI|channel"
  else
    echo "Wi-Fi details unavailable."
  fi

  echo
  read -r "?Press Enter to return..."
}

lock_screen() {
  /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
}

sleep_display() {
  pmset displaysleepnow
}

restart_finder() {
  killall Finder 2>/dev/null
  pause_brief
}

bring_terminal_front() {
  osascript >/dev/null 2>&1 <<'APPLESCRIPT'
tell application "Terminal" to activate
APPLESCRIPT
}

set_terminal_title() {
  print -Pn "\e]0;${APP_TERM_TITLE}\a"
}

main_loop() {
  while true; do
    set_terminal_title
    clear_screen
    print_header
    print_footer
    read -r "?Selection: " choice
    echo

    case "$choice" in
      1) open_app "Finder" ;;
      2) open_app "Safari" ;;
      3) open_app "Google Chrome" ;;
      4) open_app "Spotify" ;;
      5) open_app "Visual Studio Code" ;;
      6) open_app "System Settings" ;;
      7) open_app "Activity Monitor" ;;
      8) open_path "$HOME/Downloads" ;;
      9) open_path "$HOME" ;;
      10) show_network_info ;;
      11) echo "Exiting mqlaunch..."; exit 0 ;;
      12) lock_screen ;;
      13) sleep_display ;;
      14) open_path "/Applications/Utilities" ;;
      15) open_path "/Applications" ;;
      16) restart_finder ;;
      *) echo "Invalid selection: $choice"; read -r "?Press Enter..." ;;
    esac

    bring_terminal_front
    pause_brief
  done
}

main_loop
