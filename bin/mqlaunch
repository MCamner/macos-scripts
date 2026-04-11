#!/bin/zsh

set -u

# ============================================================
# MQLAUNCH — Branded Neon Command Surface
# Adds:
# - MAIN MENU in bold
# - Author line in header
# - Git Launch + Net Launch in Dev / Prompts
# ============================================================

APP_TITLE="MQLAUNCH"
APP_SUBTITLE="Branded Neon Command Surface"
APP_AUTHOR="Author Mattias Camner"

BASE_DIR="$HOME/macos-scripts"

# Performance bridge
if [[ -f "$BASE_DIR/terminal/bridges/performance-bridge.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/bridges/performance-bridge.sh"
fi

# Dev bridge
if [[ -f "$BASE_DIR/terminal/bridges/dev-bridge.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/bridges/dev-bridge.sh"
fi

# Tools bridge
if [[ -f "$BASE_DIR/terminal/bridges/tools-bridge.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/bridges/tools-bridge.sh"
fi
AI_SCRIPT="$BASE_DIR/tools/cli/ai-mode.sh"
PROMPT_DIR="$BASE_DIR/ai-prompts"
REPO_URL="https://github.com/MCamner/macos-scripts"
MQ_SCRIPT="$BASE_DIR/terminal/launchers/mqlaunch.sh"
BACKUP_DIR="$BASE_DIR/backups"
BIN_LINK="$HOME/bin/mqlaunch"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
DASHBOARD_V71="$BASE_DIR/ui/ascii/mqlaunch-dashboard-v7.1.sh"

TERMINAL_GUIDE_HTML="$BASE_DIR/tools/mac terminal_guide/mac-terminal-guide.html"
TERMINAL_GUIDE_URL="https://mcamner.github.io/macos-scripts/"

if [[ -f "$UI_LIB" ]]; then
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

BOX_INNER=88

print_header() {
  clear
  if [[ -f "$DASHBOARD_V71" ]]; then
    bash "$DASHBOARD_V71" "$APP_TITLE" "$APP_SUBTITLE" "ONLINE"
  else
    echo "$APP_TITLE — $APP_SUBTITLE"
    printf '%s
' "----------------------------------------------------------------------------------------"
  fi
  echo
}

# --- Shared UI ------------------------------------------------
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

resolve_ai_status() {
  if [[ -x "$AI_SCRIPT" ]]; then
    print -r -- "OK"
  elif [[ -e "$AI_SCRIPT" ]]; then
    print -r -- "FOUND_NOT_EXECUTABLE"
  else
    print -r -- "MISSING"
  fi
}

safe_run_ai() {
  local mode="$1"

  if [[ -x "$AI_SCRIPT" ]]; then
    "$AI_SCRIPT" "$mode"
  else
    print_header
    row "AI BACKEND STATUS"
    empty_row
    if [[ -e "$AI_SCRIPT" ]]; then
      row "ai-mode.sh found but not executable."
      row "Run:"
      row " chmod +x $AI_SCRIPT"
    else
      row "ai-mode.sh missing."
      row "Expected:"
      row " $AI_SCRIPT"
    fi
    print_footer
    pause_enter
  fi
}

run_git_screen() {
  local title="$1"
  local cmd="$2"

  print_header
  row "$title"
  empty_row
  row "Repo:"
  row " $BASE_DIR"
  empty_row

  (
    cd "$BASE_DIR" 2>/dev/null || exit 1
    eval "$cmd"
  )

  echo
  print_footer
  pause_enter
}

copy_network_info() {
  local wifi_ip gateway dns payload
  wifi_ip="$(ipconfig getifaddr en0 2>/dev/null || echo "-")"
  gateway="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
  dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3; exit}')"

  [[ -z "$gateway" ]] && gateway="-"
  [[ -z "$dns" ]] && dns="-"

  payload="Wi-Fi: $wifi_ip
Gateway: $gateway
DNS: $dns"

  if command -v pbcopy >/dev/null 2>&1; then
    print -r -- "$payload" | pbcopy
    print_header
    row "COPY NETWORK INFO"
    empty_row
    row "Copied to clipboard:"
    row " Wi-Fi: $wifi_ip"
    row " Gateway: $gateway"
    row " DNS: $dns"
    print_footer
    pause_enter
  else
    echo "${C_ERR}pbcopy missing.${C_RESET}"
    pause_enter
  fi
}

open_network_settings() {
  print_header
  row "OPEN NETWORK SETTINGS"
  empty_row
  row "Opening System Settings → Network"
  print_footer
  open "x-apple.systempreferences:com.apple.Network-Settings.extension"
}

ping_test() {
  print_header
  row "PING TEST"
  empty_row
  row "Target: 1.1.1.1"
  empty_row
  ping -c 4 1.1.1.1
  echo
  print_footer
  pause_enter
}

show_dns_gateway() {
  local gateway dns
  gateway="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
  dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3; exit}')"
  [[ -z "$gateway" ]] && gateway="-"
  [[ -z "$dns" ]] && dns="-"

  print_header
  row "DNS + GATEWAY"
  empty_row
  row "Gateway: $gateway"
  row "DNS:     $dns"
  print_footer
  pause_enter
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

open_terminal_guide() {
  local html="$BASE_DIR/docs/mac-terminal-guide.html"
  local readme="$BASE_DIR/tools/mac-terminal-guide/README.md"

  if [[ -f "$html" ]]; then
    open "$html"
  elif [[ -f "$readme" ]]; then
    open "$readme"
  else
    echo "${C_ERR}No terminal guide file found.${C_RESET}"
    pause_enter
    return 1
  fi
}

system_check() {
  local prompt_count="0"
  local resolved_prompt_dir=""
  local ai_status=""
  local link_target=""
  local active_cmd=""

  resolved_prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"
  ai_status="$(resolve_ai_status)"

  if [[ -n "$resolved_prompt_dir" ]]; then
    prompt_count="$(find "$resolved_prompt_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  fi

  if [[ -L "$BIN_LINK" ]]; then
    link_target="$(readlink "$BIN_LINK" 2>/dev/null || true)"
  fi

  active_cmd="$(command -v mqlaunch 2>/dev/null || true)"

  print_header
  row "SYSTEM CHECK"
  empty_row

  if [[ -d "$BASE_DIR" ]]; then
    row "[OK]   Base dir found"
  else
    row "[FAIL] Base dir missing"
  fi

  if [[ -x "$MQ_SCRIPT" ]]; then
    row "[OK]   mqlaunch.sh executable"
  elif [[ -e "$MQ_SCRIPT" ]]; then
    row "[FAIL] mqlaunch.sh found but not executable"
  else
    row "[FAIL] mqlaunch.sh missing"
  fi

  case "$ai_status" in
    OK)
      row "[OK]   AI backend executable"
      ;;
    FOUND_NOT_EXECUTABLE)
      row "[FAIL] AI backend found but not executable"
      ;;
    MISSING)
      row "[FAIL] AI backend missing"
      ;;
  esac

  if [[ -n "$resolved_prompt_dir" ]]; then
    row "[OK]   Prompt dir found"
    row "       $resolved_prompt_dir"
  else
    row "[FAIL] Prompt dir missing"
  fi

  if [[ -f "$TERMINAL_GUIDE_HTML" ]]; then
    row "[OK]   Terminal guide local file found"
  else
    row "[FAIL] Terminal guide local file missing"
  fi

  if [[ -L "$BIN_LINK" ]]; then
    if [[ "$link_target" == "$MQ_SCRIPT" ]]; then
      row "[OK]   ~/bin/mqlaunch symlink correct"
    else
      row "[FAIL] ~/bin/mqlaunch points elsewhere"
      row "       $link_target"
    fi
  elif [[ -e "$BIN_LINK" ]]; then
    row "[FAIL] ~/bin/mqlaunch exists but is not a symlink"
  else
    row "[FAIL] ~/bin/mqlaunch missing"
  fi

  if [[ -n "$active_cmd" ]]; then
    row "[OK]   mqlaunch command resolves"
    row "       $active_cmd"
  else
    row "[FAIL] mqlaunch command not found in PATH"
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

open_base_dir() {
  open_folder_screen "OPEN MACOS-SCRIPTS FOLDER" "$BASE_DIR" "Base dir missing:"
}

open_launcher_folder() {
  open_folder_screen "OPEN LAUNCHER FOLDER" "$BASE_DIR/terminal/launchers" "Launcher folder missing:"
}

open_tweaks_menu() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" menu
}

show_tweaks_status() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" status
}

run_tweaks_workstation() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" workstation
}

