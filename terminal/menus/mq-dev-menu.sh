#!/usr/bin/env bash

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

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$script_dir/../.." && pwd)"
  printf '%s/%s\n' "$repo_root" "$relative_path"
}

# Prints dev menu.
print_dev_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Prompt Tools" "Dev" "$width" "$panel_color"
  surface_row "PROMPT LIBRARY" "$width" "$panel_color"
  surface_split_row "1. Open AI Prompts folder" "2. Show prompt files" "$width" "$panel_color"
  surface_split_row "3. Edit mqlaunch" "4. Backup prompts" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "PROJECT" "$width" "$panel_color"
  surface_split_row "5. Backup mqlaunch" "6. Open macos-scripts folder" "$width" "$panel_color"
  surface_split_row "7. Open launcher folder" "8. HAL terminal guide" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "NAVIGATION" "$width" "$panel_color"
  surface_split_row "9. Network Tools" "10. Themes" "$width" "$panel_color"
  surface_split_row "11. Tools Menu" "12. Create Repo" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "B2 ATLAS" "$width" "$panel_color"
  surface_split_row "a. B2 Atlas Prompt TUI" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "MAINTENANCE" "$width" "$panel_color"
  surface_split_row "${C_WARN}13. Repo Signal Folder Check${C_RESET}" "14. Env Snapshot" "$width" "$panel_color"
  surface_split_row "15. Comment scripts" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Routes a dev menu selection to its script, submenu, or fallback path.
handle_dev_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) open_ai_prompts_folder ;;
    2) show_prompt_files ;;
    3) edit_mqlaunch ;;
    4) backup_prompts ;;
    5) backup_mqlaunch ;;
    6) open_base_dir ;;
    7) open_launcher_folder ;;
    8) run_dev_script "HAL TERMINAL GUIDE" "$(dev_repo_path "tools/scripts/hal-terminal-guide.sh")" ;;
    9) net_menu_loop ;;
    10) open_themes_menu ;;
    11) open_tools_menu ;;
    12) run_dev_script "CREATE REPO" "$(dev_repo_path "terminal/dev/mq-create-repo.sh")" ;;
    13) run_dev_script "REPO SIGNAL FOLDER CHECK" "$(dev_repo_path "terminal/dev/mq-repo-signal-folder-check.sh")" ;;
    14) run_dev_script "ENV SNAPSHOT" "$(dev_repo_path "tools/scripts/env-snap.sh")" ;;
    15) run_dev_script "COMMENT SCRIPTS" "$(dev_repo_path "terminal/menus/mq-tools-menu.sh")" docfunc ;;
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
