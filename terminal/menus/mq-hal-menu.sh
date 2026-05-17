#!/usr/bin/env bash

# MQ HAL Menu — mqlaunch v3 surface style.
#
# Rule: this menu owns presentation only.
# mq-hal owns all HAL logic.

hal_menu_is_sourced() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    [[ ":${ZSH_EVAL_CONTEXT:-}:" == *:file:* ]]
    return
  fi
  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

if ! command -v surface_top >/dev/null 2>&1; then
  : "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"
  [[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"
fi

: "${MQ_HAL_BIN:=$HOME/mq-hal/bin/mq-hal}"

render_hal_panel() {
  local width panel_color host user git_state
  width="$(surface_terminal_width)"

  if [[ -t 1 ]]; then
    panel_color=$'\033[0;37m'
  else
    panel_color=""
  fi

  host="$(hostname -s 2>/dev/null || echo unknown)"
  user="${USER:-unknown}"
  git_state="$(surface_git_state 2>/dev/null || echo '-')"

  surface_top "MQ HAL" "$width" "$panel_color"
  surface_row "Host: $host   User: $user   Mode: HAL   Git: $git_state" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "OBSERVE" "$width" "$panel_color"
  surface_split_row "1. Brief" "2. Doctor Summary" "$width" "$panel_color"
  surface_split_row "3. Timeline" "4. Timeline + details" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "PLAN" "$width" "$panel_color"
  surface_split_row "5. Fix Doctor Plan" "6. Remember Note" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "MEMORY" "$width" "$panel_color"
  surface_split_row "7. Session Memory" "8. Last Memory Item" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "DEBUG" "$width" "$panel_color"
  surface_split_row "9. Repos" "10. Free HAL Prompt" "$width" "$panel_color"
  surface_split_row "11. Raw Intent" "12. Memory Path" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

render_hal_command_surface() {
  local width SURFACE_COLOR FIGURE_COLOR ALT_FIGURE_COLOR USER_NAME HOST_NAME TIME git_state
  width="$(surface_terminal_width)"
  MQ_SURFACE_WIDTH="$width"
  USER_NAME="${USER:-$(whoami)}"
  HOST_NAME="$(hostname -s 2>/dev/null || echo unknown)"
  TIME="$(date '+%Y-%m-%d %H:%M:%S')"
  git_state="$(surface_git_state 2>/dev/null || echo '-')"

  if [[ -t 1 ]]; then
    SURFACE_COLOR=$'\033[0;37m'
    FIGURE_COLOR=$'\033[0;31m'
    ALT_FIGURE_COLOR=$'\033[0;32m'
  else
    SURFACE_COLOR=""
    FIGURE_COLOR=""
    ALT_FIGURE_COLOR=""
  fi

  surface_top "HAL · Session Memory · Ollama" "$width" "$SURFACE_COLOR"

  if (( width < 56 )); then
    surface_row "HAL is ready." "$width" "$SURFACE_COLOR"
    surface_compact_dual_figure_row " ▄████▄ " "▄▀▄▀▄▀▄▀" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_compact_dual_figure_row "███ ██ █" "░▒▓██▓▒░" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_compact_dual_figure_row "███ ██ █" "░▒▓██▓▒░" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_compact_dual_figure_row " ▀████▀ " "▀▄▀▄▀▄▀▄" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_row "Git: $git_state" "$width" "$SURFACE_COLOR"
    surface_row "Host: $HOST_NAME | User: $USER_NAME" "$width" "$SURFACE_COLOR"
    surface_row "Time: $TIME | X. Exit launcher" "$width" "$SURFACE_COLOR"
  else
    surface_split_row "HAL is ready." "Memory: ~/.mq-hal/session.jsonl" "$width" "$SURFACE_COLOR"
    surface_split_row "Mode: HAL" "Git: $git_state" "$width" "$SURFACE_COLOR"
    surface_row "" "$width" "$SURFACE_COLOR"
    surface_dual_figure_row " ▄████▄ " "▄▀▄▀▄▀▄▀" "" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row "███ ██ █" "░▒▓██▓▒░" "Observe. Plan. Remember." "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row "███ ██ █" "░▒▓██▓▒░" "Repo: macos-scripts" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row " ▀████▀ " "▀▄▀▄▀▄▀▄" "Backend: mq-hal" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_row "" "$width" "$SURFACE_COLOR"
    surface_split_row "Host: $HOST_NAME" "User: $USER_NAME" "$width" "$SURFACE_COLOR"
    surface_split_row "Time: $TIME" "X. Exit launcher" "$width" "$SURFACE_COLOR"
  fi

  surface_bottom "$width" "$SURFACE_COLOR"
}

hal_menu_missing() {
  local width
  width="$(surface_terminal_width)"
  surface_top "MQ HAL" "$width" ""
  surface_row "HAL backend not found: $MQ_HAL_BIN" "$width" ""
  surface_row "" "$width" ""
  surface_row "Install: git clone https://github.com/MCamner/mq-hal.git ~/mq-hal" "$width" ""
  surface_bottom "$width" ""
  pause_enter
}

hal_menu_remember() {
  local note=""
  printf '\n'
  printf "note> "
  read -r note
  [[ -z "${note// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" remember "$note"
  pause_enter
}

hal_menu_free_prompt() {
  local prompt=""
  printf '\n'
  printf "hal> "
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" "$prompt"
  pause_enter
}

hal_menu_raw_intent() {
  local prompt=""
  printf '\n'
  printf "raw> "
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" --raw-intent "$prompt"
  pause_enter
}

open_hal_menu() {
  local choice

  if [[ ! -x "$MQ_HAL_BIN" ]]; then
    print_header
    hal_menu_missing
    return 127
  fi

  while true; do
    print_header
    render_hal_panel

    read_main_choice "hal"
    echo

    case "$choice" in
      # OBSERVE
      1) "$MQ_HAL_BIN" brief; pause_enter ;;
      2) "$MQ_HAL_BIN" doctor-summary; pause_enter ;;
      3) "$MQ_HAL_BIN" timeline; pause_enter ;;
      4) "$MQ_HAL_BIN" timeline --details; pause_enter ;;
      # PLAN
      5) "$MQ_HAL_BIN" fix-doctor; pause_enter ;;
      6) hal_menu_remember ;;
      # MEMORY
      7) "$MQ_HAL_BIN" session; pause_enter ;;
      8) "$MQ_HAL_BIN" last; pause_enter ;;
      # DEBUG
      9) "$MQ_HAL_BIN" --list-repos; pause_enter ;;
      10) hal_menu_free_prompt ;;
      11) hal_menu_raw_intent ;;
      12) "$MQ_HAL_BIN" memory-path; pause_enter ;;
      b|B|back) break ;;
      x|X) exit 0 ;;
      *)
        if [[ -n "$choice" ]]; then
          echo
          /bin/zsh -lc "$choice" 2>/dev/null || true
          pause_enter
        fi
        ;;
    esac
  done
}

if ! hal_menu_is_sourced; then
  open_hal_menu "$@"
fi