run_tweaks_dev() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" dev
}

run_tweaks_clean() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" clean
}

run_tweaks_fast() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" fast
}

run_tweaks_all() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" all
}

revert_tweaks_latest() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" revert-latest
}

backup_mqlaunch() {
  local stamp backup_file
  stamp="$(date '+%Y%m%d-%H%M%S')"
  launcher_backup_dir="$BACKUP_DIR/launchers"
  backup_file="$launcher_backup_dir/mqlaunch-$stamp.sh.bak"

  mkdir -p "$launcher_backup_dir"

  print_header
  row "BACKUP MQLAUNCH"
  empty_row

  if [[ -f "$MQ_SCRIPT" ]]; then
    cp "$MQ_SCRIPT" "$backup_file"
    chmod +x "$backup_file" 2>/dev/null || true

    row "Backup created successfully."
    row "File:"
    row " $backup_file"
  else
    row "mqlaunch.sh not found:"
    row " $MQ_SCRIPT"
  fi

  print_footer
  pause_enter
}

theme_cmd() {
  local theme_script="$BASE_DIR/terminal/themes/mq-zsh-theme-switcher.sh"
  local cmd="${1:-current}"
  shift || true

  if [[ -x "$theme_script" ]]; then
    bash "$theme_script" "$cmd" "$@"
  elif [[ -f "$theme_script" ]]; then
    chmod +x "$theme_script" 2>/dev/null || true
    bash "$theme_script" "$cmd" "$@"
  else
    print_header
    row "THEME SWITCHER"
    empty_row
    row "Theme switcher script missing:"
    row " $theme_script"
    print_footer
    pause_enter
    return 1
  fi
}

