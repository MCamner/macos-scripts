#!/bin/zsh

set -u

# ============================================================
# MQLaunch v2 — Old School Utility
# ============================================================

APP_TITLE="MQLaunch v2"
APP_SUBTITLE="Old School Utility"

BASE_DIR="$HOME/macos-scripts"
AI_SCRIPT="$BASE_DIR/tools/cli/ai-mode.sh"
PROMPT_DIR="$BASE_DIR/ai-prompts"
REPO_URL="https://github.com/MCamner/macos-scripts"
MQ_SCRIPT="$BASE_DIR/terminal/launchers/mqlaunch.sh"
BACKUP_DIR="$BASE_DIR/backups"

BOX_INNER=88

# --- ANSI colors --------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_TITLE=$'\033[1;33m'
  C_ERR=$'\033[0;31m'
else
  C_RESET=''
  C_TITLE=''
  C_ERR=''
fi

# --- Helpers ------------------------------------------------
repeat_char() {
  local count="$1"
  local char="$2"
  printf '%*s' "$count" '' | tr ' ' "$char"
}

border() {
  printf "+%s+\n" "$(repeat_char "$BOX_INNER" "-")"
}

row() {
  local text="$1"
  printf "| %-*.*s |\n" "$BOX_INNER" "$BOX_INNER" "$text"
}

row3() {
  local c1="$1"
  local c2="$2"
  local c3="$3"
  row "$(printf '%-26s %-26s %-26s' "$c1" "$c2" "$c3")"
}

row2() {
  local c1="$1"
  local c2="$2"
  row "$(printf '%-40s %-40s' "$c1" "$c2")"
}

empty_row() {
  row ""
}

pause_enter() {
  echo
  read -r "?Press Enter to continue..."
}

set_terminal_title() {
  print -Pn "\e]0;${APP_TITLE} — ${APP_SUBTITLE}\a"
}

clear_screen() {
  if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
    tput clear
  else
    clear
  fi
  set_terminal_title
}

short_host() {
  hostname -s 2>/dev/null || hostname
}

print_header() {
  clear_screen
  border
  row "                                  ${APP_TITLE}"
  row "                               ${APP_SUBTITLE}"
  border
}

print_footer() {
  local now host user_name
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  host="$(short_host)"
  user_name="$USER"

  empty_row
  row "Host: ${host}   User: ${user_name}"
  row "Time: ${now}"
  border
}

open_app() {
  local app_name="$1"
  open -a "$app_name" >/dev/null 2>&1 || {
    echo "${C_ERR}Could not open:${C_RESET} $app_name"
    pause_enter
  }
}

open_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    open "$path"
  else
    echo "${C_ERR}Path not found:${C_RESET} $path"
    pause_enter
  fi
}

open_folder_screen() {
  local title="$1"
  local target="$2"
  local missing_label="$3"

  print_header
  row "$title"
  empty_row

  if [[ -d "$target" ]]; then
    row "Opening:"
    row " $target"
    print_footer
    open "$target"
  else
    row "$missing_label"
    row " $target"
    print_footer
    pause_enter
  fi
}

