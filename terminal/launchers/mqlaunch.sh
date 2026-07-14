#!/bin/zsh

set -u

# --- PATH bootstrap -----------------------------------------
# Ensure the standard system + Homebrew bins are on PATH even when mqlaunch is
# started from a stripped environment (GUI launch, non-login shell, a nested
# launcher). Some menu actions need CLI tools that live there — e.g. jq for the
# recommendations consumer. Appends only what is missing, so an inherited PATH
# and its tool precedence are never clobbered.
for _mq_path_dir in /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/bin /bin /usr/sbin /sbin; do
  case ":${PATH}:" in
    *":${_mq_path_dir}:"*) ;;
    *) [[ -d "$_mq_path_dir" ]] && PATH="${PATH:+$PATH:}${_mq_path_dir}" ;;
  esac
done
export PATH
unset _mq_path_dir

# --- UTF-8 locale -------------------------------------------
# The panels draw with multi-byte box glyphs (─│┌┐└┘) and em dashes. A stripped
# launch env (no LANG/LC_*) defaults to the C locale, which byte-mangles those
# glyphs and byte-counts padding — so the panel borders misalign (ragged right
# verticals). Set a UTF-8 locale only when none is active; never override a
# UTF-8 locale the user already has.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf8*|*UTF8*) ;;
  *) export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8 ;;
esac

# ============================================================
# MQLAUNCH — Branded Neon Command Surface
# Adds:
# - MAIN MENU in bold
# - Author line in header
# - Git Launch + Network Tools in Prompt Tools
# ============================================================

APP_TITLE="MQLAUNCH"
APP_SUBTITLE="Branded Neon Command Surface"
APP_AUTHOR="Author Mattias Camner"

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

if [[ ! -t 0 || ! -t 1 || -n "${MQLAUNCH_HEADLESS:-}" ]]; then
  export MQ_NO_TUI=1
fi

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