print_themes_menu() {
  print_header
  row "THEMES"
  empty_row

  row2 " 1. Current theme" " 2. Apply amber"
  row2 " 3. Apply green" " 4. Apply minimal"
  row2 " 5. Apply ice" " 6. Reset theme"
  row2 " 0. Back" ""

  print_footer
  printf "${C_TITLE}Select theme option [0-6]: ${C_RESET}"
}

themes_menu_loop() {
  local choice

  while true; do
    clear
    if [[ -f "$DASHBOARD_V71" ]]; then
      bash "$DASHBOARD_V71" "MQLAUNCH" "Branded Neon Command Surface" "ONLINE"
      echo
    fi
    print_themes_menu
    read -r choice
    echo

    case "$choice" in
      1) theme_cmd current; pause_enter ;;
      2) theme_cmd apply amber ;;
      3) theme_cmd apply green ;;
      4) theme_cmd apply minimal ;;
      5) theme_cmd apply ice ;;
      6) theme_cmd reset ;;
      0) break ;;
      *) echo "${C_ERR}Invalid theme selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

open_git_menu() {
  local git_script="$BASE_DIR/terminal/menus/mq-git-menu.sh"
  [[ -f "$git_script" ]] && bash "$git_script" || echo "Git menu not found."
}

open_release_menu() {
  local release_menu="$BASE_DIR/terminal/menus/mq-release-menu.sh"
  if [[ -x "$release_menu" ]]; then
    "$release_menu"
  else
    echo "Release menu not found: $release_menu"
  fi
}

