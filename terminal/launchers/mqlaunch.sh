#!/bin/zsh

set -u

APP_TERM_TITLE="mqlaunch"
REFRESH_DELAY=0.2
REPO_URL="https://github.com/MCamner/macos-scripts"

# Colors
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_BLUE=$'\033[34m'
C_CYAN=$'\033[36m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_MAGENTA=$'\033[35m'

clear_screen() {
  clear
}

set_terminal_title() {
  print -Pn "\e]0;${APP_TERM_TITLE}\a"
}

line() {
  echo "${C_BLUE}========================================================${C_RESET}"
}

print_header() {
  line
  echo "${C_BOLD}${C_CYAN}                    MQ LAUNCHER (macOS)${C_RESET}"
  line
  echo "${C_GREEN}  1)${C_RESET} Finder"
  echo "${C_GREEN}  2)${C_RESET} Safari"
  echo "${C_GREEN}  3)${C_RESET} Google Chrome"
  echo "${C_GREEN}  4)${C_RESET} Spotify"
  echo "${C_GREEN}  5)${C_RESET} Xcode"
  echo "${C_GREEN}  6)${C_RESET} System Settings"
  echo "${C_GREEN}  7)${C_RESET} Activity Monitor"
  echo "${C_GREEN}  8)${C_RESET} Downloads folder"
  echo "${C_GREEN}  9)${C_RESET} Home folder"
  echo "${C_GREEN} 10)${C_RESET} Show IP + network info"
  echo "${C_GREEN} 11)${C_RESET} Exit launcher"
  echo
  echo "${C_BOLD}${C_MAGENTA} Extra${C_RESET}"
  echo "${C_YELLOW} 12)${C_RESET} Lock screen"
  echo "${C_YELLOW} 13)${C_RESET} Sleep display"
  echo "${C_YELLOW} 14)${C_RESET} Open Utilities folder"
  echo "${C_YELLOW} 15)${C_RESET} Open Applications folder"
  echo "${C_YELLOW} 16)${C_RESET} Restart Finder"
  echo "${C_YELLOW} 17)${C_RESET} Show date and time"
  echo "${C_YELLOW} 18)${C_RESET} Open repo in browser"
  echo "${C_YELLOW} 19)${C_RESET} Run system check"
  line
}

print_footer() {
  echo
  echo "${C_BOLD}Choose a number and press Enter.${C_RESET}"
  echo
}

pause_brief() {
  sleep "$REFRESH_DELAY"
}

pause_enter() {
  read -r "?Press Enter to continue..."
}

app_exists() {
  [ -d "/Applications/${1}.app" ] || \
  [ -d "/System/Applications/${1}.app" ] || \
  [ -d "/System/Library/CoreServices/${1}.app" ]
}

open_app() {
  local app_name="$1"

  if open -a "$app_name" 2>/dev/null; then
    return 0
  fi

  echo "${C_RED}App not found:${C_RESET} $app_name"
  pause_enter
}

open_code() {
  if open -b com.microsoft.VSCode 2>/dev/null; then
    return 0
  fi

  if open -a "Visual Studio Code" 2>/dev/null; then
    return 0
  fi

  if command -v code >/dev/null 2>&1; then
    code . >/dev/null 2>&1
    return 0
  fi

  echo "${C_RED}VS Code not found:${C_RESET} install it or make sure the app/CLI is available."
  pause_enter
}

open_path() {
  local target_path="$1"
  if [ -e "$target_path" ]; then
    open "$target_path"
  else
    echo "${C_RED}Path not found:${C_RESET} $target_path"
    pause_enter
  fi
}

show_network_info() {
  clear_screen
  line
  echo "${C_BOLD}${C_CYAN}                 NETWORK / IP INFORMATION${C_RESET}"
  line
  echo

  echo "${C_BOLD}Local hostname:${C_RESET}"
  scutil --get LocalHostName 2>/dev/null || echo "Unavailable"
  echo

  echo "${C_BOLD}Computer name:${C_RESET}"
  scutil --get ComputerName 2>/dev/null || echo "Unavailable"
  echo

  echo "${C_BOLD}Primary IP addresses:${C_RESET}"
  ifconfig | awk '
    /^[a-z0-9]/ { iface=$1; sub(":", "", iface) }
    /inet / && $2 != "127.0.0.1" { print iface ": " $2 }
  '
  echo

  echo "${C_BOLD}Wi-Fi info:${C_RESET}"
  local airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  if [ -x "$airport_bin" ]; then
    "$airport_bin" -I 2>/dev/null | grep -E " SSID|BSSID|agrCtlRSSI|channel"
  else
    echo "Wi-Fi details unavailable."
  fi

  echo
  pause_enter
}

show_datetime() {
  clear_screen
  line
  echo "${C_BOLD}${C_CYAN}                    DATE AND TIME${C_RESET}"
  line
  echo
  date
  echo
  pause_enter
}

open_repo() {
  open "$REPO_URL"
}

run_system_check() {
  if command -v system-check >/dev/null 2>&1; then
    system-check
  else
    echo "${C_RED}system-check not found:${C_RESET} run ./install.sh first."
    pause_enter
  fi
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
      5) open_app "Xcode" ;;
      6) open_app "System Settings" ;;
      7) open_app "Activity Monitor" ;;
      8) open_path "$HOME/Downloads" ;;
      9) open_path "$HOME" ;;
      10) show_network_info ;;
      11) echo "${C_GREEN}Exiting mqlaunch...${C_RESET}"; exit 0 ;;
      12) lock_screen ;;
      13) sleep_display ;;
      14) open_path "/Applications/Utilities" ;;
      15) open_path "/Applications" ;;
      16) restart_finder ;;
      17) show_datetime ;;
      18) open_repo ;;
      19) run_system_check ;;
      *) echo "${C_RED}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac

    bring_terminal_front
    pause_brief
  done
}

main_loop