# HAL bridge (mq-hal local Ollama router)
if [[ -f "$BASE_DIR/terminal/bridges/hal-bridge.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/bridges/hal-bridge.sh"
fi

# Brain bridge (mqobsidian second brain vault)
if [[ -f "$BASE_DIR/terminal/bridges/brain-bridge.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/bridges/brain-bridge.sh"
fi
AI_SCRIPT="$BASE_DIR/tools/cli/ai-mode.sh"
PROMPT_DIR="$BASE_DIR/ai-prompts"
REPO_URL="https://github.com/MCamner/macos-scripts"
MQ_SCRIPT="$BASE_DIR/terminal/launchers/mqlaunch.sh"
BACKUP_DIR="$BASE_DIR/backups"
BIN_LINK="$HOME/bin/mqlaunch"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

# print_header is owned by mq-ui.sh (single header authority). Opt the main loop
# into the dashboard-v7.1 header via mq-ui's cached path — this is a plain
# (non-exported) shell var so it drives this launcher's own print_header calls
# without forcing the dashboard header onto child subprocesses, which set the
# flag themselves where they want it. Cache freshness is bounded by
# MQ_DASHBOARD_CACHE_TTL (default 5s) and invalidated by mutating flows
# (open_git_menu / open_release_menu). Set MQ_DASHBOARD_CACHE_TTL=0 for an
# uncached, per-screen header while investigating.
MQ_USE_DASHBOARD_HEADER=1

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

# Tools menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-tools-menu.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/terminal/menus/mq-tools-menu.sh"
fi

# Workflows menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-workflows-menu.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/terminal/menus/mq-workflows-menu.sh"
fi

# Workspace module
if [[ -f "$BASE_DIR/automation/workflows/workspace.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/automation/workflows/workspace.sh"
fi

# Themes menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-themes-menu.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/terminal/menus/mq-themes-menu.sh"
fi

# Release menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-release-menu.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/terminal/menus/mq-release-menu.sh"
fi

# Shortcuts menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-shortcuts-menu.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/terminal/menus/mq-shortcuts-menu.sh"
fi

# Login menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-login-menu.sh" ]]; then
  # shellcheck disable=SC1091
  MACOS_SCRIPTS_HOME="$BASE_DIR" source "$BASE_DIR/terminal/menus/mq-login-menu.sh"
fi

# Help/index module
if [[ -f "$BASE_DIR/terminal/menus/mq-help-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-help-menu.sh"
fi

# mq-agent menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-agent-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-agent-menu.sh"
fi

# mqobsidian menu module
if [[ -f "$BASE_DIR/terminal/menus/mq-obsidian-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/mq-obsidian-menu.sh"
fi

# recommendations menu module (read-only recommended.json consumer)
if [[ -f "$BASE_DIR/terminal/menus/recommendations-menu.sh" ]]; then
  # shellcheck disable=SC1091
  source "$BASE_DIR/terminal/menus/recommendations-menu.sh"
fi

# --- Shared UI ------------------------------------------------
# print_header is provided by mq-ui.sh (the single header authority); the
# launcher no longer overrides it. With MQ_USE_DASHBOARD_HEADER=1 (set above)
# mq-ui renders the cached dashboard-v7.1 header for the main loop.
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

# Runs ai through guardrails before acting.
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

# Network concern — status, diagnostics, and connectivity actions — lives in a
# dedicated library (Step 11a monolith de-layering, audit P4). Sourced into this
# scope so it keeps using the ambient UI helpers and $BASE_DIR; no behavior
# change — the functions are verbatim moves.
if [[ -f "$BASE_DIR/mqlaunch/lib/network.sh" ]]; then
  source "$BASE_DIR/mqlaunch/lib/network.sh"
else
  mq_debug "mqlaunch: network lib missing: mqlaunch/lib/network.sh"
fi

# --- Actions ------------------------------------------------
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

# GitHub repo picker (fzf over `gh repo list` + open/clone actions) lives in a
# dedicated library (Step 11a monolith de-layering, audit P4). Sourced into this
# scope so it keeps using the ambient UI helpers and $HOME/$SHELL; no behavior
# change — a verbatim move.
if [[ -f "$BASE_DIR/mqlaunch/lib/repo-picker.sh" ]]; then
  source "$BASE_DIR/mqlaunch/lib/repo-picker.sh"
else
  mq_debug "mqlaunch: repo picker lib missing: mqlaunch/lib/repo-picker.sh"
fi

# fzf: bläddra och kopiera sparade AI-prompts från mqobsidian/_prompts/
prompts_pick() {
  local vault_dir="${MQ_OBSIDIAN_DIR:-$HOME/mqobsidian}"
  local prompts_dir="$vault_dir/_prompts/saved-prompts-md-export"
  local fzf_bin
  fzf_bin="$(command -v fzf 2>/dev/null || true)"

  if [[ ! -d "$prompts_dir" ]]; then
    printf "Prompts directory not found: %s\n" "$prompts_dir" >&2
    return 1
  fi

  if [[ -z "$fzf_bin" ]]; then
    printf "fzf is not installed. Install: brew install fzf\n" >&2
    return 1
  fi

  local selected
  selected="$(
    find "$prompts_dir" -name "*.md" -not -name "INDEX.md" -not -name "README.md" -not -name "EXPORT_NOTES.md" -not -name "PROMPT_EXPORT_INDEX.md" | sort | while IFS= read -r f; do
      label="$(basename "$(dirname "$f")" | sed 's/^[0-9]*_//')/$(basename "$f" .md | sed 's/_/ /g')"
      printf "%s\t%s\n" "$label" "$f"
    done \
    | "$fzf_bin" \
        --delimiter='\t' \
        --with-nth=1 \
        --preview='head -40 {2}' \
        --preview-window='right:55%:wrap' \
        --reverse \
        --border \
        --header='Select prompt → copy to clipboard  (ESC = cancel)' \
        --prompt='prompt > ' \
        --height=80% \
    | cut -f2
  )"

  [[ -z "$selected" ]] && return 0

  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$selected"
    printf "Copied to clipboard: %s\n" "$(basename "$selected" .txt | sed 's/_/ /g')"
  else
    printf "pbcopy not available — printing prompt:\n\n"
    cat "$selected"
  fi
}

# fzf interactive pickers (git log/branch, kill process/port, run snippet,
# recent files) live in a dedicated library (Step 11a monolith de-layering,
# audit P4). Sourced into this scope so they keep using the ambient UI helpers
# and $BASE_DIR; no behavior change — the functions are verbatim moves.
if [[ -f "$BASE_DIR/mqlaunch/lib/fzf-pickers.sh" ]]; then
  source "$BASE_DIR/mqlaunch/lib/fzf-pickers.sh"
else
  mq_debug "mqlaunch: fzf pickers lib missing: mqlaunch/lib/fzf-pickers.sh"
fi

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
  local stamp backup_file launcher_backup_dir
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

  if command -v themes_menu_loop >/dev/null 2>&1; then
    MQ_USE_DASHBOARD_HEADER=1 themes_menu_loop
  elif [[ -x "$themes_script" ]]; then
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

# Reads or applies the theme cmd setting.
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

# Reads or applies the theme current variant setting.
theme_current_variant() {
  local zshrc="$HOME/.zshrc"

  if [[ -f "$zshrc" ]] && grep -Eq '^export MQ_ZSH_VARIANT=' "$zshrc" 2>/dev/null; then
    grep -E '^export MQ_ZSH_VARIANT=' "$zshrc" | tail -n 1 | sed -E 's/^export MQ_ZSH_VARIANT="?([^"]+)"?/\1/'
  else
    echo "not-set"
  fi
}

# Reads or applies the theme source state setting.
theme_source_state() {
  local zshrc="$HOME/.zshrc"

  if [[ -f "$zshrc" ]] && grep -Fq 'source "$HOME/macos-scripts/terminal/themes/mq-zsh-theme-v3.zsh"' "$zshrc" 2>/dev/null; then
    echo "PRESENT"
  else
    echo "MISSING"
  fi
}

# Git & release menu launchers live in a dedicated library (Step 11a monolith
# de-layering, audit P4). Sourced into this scope so they keep using the ambient
# UI helpers and $BASE_DIR; no behavior change — the functions are verbatim
# moves.
if [[ -f "$BASE_DIR/mqlaunch/lib/git-menus.sh" ]]; then
  source "$BASE_DIR/mqlaunch/lib/git-menus.sh"
else
  mq_debug "mqlaunch: git menus lib missing: mqlaunch/lib/git-menus.sh"
fi

# Runs mqworkflows.
run_mqworkflows() {
  local cmd="${1:-menu}"

  if command -v workflows_menu_loop >/dev/null 2>&1; then
    export MQ_USE_DASHBOARD_HEADER=1
    case "$cmd" in
      menu) workflows_menu_loop ;;
      status) show_workflows_status ;;
      boot) run_project_boot_default ;;
      boot-custom) run_project_boot_custom ;;
      check) run_project_check_default ;;
      check-custom) run_project_check_custom ;;
      workspace) open_workspace_menu ;;
      save) save_workspace_snapshot ;;
      restore) restore_workspace_snapshot ;;
      validate|health) run_workflows_validation ;;
      readme) open_workflows_readme ;;
      *) workflows_menu_loop ;;
    esac
  else
    local workflows_menu="$BASE_DIR/terminal/menus/mq-workflows-menu.sh"
    if [[ -f "$workflows_menu" ]]; then
      MQ_USE_DASHBOARD_HEADER=1 bash "$workflows_menu" "$cmd"
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
  fi
}