open_tools_menu() {
  local tools_script="$BASE_DIR/terminal/menus/mq-tools-menu.sh"

  if [[ -x "$tools_script" ]]; then
    bash "$tools_script" menu
  elif [[ -f "$tools_script" ]]; then
    chmod +x "$tools_script" 2>/dev/null || true
    bash "$tools_script" menu
  else
    print_header
    row "TOOLS MENU"
    empty_row
    row "Tools menu script missing:"
    row " $tools_script"
    print_footer
    pause_enter
  fi
}

get_repo_version() {
  local version_file="$BASE_DIR/VERSION"

  if [[ -f "$version_file" ]]; then
    head -n 1 "$version_file"
  else
    echo "unknown"
  fi
}

show_version_info() {
  print_header
  row_bold "VERSION INFO"
  empty_row

  local version
  version="$(get_repo_version)"

  row "Project:        macos-scripts"
  row "Version:        $version"
  row "Release stage:  baseline"
  row "Shell:          zsh"
  row "Project root:   $BASE_DIR"
  row "Legacy:         $BASE_DIR/terminal/launchers/mqlaunch.sh"
  row "V1:             $BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"

  print_footer
  pause_enter
}

run_self_check() {
  print_header
  row_bold "SELF-CHECK"
  empty_row

  local check_script="$BASE_DIR/tools/scripts/test-all.sh"

  row "Running smoke checks..."
  empty_row

  if [[ ! -x "$check_script" ]]; then
    echo "${C_ERR}Missing or non-executable:${C_RESET} $check_script"
    print_footer
    pause_enter
    return 1
  fi

  "$check_script"
  local rc=$?

  echo
  if [[ $rc -eq 0 ]]; then
    echo "${C_OK}All smoke checks passed.${C_RESET}"
  else
    echo "${C_ERR}Smoke checks failed.${C_RESET}"
  fi

  print_footer
  pause_enter
  return $rc
}

run_debug_bundle() {
  print_header
  row_bold "DEBUG BUNDLE"
  empty_row

  local bundle_script="$BASE_DIR/tools/scripts/create-debug-bundle.sh"

  if [[ ! -x "$bundle_script" ]]; then
    echo "${C_ERR}Missing or non-executable:${C_RESET} $bundle_script"
    print_footer
    pause_enter
    return 1
  fi

  local outfile
  outfile="$("$bundle_script")"
  local rc=$?

  echo
  if [[ $rc -eq 0 ]]; then
    echo "${C_OK}Debug bundle created:${C_RESET}"
    echo " $outfile"
    [[ -f "$outfile" ]] && open -R "$outfile" 2>/dev/null || true
  else
    echo "${C_ERR}Debug bundle failed.${C_RESET}"
  fi

  print_footer
  pause_enter
  return $rc
}

show_release_notes() {
  print_header
  row_bold "RELEASE NOTES"
  empty_row

  local changelog="$BASE_DIR/CHANGELOG.md"

  if [[ ! -f "$changelog" ]]; then
    echo "${C_ERR}Missing:${C_RESET} $changelog"
    print_footer
    pause_enter
    return 1
  fi

  if command -v bat >/dev/null 2>&1; then
    bat --style=plain --paging=never "$changelog" | head -n 80
  else
    head -n 80 "$changelog"
  fi

  print_footer
  pause_enter
}

run_mqlogin() {
  local login_script="$BASE_DIR/automation/login/mqlogin.sh"

  if [[ ! -x "$login_script" ]]; then
    print_header
    row_bold "LOGIN BOOT"
    empty_row
    row "Missing or non-executable:"
    row " $login_script"
    row "Run:"
    row " chmod +x $login_script"
    print_footer
    pause_enter
    return 1
  fi

  "$login_script" "$@"
}

