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
  surface_split_row "1. Brief" "2. Release Brief" "$width" "$panel_color"
  surface_split_row "3. Repo Status" "4. CI Status" "$width" "$panel_color"
  surface_split_row "5. Doctor Summary" "6. Timeline" "$width" "$panel_color"
  surface_split_row "7. Timeline + details" "" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "PLAN" "$width" "$panel_color"
  surface_split_row "8. Fix Doctor Plan" "" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "MEMORY" "$width" "$panel_color"
  surface_split_row "9. Session Memory" "10. Last Memory Item" "$width" "$panel_color"
  surface_split_row "11. Remember Note" "" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "DEBUG" "$width" "$panel_color"
  surface_split_row "12. Repos" "13. Raw Intent" "$width" "$panel_color"
  surface_split_row "14. Free Prompt" "15. Memory Path" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

hal_menu_missing() {
  local width
  width="$(surface_terminal_width)"
  surface_top "MQ HAL" "$width" ""
  surface_row "HAL backend not found: $MQ_HAL_BIN" "$width" ""
  surface_row "" "$width" ""
  surface_row "Check:" "$width" ""
  surface_row "  ls -l ~/mq-hal/bin/mq-hal" "$width" ""
  surface_bottom "$width" ""
  pause_enter
}

hal_menu_remember() {
  local note=""
  print_header
  printf '\n'
  printf "note> "
  read -r note
  [[ -z "${note// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" remember "$note"
  pause_enter
}

hal_menu_raw_intent() {
  local prompt=""
  print_header
  printf '\n'
  printf "raw> "
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" --raw-intent "$prompt"
  pause_enter
}

hal_menu_free_prompt() {
  local prompt=""
  print_header
  printf '\n'
  printf "hal> "
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" "$prompt"
  pause_enter
}

mq_hal_menu_main() {
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
      2) "$MQ_HAL_BIN" release-brief; pause_enter ;;
      3) "$MQ_HAL_BIN" repo-status; pause_enter ;;
      4) "$MQ_HAL_BIN" ci; pause_enter ;;
      5) "$MQ_HAL_BIN" doctor-summary; pause_enter ;;
      6) "$MQ_HAL_BIN" timeline; pause_enter ;;
      7) "$MQ_HAL_BIN" timeline --details; pause_enter ;;
      # PLAN
      8) "$MQ_HAL_BIN" fix-doctor; pause_enter ;;
      # MEMORY
      9) "$MQ_HAL_BIN" session; pause_enter ;;
      10) "$MQ_HAL_BIN" last; pause_enter ;;
      11) hal_menu_remember ;;
      # DEBUG
      12) "$MQ_HAL_BIN" --list-repos; pause_enter ;;
      13) hal_menu_raw_intent ;;
      14) hal_menu_free_prompt ;;
      15) "$MQ_HAL_BIN" memory-path; pause_enter ;;
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
  mq_hal_menu_main "$@"
fi
