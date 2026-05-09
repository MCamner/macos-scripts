#!/bin/zsh

set -u

# ============================================================
# MQLAUNCH — Branded Neon Command Surface
# Adds:
# - MAIN MENU in bold
# - Author line in header
# - Git Launch + Net Launch in Prompt Tools
# ============================================================

APP_TITLE="MQLAUNCH"
APP_SUBTITLE="Branded Neon Command Surface"
APP_AUTHOR="Author Mattias Camner"

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

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

TERMINAL_GUIDE_HTML="$BASE_DIR/docs/mac-terminal-guide.html"
TERMINAL_GUIDE_URL="https://mcamner.github.io/macos-scripts/"

if [[ -f "$UI_LIB" ]]; then
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

if [[ -t 0 ]]; then
  stty erase '^?' 2>/dev/null || true
fi

BOX_INNER=88

# Main menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-main-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-main-menu.sh"
fi

# Apps menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-apps-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-apps-menu.sh"
fi

# System menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-system-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-system-menu.sh"
fi

# Help center menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-help-center-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-help-center-menu.sh"
fi

# Command mode module
if [[ -f "$BASE_DIR/terminal/launchers/mqlaunch-command-mode.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/launchers/mqlaunch-command-mode.sh"
fi

# AI prompts
if [[ -f "$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh"
fi

# Dev menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-dev-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-dev-menu.sh"
fi

# AI menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-ai-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-ai-menu.sh"
fi

# Net menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-net-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-net-menu.sh"
fi

# Help/index module
if [[ -f "$BASE_DIR/terminal/menus/mq-help-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-help-menu.sh"
fi

# Prints header.
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

# Opens path.
open_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    open "$path"
  else
    echo "${C_ERR}Path not found:${C_RESET} $path"
    pause_enter
  fi
}

# Opens folder screen.
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

# Resolves prompt dir.
resolve_prompt_dir() {
  local candidate
  for candidate in "$BASE_DIR/ai-prompts" "$PROMPT_DIR"; do
    if [[ -d "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

# Resolves ai status.
resolve_ai_status() {
  if [[ -x "$AI_SCRIPT" ]]; then
    print -r -- "OK"
  elif [[ -e "$AI_SCRIPT" ]]; then
    print -r -- "FOUND_NOT_EXECUTABLE"
  else
    print -r -- "MISSING"
  fi
}

# Handles safe run ai.
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

# Runs git screen.
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

# Copies network info.
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

# Opens network settings.
open_network_settings() {
  print_header
  row "OPEN NETWORK SETTINGS"
  empty_row
  row "Opening System Settings → Network"
  print_footer
  open "x-apple.systempreferences:com.apple.Network-Settings.extension"
}

# Pings test.
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

# Shows dns gateway.
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

# Locks screen.
lock_screen() {
  if [[ -x "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" ]]; then
    "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
  else
    osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}' >/dev/null 2>&1
  fi
}

# Sleeps display.
sleep_display() {
  pmset displaysleepnow
}

# Restarts finder.
restart_finder() {
  killall Finder >/dev/null 2>&1
}

# Restarts mqlaunch.
restart_mqlaunch() {
  local target="${1:-menu}"
  shift || true

  if [[ -x "$MQ_SCRIPT" ]]; then
    exec "$MQ_SCRIPT" "$target" "$@"
  elif [[ -f "$MQ_SCRIPT" ]]; then
    exec zsh "$MQ_SCRIPT" "$target" "$@"
  fi

  echo "${C_ERR}mqlaunch script not found:${C_RESET} $MQ_SCRIPT"
  return 1
}

# Shows date time.
show_date_time() {
  print_header
  row "DATE AND TIME"
  empty_row
  row "$(date '+%A %Y-%m-%d')"
  row "$(date '+%H:%M:%S')"
  print_footer
  pause_enter
}

# Opens repo browser.
open_repo_browser() {
  print_header
  row "OPEN REPO IN BROWSER"
  empty_row
  row "Opening:"
  row " $REPO_URL"
  print_footer
  open "$REPO_URL"
}

# Opens terminal guide.
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

# Handles system check.
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
    if [[ "$link_target" == "$BASE_DIR/bin/mqlaunch" || "$link_target" == "$MQ_SCRIPT" ]]; then
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

# Opens downloads folder.
open_downloads_folder() {
  open_folder_screen "OPEN DOWNLOADS FOLDER" "$HOME/Downloads" "Downloads folder missing:"
}

# Opens home folder.
open_home_folder() {
  open_folder_screen "OPEN HOME FOLDER" "$HOME" "Home folder missing:"
}

# Opens utilities folder.
open_utilities_folder() {
  open_folder_screen "OPEN UTILITIES FOLDER" "/Applications/Utilities" "Utilities folder missing:"
}

# Opens applications folder.
open_applications_folder() {
  open_folder_screen "OPEN APPLICATIONS FOLDER" "/Applications" "Applications folder missing:"
}

# Opens ai prompts folder.
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

# Shows prompt files.
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

# Edits mqlaunch.
edit_mqlaunch() {
  ${EDITOR:-nano} "$MQ_SCRIPT"
}

# Backs up prompts.
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

# Opens base dir.
open_base_dir() {
  open_folder_screen "OPEN MACOS-SCRIPTS FOLDER" "$BASE_DIR" "Base dir missing:"
}

# Opens launcher folder.
open_launcher_folder() {
  open_folder_screen "OPEN LAUNCHER FOLDER" "$BASE_DIR/terminal/launchers" "Launcher folder missing:"
}

# Opens tweaks menu.
open_tweaks_menu() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" menu
}

# Shows tweaks status.
show_tweaks_status() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" status
}

# Runs tweaks workstation.
run_tweaks_workstation() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" workstation
}

# Runs tweaks dev.
run_tweaks_dev() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" dev
}

# Runs tweaks clean.
run_tweaks_clean() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" clean
}

# Runs tweaks fast.
run_tweaks_fast() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" fast
}

# Runs tweaks all.
run_tweaks_all() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" all
}