show_about_dashboard() {
  print_header
  row_bold "ABOUT / STATUS"
  empty_row

  local version_file="$BASE_DIR/VERSION"
  local version="unknown"
  local repo_state="unknown"
  local smoke_status="unknown"
  local latest_bundle="none"
  local guide_html="$BASE_DIR/docs/mac-terminal-guide.html"
  local legacy="$BASE_DIR/terminal/launchers/mqlaunch.sh"
  local v1="$BASE_DIR/terminal/mqlaunch-v1/mqlaunch.sh"
  local bundle_dir="$BASE_DIR/backups/debug-bundles"
  local test_script="$BASE_DIR/tools/scripts/test-all.sh"

  [[ -f "$version_file" ]] && version="$(head -n 1 "$version_file")"

  if git -C "$BASE_DIR" diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
    repo_state="clean"
  else
    repo_state="dirty"
  fi

  if [[ -x "$test_script" ]]; then
    if "$test_script" >/dev/null 2>&1; then
      smoke_status="PASS"
    else
      smoke_status="FAIL"
    fi
  else
    smoke_status="missing"
  fi

  if [[ -d "$bundle_dir" ]]; then
    latest_bundle="$(ls -1t "$bundle_dir" 2>/dev/null | head -n 1)"
    [[ -z "$latest_bundle" ]] && latest_bundle="none"
  fi

  row "Project:        macos-scripts"
  row "Version:        $version"
  row "Release stage:  baseline"
  row "Repo state:     $repo_state"
  row "Smoke tests:    $smoke_status"
  row "Guide HTML:     $guide_html"
  row "Legacy:         $legacy"
  row "V1:             $v1"
  row "Latest bundle:  $latest_bundle"
  row "Modules:        perf / dev / tools"

  print_footer
  pause_enter
}

show_command_index() {
  print_header
  row_bold "COMMAND INDEX"
  empty_row

  row "CORE"
  row " mqlaunch              Open main menu"
  row " mqlaunch help         Show help"
  row " mqlaunch commands     Show command index"

  empty_row
  row "WORKFLOWS"
  row " mqlaunch perf         Performance module"
  row " mqlaunch dev          Dev module"
  row " mqlaunch git          Alias for Dev"
  row " mqlaunch tools        Tools module"
  row " mqlaunch release      Open Release Menu"
  row " mqlaunch login        Start session boot"
  row " mqlaunch login menu   Session boot + full menu"
  row " mqlaunch login about  Session boot + about screen"
  row " mqlaunch login check  Session boot + self-check"

  empty_row
  row "STATUS / SUPPORT"
  row " mqlaunch about        About / status dashboard"
  row " mqlaunch version      Version information"
  row " mqlaunch notes        Release notes / changelog"
  row " mqlaunch check        Run self-check"
  row " mqlaunch bundle       Create debug bundle"

  empty_row
  row "UTILITY"
  row " mqlaunch repo         Open repo root"
  row " mqlaunch guide        Open terminal guide"

  empty_row
  row "ALIASES"
  row " mqlaunch health       Alias for check"
  row " mqlaunch support      Alias for bundle"
  row " mqlaunch changelog    Alias for notes"
  row " mqlaunch dashboard    Alias for about"
  row " mqlaunch index        Alias for commands"
  row " mqlaunch palette      Alias for commands"

  print_footer
  pause_enter
}

