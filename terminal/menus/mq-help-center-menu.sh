#!/usr/bin/env bash

if ! command -v surface_top >/dev/null 2>&1; then
  BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
  # shellcheck disable=SC1091
  [[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"
fi

# Coordinates help center git state behavior.
help_center_git_state() {
  local count
  count="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

  if [[ -z "$count" || "$count" == "0" ]]; then
    printf "Clean"
  else
    printf "Dirty (%s)" "$count"
  fi
}

# Renders the help center panel view for terminal output.
render_help_center_panel() {
  local width panel_color host user git_state mode
  width="$(surface_terminal_width)"

  if [[ -t 1 ]]; then
    panel_color=$'\033[0;37m'
  else
    panel_color=""
  fi

  host="$(hostname -s 2>/dev/null || echo unknown)"
  user="${USER:-unknown}"
  git_state="$(help_center_git_state)"
  mode="Help"

  surface_top "Help" "$width" "$panel_color"
  surface_row "Host: $host   User: $user   Mode: $mode   Git: $git_state" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "REFERENCE" "$width" "$panel_color"
  surface_split_row "1. Command index" "2. About / Status" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "INFO" "$width" "$panel_color"
  surface_split_row "3. Version" "4. Release Notes" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "SUPPORT" "$width" "$panel_color"
  surface_split_row "5. Repo in browser" "6. Repo folder" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Opens help center menu.
open_help_center_menu() {
  local choice

  while true; do
    print_header
    render_help_center_panel

    read_menu_choice "" "help" || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) show_command_index || true ;;
      2) show_about_dashboard || true ;;
      3) show_version_info || true ;;
      4) show_release_notes || true ;;
      5) open_repo_browser ;;
      6) open_base_dir ;;
      b|B|x|X|exit) return ;;
      *)
        echo "${C_ERR}Invalid selection:${C_RESET} $choice"
        pause_enter
        ;;
    esac
  done
}