# Reverts tweaks latest.
revert_tweaks_latest() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" revert-latest
}

# Backs up mqlaunch.
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

# Opens themes menu.
open_themes_menu() {
  local themes_script="$BASE_DIR/terminal/menus/mq-themes-menu.sh"

  if [[ -x "$themes_script" ]]; then
    MQ_USE_DASHBOARD_HEADER=1 "$themes_script"
  elif [[ -f "$themes_script" ]]; then
    chmod +x "$themes_script" 2>/dev/null || true
    MQ_USE_DASHBOARD_HEADER=1 bash "$themes_script"
  else
    print_header
    row "THEMES MENU"
    empty_row
    row "Themes menu not found:"
    row " $themes_script"
    print_footer
    pause_enter
  fi
}

# Handles theme cmd.
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

# Handles theme current variant.
theme_current_variant() {
  local zshrc="$HOME/.zshrc"

  if [[ -f "$zshrc" ]] && grep -Eq '^export MQ_ZSH_VARIANT=' "$zshrc" 2>/dev/null; then
    grep -E '^export MQ_ZSH_VARIANT=' "$zshrc" | tail -n 1 | sed -E 's/^export MQ_ZSH_VARIANT="?([^"]+)"?/\1/'
  else
    echo "not-set"
  fi
}

# Handles theme source state.
theme_source_state() {
  local zshrc="$HOME/.zshrc"

  if [[ -f "$zshrc" ]] && grep -Fq 'source "$HOME/macos-scripts/terminal/themes/mq-zsh-theme-v3.zsh"' "$zshrc" 2>/dev/null; then
    echo "PRESENT"
  else
    echo "MISSING"
  fi
}

# Opens git menu.
open_git_menu() {
  local repo_arg="${1:-}"
  local git_script="$BASE_DIR/terminal/launchers/gitlaunch.sh"
  local git_path=""

  if [[ -n "$repo_arg" ]]; then
    git_path="$repo_arg"
  else
    git_path="$(pwd)"
  fi

  if [[ -x "$git_script" ]]; then
    MQ_GIT_REPO="$git_path" "$git_script"
  elif [[ -f "$git_script" ]]; then
    MQ_GIT_REPO="$git_path" zsh "$git_script"
  else
    print_header
    row "GIT MENU"
    empty_row
    row "Git menu not found:"
    row " $git_script"
    print_footer
    pause_enter
  fi
}