# --- Menus --------------------------------------------------
print_main_menu() {
  print_header
  row_bold "MAIN MENU"
  empty_row

  row "APPS"
  row3 " 1. Finder" " 2. Safari" " 3. Google Chrome"
  row3 " 4. Spotify" " 5. Xcode" " 6. System Settings"
  row3 " 7. Activity Monitor" "" ""

  empty_row
  row "SYSTEM / CONTROL"
  row3 " 8. Downloads folder" " 9. Home folder" "10. Show IP + network"
  row3 "12. Lock screen" "13. Sleep display" ""

  empty_row
  row "QUICK ACTIONS"
  row3 "14. Utilities folder" "15. Applications folder" "16. Restart Finder"
  row3 "17. Show date and time" "18. Open repo in browser" "19. Run system check"

  empty_row
  row "MENUS"
  row3 "20. AI Modes" "21. Dev / Prompts" "22. Tweaks"

  empty_row
  row "WORKFLOWS"
  row2 "23. Performance" "24. Dev"
  row2 "23. Performance" "24. Dev"
  row2 "25. Tools" "26. Version"
  row2 "27. Self-check" "28. Debug bundle"
  row2 "29. Release notes" "30. About / Status"
  row "31. Command index"

  print_main_footer
  printf "${C_TITLE}Select option [1-10,12-31,X]: ${C_RESET}"
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

print_dev_menu() {
  print_header
  row "DEV / PROMPTS"
  empty_row

  row2 " 1. Open AI Prompts folder" " 2. Show prompt files"
  row2 " 3. Edit mqlaunch" " 4. Backup prompts"
  row2 " 5. Backup mqlaunch" " 6. Open macos-scripts folder"
  row2 " 7. Open launcher folder" " 8. Open mac terminal guide"
  row2 " 9. Git Launch" "10. Net Launch"
  row2 "11. Themes" "12. Tools Menu"
  row2 " 0. Back" ""

  print_footer
  printf "${C_TITLE}Select dev option [0-12]: ${C_RESET}"
}

print_git_menu() {
  print_header
  row "GIT LAUNCH"
  empty_row

  row2 " 1. Git status" " 2. Git pull"
  row2 " 3. Git push" " 4. Open repo in browser"
  row2 " 5. Open local repo folder" " 0. Back"

  print_footer
  printf "${C_TITLE}Select git option [0-5]: ${C_RESET}"
}

print_net_menu() {
  print_header
  row "NET LAUNCH"
  empty_row

  row2 " 1. Show IP + network info" " 2. Ping test"
  row2 " 3. Show DNS + gateway" " 4. Open Network Settings"
  row2 " 5. Copy IP info to clipboard" " 0. Back"

  print_footer
  printf "${C_TITLE}Select net option [0-5]: ${C_RESET}"
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

git_menu_loop() {
  local choice

  while true; do
    print_git_menu
    read -r choice
    echo

    case "$choice" in
      1) run_git_screen "GIT STATUS" "git status --short --branch" ;;
      2) run_git_screen "GIT PULL" "git pull" ;;
      3) run_git_screen "GIT PUSH" "git push" ;;
      4) open_repo_browser ;;
      5) open_base_dir ;;
      0) break ;;
      *) echo "${C_ERR}Invalid git selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

net_menu_loop() {
  local choice

  while true; do
    print_net_menu
    read -r choice
    echo

    case "$choice" in
      1) show_network_info ;;
      2) ping_test ;;
      3) show_dns_gateway ;;
      4) open_network_settings ;;
      5) copy_network_info ;;
      0) break ;;
      *) echo "${C_ERR}Invalid net selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

dev_menu_loop() {
  local choice

  while true; do
    print_dev_menu
    read -r choice
    echo

    case "$choice" in
      1) open_ai_prompts_folder ;;
      2) show_prompt_files ;;
      3) edit_mqlaunch ;;
      4) backup_prompts ;;
      5) backup_mqlaunch ;;
      6) open_base_dir ;;
      7) open_launcher_folder ;;
      8) open_terminal_guide ;;
      9) open_git_menu ;;
      10) net_menu_loop ;;
      11) themes_menu_loop ;;
      12) open_tools_menu ;;
      0) break ;;
      *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}


tweaks_menu_loop() {
  local tweaks_script="$BASE_DIR/system/tweaks/macos-tweaks.sh"

  if [[ -x "$tweaks_script" || -f "$tweaks_script" ]]; then
    bash "$tweaks_script" menu || true
  else
    echo "${C_ERR}Tweaks script not found:${C_RESET} $tweaks_script"
    pause_enter
    return 1
  fi
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
      x|X) echo "Exiting ${APP_TITLE}..."; exit 0 ;;
      12) lock_screen ;;
      13) sleep_display ;;
      14) open_utilities_folder ;;
      15) open_applications_folder ;;
      16) restart_finder ;;
      17) show_date_time ;;
      18) open_repo_browser ;;
      19) system_check ;;
      20) ai_menu_loop ;;
      21) dev_menu_loop ;;
      22) tweaks_menu_loop ;;
      23) open_v1_performance_menu ;;
      24) open_v1_dev_menu ;;
      25) open_v1_tools_menu ;;
      26) show_version_info ;;
      27) run_self_check || true ;;
      28) run_debug_bundle || true ;;
      29) show_release_notes || true ;;
      30) show_about_dashboard || true ;;
      31) show_command_index || true ;;
      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