resolve_prompt_dir() {
  local candidate
  for candidate in "$HOME/macos-scripts/ai-prompts" "$PROMPT_DIR"; do
    if [[ -d "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

safe_run_ai() {
  local mode="$1"

  if [[ -x "$AI_SCRIPT" ]]; then
    "$AI_SCRIPT" "$mode"
  else
    echo "${C_ERR}AI script missing or not executable:${C_RESET}"
    echo "$AI_SCRIPT"
    pause_enter
  fi
}

# --- Actions ------------------------------------------------
show_network_info() {
  local wifi_ip eth_ip gateway dns
  wifi_ip="$(ipconfig getifaddr en0 2>/dev/null || echo "-")"
  eth_ip="$(ipconfig getifaddr en1 2>/dev/null || echo "-")"
  gateway="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
  dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3; exit}')"

  [[ -z "$gateway" ]] && gateway="-"
  [[ -z "$dns" ]] && dns="-"

  print_header
  row "NETWORK INFO"
  empty_row
  row "Wi-Fi (en0):     $wifi_ip"
  row "Ethernet (en1):  $eth_ip"
  row "Gateway:         $gateway"
  row "DNS:             $dns"
  print_footer
  pause_enter
}

lock_screen() {
  if [[ -x "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" ]]; then
    "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
  else
    osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}' >/dev/null 2>&1
  fi
}

sleep_display() {
  pmset displaysleepnow
}

restart_finder() {
  killall Finder >/dev/null 2>&1
}

show_date_time() {
  print_header
  row "DATE AND TIME"
  empty_row
  row "$(date '+%A %Y-%m-%d')"
  row "$(date '+%H:%M:%S')"
  print_footer
  pause_enter
}

open_repo_browser() {
  print_header
  row "OPEN REPO IN BROWSER"
  empty_row
  row "Opening:"
  row " $REPO_URL"
  print_footer
  open "$REPO_URL"
}

system_check() {
  local prompt_count="0"
  local resolved_prompt_dir=""
  resolved_prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"

  if [[ -n "$resolved_prompt_dir" ]]; then
    prompt_count="$(find "$resolved_prompt_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  fi

  print_header
  row "SYSTEM CHECK"
  empty_row

  if [[ -d "$BASE_DIR" ]]; then
    row "[OK]   Base dir found"
  else
    row "[FAIL] Base dir missing"
  fi

  if [[ -x "$AI_SCRIPT" ]]; then
    row "[OK]   ai-mode.sh executable"
  else
    row "[FAIL] ai-mode.sh missing/not executable"
  fi

  if [[ -n "$resolved_prompt_dir" ]]; then
    row "[OK]   Prompt dir found"
    row "       $resolved_prompt_dir"
  else
    row "[FAIL] Prompt dir missing"
  fi

  if command -v git >/dev/null 2>&1; then
    row "[OK]   git available"
  else
    row "[FAIL] git missing"
  fi

  if command -v open >/dev/null 2>&1; then
    row "[OK]   open command available"
  else
    row "[FAIL] open command missing"
  fi

  if command -v pbcopy >/dev/null 2>&1; then
    row "[OK]   pbcopy available"
  else
    row "[FAIL] pbcopy missing"
  fi

  row "Prompt files: $prompt_count"
  print_footer
  pause_enter
}

open_downloads_folder() {
  open_folder_screen "OPEN DOWNLOADS FOLDER" "$HOME/Downloads" "Downloads folder missing:"
}

open_home_folder() {
  open_folder_screen "OPEN HOME FOLDER" "$HOME" "Home folder missing:"
}

open_utilities_folder() {
  open_folder_screen "OPEN UTILITIES FOLDER" "/Applications/Utilities" "Utilities folder missing:"
}

open_applications_folder() {
  open_folder_screen "OPEN APPLICATIONS FOLDER" "/Applications" "Applications folder missing:"
}

open_ai_prompts_folder() {
  local target=""
  target="$(resolve_prompt_dir 2>/dev/null || true)"

  print_header
  row "OPEN AI PROMPTS FOLDER"
  empty_row

  if [[ -n "$target" ]]; then
    row "Opening:"
    row " $target"
    print_footer
    open "$target"
  else
    row "Prompt dir missing."
    row "Checked:"
    row " $HOME/macos-scripts/ai-prompts"
    row " $PROMPT_DIR"
    print_footer
    pause_enter
  fi
}

show_prompt_files() {
  local resolved_prompt_dir=""
  local -a files
  local f
  local shown=0

  resolved_prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"

  print_header
  row "PROMPT FILES"
  empty_row

  if [[ -z "$resolved_prompt_dir" ]]; then
    row "Prompt dir missing."
    row "Checked:"
    row " $HOME/macos-scripts/ai-prompts"
    row " $PROMPT_DIR"
  else
    files=("$resolved_prompt_dir"/*(.N))
    if (( ${#files[@]} == 0 )); then
      row "No prompt files found."
      row "Folder:"
      row " $resolved_prompt_dir"
    else
      for f in "${files[@]}"; do
        row " - ${f:t}"
        ((shown++))
        if (( shown >= 20 && ${#files[@]} > 20 )); then
          row " ..."
          break
        fi
      done
      empty_row
      row "Total files: ${#files[@]}"
      row "Folder: $resolved_prompt_dir"
    fi
  fi

  print_footer
  pause_enter
}

edit_mqlaunch() {
  ${EDITOR:-nano} "$MQ_SCRIPT"
}

backup_prompts() {
  local resolved_prompt_dir=""
  local stamp backup_file

  resolved_prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"

  if [[ -z "$resolved_prompt_dir" ]]; then
    echo "${C_ERR}Prompt dir missing.${C_RESET}"
    pause_enter
    return
  fi

  if ! command -v zip >/dev/null 2>&1; then
    echo "${C_ERR}zip is missing on this system.${C_RESET}"
    pause_enter
    return
  fi

  mkdir -p "$BACKUP_DIR"
  stamp="$(date '+%Y%m%d-%H%M%S')"
  backup_file="$BACKUP_DIR/ai-prompts-$stamp.zip"

  (
    cd "$(dirname "$resolved_prompt_dir")" || exit 1
    zip -rq "$backup_file" "$(basename "$resolved_prompt_dir")"
  )

  print_header
  row "PROMPT BACKUP"
  empty_row

  if [[ -f "$backup_file" ]]; then
    row "Backup created successfully."
    row "File:"
    row " $backup_file"
  else
    row "Backup failed."
  fi

  print_footer
  pause_enter
}

# --- Menus --------------------------------------------------
print_main_menu() {
  print_header
  row "MAIN MENU"
  empty_row

  row "APPS"
  row3 " 1. Finder" " 2. Safari" " 3. Google Chrome"
  row3 " 4. Spotify" " 5. Xcode" " 6. System Settings"
  row3 " 7. Activity Monitor" "" ""

  empty_row
  row "SYSTEM / CONTROL"
  row3 " 8. Downloads folder" " 9. Home folder" "10. Show IP + network"
  row3 "11. Exit launcher" "12. Lock screen" "13. Sleep display"

  empty_row
  row "TOOLS"
  row3 "14. Utilities folder" "15. Applications folder" "16. Restart Finder"
  row3 "17. Show date and time" "18. Open repo in browser" "19. Run system check"

  empty_row
  row "DEV / PROMPTS"
  row3 "20. AI Modes" "21. Open AI Prompts folder" "22. Show prompt files"
  row3 "23. Edit mqlaunch" "24. Backup prompts" ""

  print_footer
  printf "${C_TITLE}Select option [1-24]: ${C_RESET}"
}

print_ai_menu() {
  print_header
  row "AI MODES"
  empty_row

  row2 " 1. Auto Mode" " 2. Atlas One"
  row2 " 3. Atlas Router" " 4. Decision"
  row2 " 5. Research" " 6. Root Cause"
  row2 " 7. Problem Solving" " 8. Prompt Debugger"
  row2 " 9. AI Menu" " 0. Back"

  print_footer
  printf "${C_TITLE}Select AI mode [0-9]: ${C_RESET}"
}

ai_menu_loop() {
  local choice

  while true; do
    print_ai_menu
    read -r choice
    echo

    case "$choice" in
      1) safe_run_ai auto ;;
      2) safe_run_ai one ;;
      3) safe_run_ai atlas ;;
      4) safe_run_ai decide ;;
      5) safe_run_ai research ;;
      6) safe_run_ai root ;;
      7) safe_run_ai solve ;;
      8) safe_run_ai pdebug ;;
      9) safe_run_ai menu ;;
      0) break ;;
      *) echo "${C_ERR}Invalid AI selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

main_loop() {
  local choice

  while true; do
    print_main_menu
    read -r choice
    echo

    case "$choice" in
      1) open_app "Finder" ;;
      2) open_app "Safari" ;;
      3) open_app "Google Chrome" ;;
      4) open_app "Spotify" ;;
      5) open_app "Xcode" ;;
      6) open_app "System Settings" ;;
      7) open_app "Activity Monitor" ;;
      8) open_downloads_folder ;;
      9) open_home_folder ;;
      10) show_network_info ;;
      11) echo "Exiting ${APP_TITLE}..."; exit 0 ;;
      12) lock_screen ;;
      13) sleep_display ;;
      14) open_utilities_folder ;;
      15) open_applications_folder ;;
      16) restart_finder ;;
      17) show_date_time ;;
      18) open_repo_browser ;;
      19) system_check ;;
      20) ai_menu_loop ;;
      21) open_ai_prompts_folder ;;
      22) show_prompt_files ;;
      23) edit_mqlaunch ;;
      24) backup_prompts ;;
      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

show_help() {
  cat <<EOH
MQLaunch v2 — Old School Utility

Usage:
  mqlaunch                Open main menu
  mqlaunch ai             Open AI submenu

Direct commands:
  finder | safari | chrome | spotify | xcode
  settings | monitor
  downloads | home | utilities | applications
  ip | lock | sleep | restart-finder | date
  repo | check | ai
  prompts | prompt-files | edit | backup-prompts
  auto | one | atlas | decide | research | root | solve | pdebug | menu

Examples:
  mqlaunch
  mqlaunch chrome
  mqlaunch ai
  mqlaunch prompts
  mqlaunch edit
  mqlaunch backup-prompts
EOH
}

run_arg_command() {
  local cmd="${1:l}"

  case "$cmd" in
    finder) open_app "Finder" ;;
    safari) open_app "Safari" ;;
    chrome) open_app "Google Chrome" ;;
    spotify) open_app "Spotify" ;;
    xcode) open_app "Xcode" ;;
    settings) open_app "System Settings" ;;
    monitor) open_app "Activity Monitor" ;;
    downloads) open_downloads_folder ;;
    home) open_home_folder ;;
    utilities) open_utilities_folder ;;
    applications|apps) open_applications_folder ;;
    ip|network) show_network_info ;;
    lock) lock_screen ;;
    sleep) sleep_display ;;
    restart-finder|finder-restart) restart_finder ;;
    date|time) show_date_time ;;
    repo) open_repo_browser ;;
    check|health) system_check ;;
    ai) ai_menu_loop ;;
    prompts|prompt-folder) open_ai_prompts_folder ;;
    prompt-files|files) show_prompt_files ;;
    edit|edit-mqlaunch) edit_mqlaunch ;;
    backup-prompts|backup) backup_prompts ;;
    auto|one|atlas|decide|research|root|solve|pdebug|menu) safe_run_ai "$cmd" ;;
    help|-h|--help) show_help ;;
    *)
      echo "${C_ERR}Unknown command:${C_RESET} $1"
      echo
      show_help
      exit 1
      ;;
  esac
}

# --- Entry --------------------------------------------------
if [[ $# -gt 0 ]]; then
  run_arg_command "$1"
else
  main_loop
fi