# Opens release menu.
open_release_menu() {
  local release_menu="$BASE_DIR/terminal/menus/mq-release-menu.sh"
  if [[ -x "$release_menu" ]]; then
    MQ_USE_DASHBOARD_HEADER=1 "$release_menu" menu
  elif [[ -f "$release_menu" ]]; then
    chmod +x "$release_menu" 2>/dev/null || true
    MQ_USE_DASHBOARD_HEADER=1 bash "$release_menu" menu
  else
    print_header
    row "RELEASE MENU"
    empty_row
    row "Release menu not found:"
    row " $release_menu"
    print_footer
    pause_enter
  fi
}

# Runs mqworkflows.
run_mqworkflows() {
  local workflows_menu="$BASE_DIR/terminal/menus/mq-workflows-menu.sh"

  if [[ -x "$workflows_menu" ]]; then
    MQ_USE_DASHBOARD_HEADER=1 "$workflows_menu" "${@:-menu}"
  elif [[ -f "$workflows_menu" ]]; then
    chmod +x "$workflows_menu" 2>/dev/null || true
    MQ_USE_DASHBOARD_HEADER=1 bash "$workflows_menu" "${@:-menu}"
  else
    print_header
    row_bold "WORKFLOWS"
    empty_row
    row "Workflows menu not found:"
    row " $workflows_menu"
    print_footer
    pause_enter
    return 1
  fi
}