show_help() {
  cat <<HELP

mqlaunch — modular terminal workflow hub

CORE
  mqlaunch                Open main menu
  mqlaunch help           Show help
  mqlaunch commands       Show command index

WORKFLOWS
  mqlaunch perf           Open Performance module
  mqlaunch dev            Open Dev module
  mqlaunch git            Alias for Dev
  mqlaunch tools          Open Tools module
  mqlaunch release        Open Release Menu
  mqlaunch login          Start session boot
  mqlaunch login menu     Session boot + full menu
  mqlaunch login about    Session boot + about screen
  mqlaunch login check    Session boot + self-check

STATUS / SUPPORT
  mqlaunch about          Show about / status dashboard
  mqlaunch version        Show version information
  mqlaunch notes          Show release notes / changelog
  mqlaunch check          Run self-check
  mqlaunch bundle         Create debug bundle

UTILITY
  mqlaunch repo           Open repo root
  mqlaunch guide          Open terminal guide

ALIASES
  mqlaunch health         Alias for check
  mqlaunch support        Alias for bundle
  mqlaunch changelog      Alias for notes
  mqlaunch dashboard      Alias for about
  mqlaunch index          Alias for commands
  mqlaunch palette        Alias for commands

HELP
}

run_arg_command() {
  local cmd="${1:l}"
  shift || true

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
    dev|git) open_v1_dev_menu ;;
    tweaks|tweak|tw) open_tweaks_menu ;;
    tweaks-status) show_tweaks_status ;;
    tweaks-workstation) run_tweaks_workstation ;;
    tweaks-dev) run_tweaks_dev ;;
    tweaks-clean) run_tweaks_clean ;;
    tweaks-fast) run_tweaks_fast ;;
    tweaks-all) run_tweaks_all ;;
    tweaks-revert|revert-tweaks) revert_tweaks_latest ;;
    dashboard|dash) open_dashboard ;;
    theme|themes) themes_menu_loop ;;
    theme-current) theme_cmd current ;;
    theme-reset) theme_cmd reset ;;
    theme-amber) theme_cmd apply amber ;;
    theme-green) theme_cmd apply green ;;
    theme-minimal) theme_cmd apply minimal ;;
    theme-ice) theme_cmd apply ice ;;
    tools-menu|toolsmenu|menu-tools) open_tools_menu ;;
    release|rel) open_release_menu ;;
    git|git-menu|gitlaunch) open_git_menu ;;
    login|boot|session) run_mqlogin "$@" ;;
    perf|performance) open_v1_performance_menu ;;
    version|ver|about) show_version_info ;;
    check|health) run_self_check ;;
    bundle|debug-bundle|support) run_debug_bundle ;;
    notes|changelog|release-notes) show_release_notes ;;
    about|status|dashboard) show_about_dashboard ;;
    commands|index|palette) show_command_index ;;
    dev-v1|git-v1) open_v1_dev_menu ;;
    tools|tools-v1|menu-tools-v1) open_v1_tools_menu ;;
    tools-v1|menu-tools-v1) open_v1_tools_menu ;;
    git-menu|gitmenu|menu-git|git) open_git_menu ;;
    prompts|prompt-folder) open_ai_prompts_folder ;;
    prompt-files|files) show_prompt_files ;;
    edit|edit-mqlaunch) edit_mqlaunch ;;
    backup-prompts|backup) backup_prompts ;;
    backup-mqlaunch|backup-launcher) backup_mqlaunch ;;
    base|macos-scripts) open_base_dir ;;
    launchers|launcher-folder) open_launcher_folder ;;
    guide|terminal-guide) open_terminal_guide ;;
    gitlaunch) git_menu_loop ;;
    netlaunch|net) net_menu_loop ;;
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
  run_arg_command "$@"
else
  main_loop
fi
