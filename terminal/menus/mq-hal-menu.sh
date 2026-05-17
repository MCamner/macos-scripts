#!/usr/bin/env bash

# MQ HAL Menu — follows mqlaunch surface_* pattern.
#
# Rule: this menu owns presentation only.
# mq-hal owns all HAL logic.
#
# STANDARD PATTERN FOR MQLAUNCH SUBMENUS
# ───────────────────────────────────────
# This file is the reference implementation for how new mqlaunch submenus
# should be built. Follow this pattern exactly:
#
#   1. Auto-source mq-ui.sh if surface_* not available (standalone support).
#   2. render_*_panel() calls:
#        print_header           — mqlaunch top bar (if available)
#        surface_panel_header   — submenu box with host/mode/git row
#        surface_row            — section labels inside the box
#        surface_split_row      — two-column item rows inside the box
#        surface_bottom         — closes the box
#   3. Main loop calls read_main_choice "label" for the pinned prompt.
#      Fallback: plain printf + read -r choice for standalone use.
#   4. pause_enter after each action (wrapped in _*_pause_enter for safety).
#   5. hal_menu_is_sourced guard at the bottom for standalone execution.

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

_hal_pause_enter() {
  if command -v pause_enter >/dev/null 2>&1; then
    pause_enter
  else
    printf '\nPress Enter to continue...'
    read -r _
  fi
}

render_hal_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi

  surface_panel_header "MQ HAL" "HAL" "$width" "$panel_color"

  surface_row "OBSERVE" "$width" "$panel_color"
  surface_split_row "1. Brief" "2. Audit" "$width" "$panel_color"
  surface_split_row "3. Release Brief" "4. Repo Status" "$width" "$panel_color"
  surface_split_row "5. CI Status" "6. Doctor Summary" "$width" "$panel_color"
  surface_split_row "7. Timeline" "8. Timeline + details" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "PLAN" "$width" "$panel_color"
  surface_split_row "9. Fix Doctor Plan" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "MEMORY" "$width" "$panel_color"
  surface_split_row "10. Session Memory" "11. Last Memory Item" "$width" "$panel_color"
  surface_split_row "12. Remember Note" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "DEBUG" "$width" "$panel_color"
  surface_split_row "13. Repos" "14. Raw Intent" "$width" "$panel_color"
  surface_split_row "15. Free Prompt" "16. Memory Path" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

hal_menu_missing() {
  local width
  width="$(surface_terminal_width)"
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  surface_panel_header "MQ HAL" "HAL" "$width" ""
  surface_row "HAL backend not found: $MQ_HAL_BIN" "$width" ""
  surface_row "" "$width" ""
  surface_row "Check: ls -l ~/mq-hal/bin/mq-hal" "$width" ""
  surface_bottom "$width" ""
  _hal_pause_enter
}

hal_menu_remember() {
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  printf '\n'
  printf "note> "
  local note=""
  read -r note
  [[ -z "${note// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" remember "$note"
  _hal_pause_enter
}

hal_menu_raw_intent() {
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  printf '\n'
  printf "raw> "
  local prompt=""
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" --raw-intent "$prompt"
  _hal_pause_enter
}

hal_menu_free_prompt() {
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  printf '\n'
  printf "hal> "
  local prompt=""
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" "$prompt"
  _hal_pause_enter
}

mq_hal_menu_main() {
  local choice

  if [[ ! -x "$MQ_HAL_BIN" ]]; then
    hal_menu_missing
    return 127
  fi

  while true; do
    render_hal_panel

    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "hal" || break
    else
      printf '\nhal> '
      read -r choice
    fi
    echo

    case "$choice" in
      1)  "$MQ_HAL_BIN" brief;              _hal_pause_enter ;;
      2)  "$MQ_HAL_BIN" audit;              _hal_pause_enter ;;
      3)  "$MQ_HAL_BIN" release-brief;      _hal_pause_enter ;;
      4)  "$MQ_HAL_BIN" repo-status;        _hal_pause_enter ;;
      5)  "$MQ_HAL_BIN" ci;                 _hal_pause_enter ;;
      6)  "$MQ_HAL_BIN" doctor-summary;     _hal_pause_enter ;;
      7)  "$MQ_HAL_BIN" timeline;           _hal_pause_enter ;;
      8)  "$MQ_HAL_BIN" timeline --details; _hal_pause_enter ;;
      9)  "$MQ_HAL_BIN" fix-doctor;         _hal_pause_enter ;;
      10) "$MQ_HAL_BIN" session;            _hal_pause_enter ;;
      11) "$MQ_HAL_BIN" last;               _hal_pause_enter ;;
      12) hal_menu_remember ;;
      13) "$MQ_HAL_BIN" --list-repos;       _hal_pause_enter ;;
      14) hal_menu_raw_intent ;;
      15) hal_menu_free_prompt ;;
      16) "$MQ_HAL_BIN" memory-path;        _hal_pause_enter ;;
      h|help) "$MQ_HAL_BIN" --help;         _hal_pause_enter ;;
      b|B|back) break ;;
      x|X) exit 0 ;;
      *)
        if [[ -n "$choice" ]]; then
          printf '\n'
          /bin/zsh -lc "$choice" 2>/dev/null || true
          _hal_pause_enter
        fi
        ;;
    esac
  done
}

if ! hal_menu_is_sourced; then
  mq_hal_menu_main "$@"
fi