# Opens tools menu.
open_tools_menu() {
  if command -v tools_menu_loop >/dev/null 2>&1; then
    MQ_WORK_DIR="$PWD" MQ_USE_DASHBOARD_HEADER=1 tools_menu_loop
  else
    print_header
    row "TOOLS MENU"
    empty_row
    row "tools_menu_loop not found — mq-tools-menu.sh may not be sourced."
    print_footer
    pause_enter
  fi
}

# Diagnostics — version reporting, self-check, debug bundle, release notes, and
# the system check — live in a dedicated library (Step 11a monolith de-layering,
# audit P4).
# Sourced into this scope so they keep using the ambient UI helpers and
# $BASE_DIR; no behavior change — the functions are verbatim moves.
if [[ -f "$BASE_DIR/mqlaunch/lib/diagnostics.sh" ]]; then
  source "$BASE_DIR/mqlaunch/lib/diagnostics.sh"
else
  mq_debug "mqlaunch: diagnostics lib missing: mqlaunch/lib/diagnostics.sh"
fi

# Runs mqlogin.
run_mqlogin() {
  local login_script="$BASE_DIR/automation/login/mqlogin.sh"
  local login_menu="$BASE_DIR/terminal/menus/mq-login-menu.sh"

  if [[ $# -eq 0 ]]; then
    if command -v login_menu_loop >/dev/null 2>&1; then
      login_menu_loop
      return $?
    elif [[ -x "$login_menu" ]]; then
      "$login_menu" menu
      return $?
    fi
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

  if [[ $# -eq 0 ]]; then
    if command -v shortcuts_menu_loop >/dev/null 2>&1; then
      shortcuts_menu_loop
      return $?
    elif [[ -x "$shortcuts_menu" ]]; then
      "$shortcuts_menu" menu
      return $?
    fi
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

  if [[ ! -t 0 || ! -t 1 || -n "${MQ_NO_TUI:-}" ]]; then
    echo "Command palette requires an interactive terminal. Showing command help instead."
    echo
    show_help
    return 0
  fi

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
hub	Repos — sök, klona eller öppna dina GitHub-repos
git-log	Git commit browser med diff-preview
git-branch	Byt git-branch med fzf
kill-process	Döda processer med fzf
kill-port	Frigör port med fzf
snippets	Kör ett script från macos-scripts
recent	Senast ändrade filer — öppna direkt
hal	Local Ollama command router (mq-hal)
obsidian	Open MQ Obsidian / Memory menu
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

# Coordinates legacy alias notice behavior.
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

# Keeps the tweaks menu interactive until the user backs out.
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
    apps|guide-ai|terminal-guide-ai)
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
    hub|github|ghub|gh-search|gh-pick|10) run_github_repo_picker ;;
    git-log|gitlog|glog) fzf_git_log ;;
    git-branch|branch-switch|gbranch) fzf_git_branch ;;
    kill-process|killp|pkill-fzf) fzf_kill_process ;;
    kill-port|killport|port-kill) fzf_kill_port ;;
    snippets|snippet|scripts) fzf_run_snippet ;;
    recent|recent-files|rf) fzf_recent_files ;;
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
    agent|mq-agent|g) run_agent_command "$@" ;;
    obsidian|mqobsidian|memory-menu|mq-memory) mq_obsidian_menu_main ;;
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
    version|ver) show_version_info ;;
    ask) "$BASE_DIR/tools/scripts/ask.sh" "$@" ;;
    fix) "$BASE_DIR/tools/scripts/fix.sh" "$@" ;;
    skills|skill) "$BASE_DIR/tools/scripts/mq-skills.py" "$@" ;;
    repos)
      case "${1:-}" in
        ""|menu|hub) "$BASE_DIR/bin/mqlaunch" hub ;;
        *) "$BASE_DIR/tools/scripts/mq-repos.py" "$@" ;;
      esac
      ;;
    nickname-set|nick-set|nick)
      if [[ -n "${1:-}" ]]; then
        printf '%s\n' "$*" > "$HOME/.mqlaunch_nickname"
        echo "Smeknamn sparat: $*"
      else
        echo "Nuvarande smeknamn: $(get_nickname)"
        echo "Ändra: mqlaunch nickname-set <smeknamn>"
      fi
      ;;
    doctor) "$BASE_DIR/tools/scripts/doctor.sh" "$@" ;;
    selftest|self-test|self-check) run_self_check ;;
    check|health) run_self_check ;;
    bundle|debug-bundle|support) run_debug_bundle ;;
    notes|changelog|release-notes) show_release_notes ;;
    about|status) show_about_dashboard ;;
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
    hal) mq_hal_run "$@" ;;
    brain|note|sessions|decisions|reviews|learn|verified|systems|memory|stack|roadmap) mq_brain_run "$cmd" "$@" ;;
    review-brain) _run_agent review repo "${2:-.}" --brain ;;
    signal-brain) _run_agent signal --brain "${2:-.}" ;;
    learn-promote|promote-pattern) _run_agent learn promote "${2:-}" --approve ;;
    prompts) prompts_pick ;;
    b2tui|b2) shift; PYTHONPATH="$BASE_DIR" python3 -m mqlaunch.b2_tui.main "$@" ;;
    auto|one|decide|research|root|solve|pdebug|menu) safe_run_ai "$cmd" ;;
    mc) "$BASE_DIR/tools/scripts/mission-control.sh" ;;
    ghost) "$BASE_DIR/tools/scripts/network-ghost.sh" ;;
    pulse) "$BASE_DIR/tools/scripts/pulse.sh" ;;
    scan) "$BASE_DIR/tools/scripts/vault-scan.sh" ;;
    reap) "$BASE_DIR/tools/scripts/overseer.sh" ;;
    guard) "$BASE_DIR/tools/scripts/blackout.sh" ;;
    help|-h|--help) show_help ;;
    *)
      if declare -f print_unknown_command_error >/dev/null; then
        print_unknown_command_error "$cmd"
      else
        printf 'ERROR: Unknown command: %s\n' "$cmd" >&2
        printf 'For AI help, run explicitly: mqlaunch ask "What does %s mean?"\n' \
          "$cmd" >&2
      fi
      return 2
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