# Opens tools menu.
open_tools_menu() {
  local tools_script="$BASE_DIR/terminal/menus/mq-tools-menu.sh"
  local work_dir="$PWD"

  if [[ -x "$tools_script" ]]; then
    MQ_WORK_DIR="$work_dir" MQ_USE_DASHBOARD_HEADER=1 bash "$tools_script" menu
  elif [[ -f "$tools_script" ]]; then
    chmod +x "$tools_script" 2>/dev/null || true
    MQ_WORK_DIR="$work_dir" MQ_USE_DASHBOARD_HEADER=1 bash "$tools_script" menu
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

# Gets repo version.
get_repo_version() {
  local version_file="$BASE_DIR/VERSION"

  if [[ -f "$version_file" ]]; then
    head -n 1 "$version_file"
  else
    echo "unknown"
  fi
}

# Shows version info.
show_version_info() {
  print_header
  row_bold "VERSION INFO"
  empty_row

  local version
  version="$(get_repo_version)"
  local launcher="$BASE_DIR/terminal/launchers/mqlaunch.sh"
  local main_menu="$BASE_DIR/terminal/menus/mq-main-menu.sh"
  local help_menu="$BASE_DIR/terminal/menus/mq-help-menu.sh"

  row "Project:        macos-scripts"
  row "Version:        $version"
  row "Release stage:  baseline"
  row "Shell:          zsh"
  row "Project root:   $BASE_DIR"
  row "Launcher:       $launcher"
  row "Main menu:      $main_menu"
  row "Help module:    $help_menu"

  print_footer
  pause_enter
}

# Runs self check.
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

# Runs debug bundle.
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

# Shows release notes.
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

# Runs mqlogin.
run_mqlogin() {
  local login_script="$BASE_DIR/automation/login/mqlogin.sh"
  local login_menu="$BASE_DIR/terminal/menus/mq-login-menu.sh"

  if [[ $# -eq 0 && -x "$login_menu" ]]; then
    "$login_menu" menu
    return $?
  fi

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

# Runs mqshortcuts.
run_mqshortcuts() {
  local shortcuts_script="$BASE_DIR/automation/shortcuts/mqshortcuts.sh"
  local shortcuts_menu="$BASE_DIR/terminal/menus/mq-shortcuts-menu.sh"

  if [[ $# -eq 0 && -x "$shortcuts_menu" ]]; then
    "$shortcuts_menu" menu
    return $?
  fi

  if [[ ! -x "$shortcuts_script" ]]; then
    print_header
    row_bold "SHORTCUTS"
    empty_row
    row "Missing or non-executable:"
    row " $shortcuts_script"
    row "Run:"
    row " chmod +x $shortcuts_script"
    print_footer
    pause_enter
    return 1
  fi

  "$shortcuts_script" "$@"
}

# Shows about dashboard.
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
  local launcher="$BASE_DIR/terminal/launchers/mqlaunch.sh"
  local main_menu="$BASE_DIR/terminal/menus/mq-main-menu.sh"
  local help_menu="$BASE_DIR/terminal/menus/mq-help-menu.sh"
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
  row "Launcher:       $launcher"
  row "Main menu:      $main_menu"
  row "Help module:    $help_menu"
  row "Latest bundle:  $latest_bundle"
  row "Core menus:     main / help / dev / ai / net"

  print_footer
  pause_enter
}

# Runs command palette.
run_command_palette() {
  local fzf_bin selected selected_cmd
  fzf_bin="$(command -v fzf 2>/dev/null || true)"

  if [[ -z "$fzf_bin" ]]; then
    print_header
    row_bold "COMMAND PALETTE"
    empty_row
    row "fzf is not installed."
    row "Falling back to command index."
    print_footer
    pause_enter
    show_command_index
    return 0
  fi

  selected="$(
    cat <<'EOF' | "$fzf_bin" --height=70% --layout=reverse --border --prompt='mqlaunch > ' --with-nth=2.. --delimiter=$'\t' --preview-window=hidden
main	Open main menu
demo	Run guided demo mode
git	Open Git workspace
perf	Open Performance module
dev	Open Dev menu
tools	Open Tools menu
workflows	Open Project workflows menu
workflows boot	Run project boot
release	Open Release menu
login	Open Login / Session menu
login menu	Start full session boot
login about	Start session about mode
login check	Start session self-check mode
shortcuts	Open Shortcuts menu
shortcuts list	List shortcuts directly
shortcuts search clip	Search shortcuts by name
version	Show version information
about	Show about / status dashboard
notes	Show release notes
check	Run self-check
bundle	Create debug bundle
repo	Open repo root in browser
hal	Open HAL command menu
guide	Open terminal guide
commands	Show command index
EOF
  )"

  [[ -n "$selected" ]] || return 0

  selected_cmd="${selected%%$'\t'*}"

  case "$selected_cmd" in
    main)
      main_loop
      ;;
    *)
      # shellcheck disable=SC2086
      run_arg_command ${=selected_cmd}
      ;;
  esac
}

# Runs demo mode.
run_demo_mode() {
  local delay version prompt_dir prompt_count repo_state load_line disk_line ip_addr battery_line active_cmd
  local theme_variant theme_state
  delay="${MQLAUNCH_DEMO_DELAY:-1}"
  version="$(get_repo_version)"
  prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"
  prompt_count=0
  load_line="$(uptime 2>/dev/null || echo "uptime unavailable")"
  disk_line="$(df -h / 2>/dev/null | tail -1 || echo "disk usage unavailable")"
  ip_addr="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "Unavailable")"
  battery_line="$(pmset -g batt 2>/dev/null | tail -1 || echo "Battery info unavailable")"
  active_cmd="$(command -v mqlaunch 2>/dev/null || echo "$BIN_LINK")"
  theme_variant="$(theme_current_variant)"
  theme_state="$(theme_source_state)"

  if [[ -n "$prompt_dir" ]]; then
    prompt_count="$(find "$prompt_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  fi

  if git -C "$BASE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$BASE_DIR" diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
      repo_state="clean"
    else
      repo_state="dirty"
    fi
  else
    repo_state="not-a-git-repo"
  fi

  print_header
  row_bold "DEMO MODE"
  empty_row
  row "A guided tour of the mqlaunch surface."
  row "Press Enter to advance each step."
  print_footer
  pause_enter

  print_header
  row_bold "STEP 1 / 5 — SYSTEM CHECK"
  empty_row
  row "[OK]   Base dir: $BASE_DIR"
  row "[OK]   Active command: $active_cmd"
  row "[OK]   Repo state: $repo_state"
  row "[OK]   Prompt files: $prompt_count"
  empty_row
  row "Run anytime:"
  row "  mqlaunch doctor"
  row "  mqlaunch system check"
  print_footer
  pause_enter

  print_header
  row_bold "STEP 2 / 5 — PERFORMANCE SNAPSHOT"
  empty_row
  row "Load:    $load_line"
  row "Disk /:  $disk_line"
  row "Network: $ip_addr"
  row "Battery: $battery_line"
  empty_row
  row "Run anytime:"
  row "  mqlaunch perf"
  row "  mq scan"
  print_footer
  pause_enter

  print_header
  row_bold "STEP 3 / 5 — THEME STATUS"
  empty_row
  row "Current theme: $theme_variant"
  row "Theme source:  $theme_state"
  empty_row
  row "Commands:"
  row "  mqlaunch theme          open theme menu"
  row "  mqlaunch theme-macos    apply macOS theme"
  row "  mqlaunch theme-reset    reset to default"
  print_footer
  pause_enter

  print_header
  row_bold "STEP 4 / 5 — VERSION"
  empty_row
  row "Project:   macos-scripts"
  row "Version:   $version"
  row "Launcher:  $MQ_SCRIPT"
  empty_row
  row "Commands:"
  row "  mqlaunch version"
  row "  mqlaunch notes"
  row "  mqlaunch release"
  print_footer
  pause_enter

  print_header
  row_bold "STEP 5 / 5 — WHAT TO TRY NEXT"
  empty_row
  row "WORKFLOWS"
  row "  mqlaunch system check"
  row "  mqlaunch dev"
  row "  mqlaunch workflows"
  row "  mqlaunch release"
  empty_row
  row "AI ASSISTANT"
  row "  mqlaunch ask \"what does doctor.sh check?\""
  row "  mqlaunch atlas"
  empty_row
  row "RELEASE"
  row "  mqlaunch release-check"
  row "  mqlaunch release-notes"
  print_footer
  pause_enter

  row "Demo complete. Run  mqlaunch  to open the full menu."
}

# Handles legacy alias notice.
legacy_alias_notice() {
  local old_cmd="$1"
  local new_cmd="$2"
  print_header
  row_bold "LEGACY ALIAS"
  empty_row
  row "Redirecting:"
  row " $old_cmd"
  row " -> $new_cmd"
  print_footer
}

# Handles tweaks menu loop.
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

# Runs arg command.
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
    applications) open_applications_folder ;;
    apps|hal|guide-ai|terminal-guide-ai)
      if [[ -n "${1:-}" ]]; then
        "$BASE_DIR/tools/scripts/hal-terminal-guide.sh" ask "$@"
      else
        "$BASE_DIR/tools/scripts/hal-terminal-guide.sh"
      fi
      ;;
    ip|network) show_network_info ;;
    lock) lock_screen ;;
    sleep) sleep_display ;;
    restart|reload|relaunch) restart_mqlaunch "$@" ;;
    restart-finder|finder-restart) restart_finder ;;
    date|time) show_date_time ;;
    repo) open_repo_browser ;;
    ai) open_ai_menu ;;
    dev) open_dev_menu ;;
    tweaks|tweak|tw) open_tweaks_menu ;;
    tweaks-status) show_tweaks_status ;;
    tweaks-workstation) run_tweaks_workstation ;;
    tweaks-dev) run_tweaks_dev ;;
    tweaks-clean) run_tweaks_clean ;;
    tweaks-fast) run_tweaks_fast ;;
    tweaks-all) run_tweaks_all ;;
    tweaks-revert|revert-tweaks) revert_tweaks_latest ;;
    dashboard|dash) open_dashboard ;;
    theme|themes) open_themes_menu ;;
    theme-current) theme_cmd current ;;
    theme-reset) theme_cmd reset ;;
    theme-amber) theme_cmd apply amber ;;
    theme-green) theme_cmd apply green ;;
    theme-minimal) theme_cmd apply minimal ;;
    theme-ice) theme_cmd apply ice ;;
    theme-macos) theme_cmd apply macos ;;
    release|rel) open_release_menu ;;
    workflows|workflow|wf) run_mqworkflows "$@" ;;
    git|git-menu|gitmenu|menu-git) open_git_menu "${1:-}" ;;
    gitlaunch)
      legacy_alias_notice "mqlaunch gitlaunch" "mqlaunch git"
      open_git_menu "${1:-}"
      ;;
    login|boot|session) run_mqlogin "$@" ;;
    shortcuts|shortcut|sc) run_mqshortcuts "$@" ;;
    perf|performance) open_performance_menu ;;
    demo) run_demo_mode ;;
    version|ver|about) show_version_info ;;
    ask) "$BASE_DIR/tools/scripts/ask.sh" "$@" ;;
    fix) "$BASE_DIR/tools/scripts/fix.sh" "$@" ;;
    nickname-set|nick-set|nick)
      if [[ -n "${1:-}" ]]; then
        printf '%s\n' "$*" > "$HOME/.mqlaunch_nickname"
        echo "Smeknamn sparat: $*"
      else
        echo "Nuvarande smeknamn: $(get_nickname)"
        echo "Ändra: mqlaunch nickname-set <smeknamn>"
      fi
      ;;
    doctor) "$BASE_DIR/tools/scripts/doctor.sh" ;;
    check|health) run_self_check ;;
    bundle|debug-bundle|support) run_debug_bundle ;;
    notes|changelog|release-notes) show_release_notes ;;
    about|status|dashboard) show_about_dashboard ;;
    commands|index) show_command_index ;;
    palette|fzf|search) run_command_palette ;;
    dev-v1|git-v1)
      legacy_alias_notice "mqlaunch $cmd" "mqlaunch dev"
      open_dev_menu
      ;;
    tools) open_tools_menu ;;
    docfunc|document-functions) MQ_WORK_DIR="$PWD" "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docfunc ;;
    docwrite|document-functions-write|update-comments)
      MQ_WORK_DIR="$PWD" "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docwrite
      ;;
    tools-menu|toolsmenu|menu-tools|tools-v1|menu-tools-v1)
      legacy_alias_notice "mqlaunch $cmd" "mqlaunch tools"
      open_tools_menu
      ;;
    prompts|prompt-folder) open_ai_prompts_folder ;;
    prompt-files|files) show_prompt_files ;;
    edit|edit-mqlaunch) edit_mqlaunch ;;
    backup-prompts|backup) backup_prompts ;;
    backup-mqlaunch|backup-launcher) backup_mqlaunch ;;
    base|macos-scripts) open_base_dir ;;
    launchers|launcher-folder) open_launcher_folder ;;
    guide|terminal-guide) open_terminal_guide ;;
    netlaunch|net) open_net_menu ;;
    atlas) mq_ai_run_atlas "$@" ;;
    auto|one|decide|research|root|solve|pdebug|menu) safe_run_ai "$cmd" ;;
    mc) "$BASE_DIR/tools/scripts/mission-control.sh" ;;
    ghost) "$BASE_DIR/tools/scripts/network-ghost.sh" ;;
    pulse) "$BASE_DIR/tools/scripts/pulse.sh" ;;
    scan) "$BASE_DIR/tools/scripts/vault-scan.sh" ;;
    reap) "$BASE_DIR/tools/scripts/overseer.sh" ;;
    guard) "$BASE_DIR/tools/scripts/blackout.sh" ;;
    help|-h|--help) show_help ;;
    *)
      echo "${C_ERR}Unknown command:${C_RESET} $cmd"
      echo
      echo "Try:"
      echo "  mqlaunch ask \"Vad betyder kommandot: $cmd $*\""
      echo

      if declare -f mq_ai_prompt_ask >/dev/null; then
        echo "Copying an /ask prompt for this unknown command..."
        mq_ai_prompt_ask "Vad betyder kommandot '$cmd $*' i mqlaunch, och finns det ett liknande kommando?"
        return 0
      fi

      show_help
      exit 1
      ;;
  esac
}

# --- Entry --------------------------------------------------
if [[ $# -gt 0 ]]; then
  # Atlas REPL — intercept before dispatch to avoid ai-mode.sh routing
  case "${1:l}" in
    atlas)
      shift
      mq_ai_run_atlas "$@"
      exit 0
      ;;
  esac

  if dispatch_cli_command "$@"; then
    exit 0
  else
    cmd_status=$?
    if [[ $cmd_status -eq 2 ]]; then
      exit 2
    fi
  fi

  if [[ "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" == "menu" ]]; then
    main_loop
  else
    run_arg_command "$@"
  fi
else
  main_loop
fi
