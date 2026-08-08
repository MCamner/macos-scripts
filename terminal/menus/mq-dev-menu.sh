#!/usr/bin/env bash

# Resolved at source time because dev_repo_path's fallback needs it and cannot
# recompute it: BASH_SOURCE is unset under zsh (the interactive launcher), and
# inside a zsh function $0 holds the function name, not the file. `-` rather
# than `:-` so it survives a caller running under `set -u`. Same idiom as
# ui/terminal-ui/mq-ui.sh and mqlaunch/lib/mqobsidian/manifest.sh.
_mq_dev_menu_self="${BASH_SOURCE[0]-}"
[ -n "$_mq_dev_menu_self" ] || _mq_dev_menu_self="$0"
_MQ_DEV_MENU_DIR="$(cd "$(dirname "$_mq_dev_menu_self")" 2>/dev/null && pwd)"
unset _mq_dev_menu_self

# Runs a bundled dev script with a clear missing-file fallback.
run_dev_script() {
  local label="$1"
  local script="$2"
  shift 2

  if [[ -x "$script" ]]; then
    "$script" "$@"
  elif [[ -f "$script" ]]; then
    bash "$script" "$@"
  else
    print_header
    row_bold "$label"
    empty_row
    row "Script missing:"
    row " $script"
    print_footer
  fi

  pause_enter
}

# Resolves a repo-local path from BASE_DIR when available, otherwise from this file.
dev_repo_path() {
  local relative_path="$1"
  local script_dir repo_root

  if [[ -n "${BASE_DIR:-}" ]]; then
    printf '%s/%s\n' "$BASE_DIR" "$relative_path"
    return
  fi

  script_dir="${_MQ_DEV_MENU_DIR:-}"
  if [[ -z "$script_dir" ]]; then
    printf '%s\n' "$relative_path"
    return 1
  fi
  repo_root="$(cd "$script_dir/../.." && pwd)"
  printf '%s/%s\n' "$repo_root" "$relative_path"
}

# Renders a Dev submenu panel from a title and its rows.
_dev_submenu_panel() {
  local title="$1"; shift
  local width panel_color heading
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # `tr` rather than `${title^^}`: that expansion is bash 4, and this menu is
  # sourced into whatever shell mqlaunch runs under — on macOS that can be
  # /bin/bash 3.2 or zsh, neither of which has it.
  heading="$(printf '%s' "$title" | tr '[:lower:]' '[:upper:]')"

  print_header
  surface_panel_header "$title" "Dev" "$width" "$panel_color"
  surface_row "$heading" "$width" "$panel_color"
  local row
  for row in "$@"; do
    surface_split_row "$row" "" "$width" "$panel_color"
  done
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the prompt-library submenu.
dev_prompts_menu_loop() {
  local choice
  while true; do
    _dev_submenu_panel "Prompts" "1. Open AI Prompts folder" "2. Show prompt files" \
      "3. Backup prompts"
    read_menu_choice "" "prompts" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) open_ai_prompts_folder ;;
      2) show_prompt_files ;;
      3) backup_prompts ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

# Runs the folders submenu.
dev_folders_menu_loop() {
  local choice
  while true; do
    _dev_submenu_panel "Folders" "1. macos-scripts folder" "2. Launcher folder"
    read_menu_choice "" "folders" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) open_base_dir ;;
      2) open_launcher_folder ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

# Runs the submenu holding the doors to other menus.
#
# Network, Themes and Tools were rows 9-11 of the front menu, sitting between
# actions. They are not dev actions — they are other menus — and Dev is the only
# place a menu reaches Themes and Tools at all, so they are grouped rather than
# removed. The HAL terminal guide joins them: it is also a menu, not a script.
dev_menus_menu_loop() {
  local choice
  while true; do
    _dev_submenu_panel "Menus" "1. Network tools" "2. Themes" "3. Tools menu" \
      "4. HAL terminal guide"
    read_menu_choice "" "menus" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) net_menu_loop ;;
      2) open_themes_menu ;;
      3) open_tools_menu ;;
      4) run_dev_script "HAL TERMINAL GUIDE" "$(dev_repo_path "tools/scripts/hal-terminal-guide.sh")" ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

# Prints dev menu.
print_dev_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Prompt Tools" "Dev" "$width" "$panel_color"
  surface_row "PROMPTS" "$width" "$panel_color"
  surface_split_row "1. Prompts" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MQLAUNCH" "$width" "$panel_color"
  surface_split_row "2. Edit mqlaunch" "3. Backup mqlaunch" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "FOLDERS" "$width" "$panel_color"
  surface_split_row "4. Folders" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "REPO" "$width" "$panel_color"
  surface_split_row "5. Create repo" "${C_WARN}6. Repo signal folder check${C_RESET}" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "TOOLS" "$width" "$panel_color"
  surface_split_row "7. Comment scripts" "8. Env snapshot" "$width" "$panel_color"
  surface_split_row "9. Excalidraw" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MENUS" "$width" "$panel_color"
  surface_split_row "10. Menus" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "B2 ATLAS" "$width" "$panel_color"
  surface_split_row "a. B2 Atlas Prompt TUI" "b. Back" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Routes a dev menu selection to its script, submenu, or fallback path.
handle_dev_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) dev_prompts_menu_loop ;;
    2) edit_mqlaunch ;;
    3) backup_mqlaunch ;;
    4) dev_folders_menu_loop ;;
    5) run_dev_script "CREATE REPO" "$(dev_repo_path "terminal/dev/mq-create-repo.sh")" ;;
    6) run_dev_script "REPO SIGNAL FOLDER CHECK" "$(dev_repo_path "terminal/dev/mq-repo-signal-folder-check.sh")" ;;
    7) run_dev_script "COMMENT SCRIPTS" "$(dev_repo_path "terminal/menus/mq-tools-menu.sh")" docfunc ;;
    8) run_dev_script "ENV SNAPSHOT" "$(dev_repo_path "tools/scripts/env-snap.sh")" ;;
    9) run_dev_script "EXCALIDRAW" "$(dev_repo_path "tools/scripts/excalidraw.sh")" ;;
    10) dev_menus_menu_loop ;;
    a|A) PYTHONPATH="${BASE_DIR}" python3 -m mqlaunch.b2_tui.main ;;
    b|B|x|X|exit) return 1 ;;
    *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

# Keeps the dev menu interactive until the user backs out.
dev_menu_loop() {
  local choice

  while true; do
    print_dev_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice || break
    else
      printf "\nmqlaunch > "
      read -r choice
    fi
    echo

    if ! handle_dev_menu_choice "$choice"; then
      break
    fi
  done
}

# Opens dev menu.
open_dev_menu() {
  dev_menu_loop
}
