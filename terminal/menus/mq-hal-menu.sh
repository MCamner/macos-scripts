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

# Checks whether hal menu is sourced.
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

# Pauses safely after HAL menu actions.
_hal_pause_enter() {
  if command -v pause_enter >/dev/null 2>&1; then
    pause_enter
  else
    printf '\nPress Enter to continue...'
    read -r _
  fi
}

# Renders the HAL menu panel.
render_hal_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi

  surface_panel_header "MQ HAL" "HAL" "$width" "$panel_color"

  surface_row "OBSERVE" "$width" "$panel_color"
  surface_split_row "1. Brief" "2. Repo status" "$width" "$panel_color"
  surface_split_row "3. Release readiness" "4. CI status" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "HEALTH" "$width" "$panel_color"
  surface_split_row "5. Doctor" "6. Fix plan" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "MEMORY" "$width" "$panel_color"
  surface_split_row "7. Memory" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "DEBUG / ADVANCED" "$width" "$panel_color"
  surface_split_row "8. Diagnostics" "9. Repos" "$width" "$panel_color"
  surface_split_row "10. Prompt" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_row "Shell needs an explicit prefix:  ! ls -la" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Shows the missing mq-hal message.
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

# Prompts HAL to remember a note.
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

# Shows HAL raw intent output.
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

# Runs a free-form HAL prompt.
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


# The three submenus the grouped front menu opens. Every action that used to sit
# flat on the front is still here — the menu got shorter, not smaller.
#
# `audit` and `context` were not in the grouping brief and are not lost: audit is
# a primary HAL job and keeps its `a` / `audit` shortcut on the front menu, which
# costs no visible row, and both are listed under Diagnostics so they can still
# be found by reading rather than by remembering.

# Renders a HAL submenu panel from a title and its rows.
_hal_submenu_panel() {
  local title="$1"; shift
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # shellcheck disable=SC2034
  MQ_SURFACE_WIDTH="$width"

  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  surface_panel_header "$title" "HAL" "$width" "$panel_color"
  # `tr` rather than `${title^^}`: that expansion is bash 4, and this menu is
  # sourced into whatever shell mqlaunch runs under — on macOS that can be
  # /bin/bash 3.2 or zsh, neither of which has it.
  local heading
  heading="$(printf '%s' "$title" | tr '[:lower:]' '[:upper:]')"
  surface_row "$heading" "$width" "$panel_color"
  local row
  for row in "$@"; do
    surface_split_row "$row" "" "$width" "$panel_color"
  done
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Reads a submenu choice into REPLY, falling back when read_menu_choice is absent.
_hal_submenu_read() {
  if command -v read_menu_choice >/dev/null 2>&1; then
    read_menu_choice "" "$1" || return 1
    return 0
  fi
  printf '\n%s> ' "$1"
  read -r REPLY || return 1
  return 0
}

# Runs the memory submenu.
hal_menu_memory_loop() {
  local choice
  while true; do
    _hal_submenu_panel "Memory" "1. Session memory" "2. Last memory item" \
      "3. Remember note" "4. Memory path"
    _hal_submenu_read "memory" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) "$MQ_HAL_BIN" session;     _hal_pause_enter ;;
      2) "$MQ_HAL_BIN" last;        _hal_pause_enter ;;
      3) hal_menu_remember ;;
      4) "$MQ_HAL_BIN" memory-path; _hal_pause_enter ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) printf 'Unknown memory choice: %s\n' "$choice"; _hal_pause_enter ;;
    esac
  done
}

# Runs the diagnostics submenu.
hal_menu_diagnostics_loop() {
  local choice
  while true; do
    _hal_submenu_panel "Diagnostics" "1. Timeline" "2. Timeline + details" \
      "3. Context status" "4. Audit"
    _hal_submenu_read "diagnostics" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) "$MQ_HAL_BIN" timeline;           _hal_pause_enter ;;
      2) "$MQ_HAL_BIN" timeline --details; _hal_pause_enter ;;
      3) "$MQ_HAL_BIN" context;            _hal_pause_enter ;;
      4) "$MQ_HAL_BIN" audit;              _hal_pause_enter ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) printf 'Unknown diagnostics choice: %s\n' "$choice"; _hal_pause_enter ;;
    esac
  done
}

# Runs the prompt submenu.
hal_menu_prompt_loop() {
  local choice
  while true; do
    _hal_submenu_panel "Prompt" "1. Free prompt" "2. Raw intent"
    _hal_submenu_read "prompt" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) hal_menu_free_prompt ;;
      2) hal_menu_raw_intent ;;
      b|B|back|x|X|exit) return ;;
      "") ;;
      *) printf 'Unknown prompt choice: %s\n' "$choice"; _hal_pause_enter ;;
    esac
  done
}

# Runs the HAL menu loop.
mq_hal_menu_main() {
  local choice _hal_shell

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
      2)  "$MQ_HAL_BIN" repo-status;        _hal_pause_enter ;;
      3)  "$MQ_HAL_BIN" release-brief;      _hal_pause_enter ;;
      4)  "$MQ_HAL_BIN" ci;                 _hal_pause_enter ;;
      5)  "$MQ_HAL_BIN" doctor-summary;     _hal_pause_enter ;;
      6)  "$MQ_HAL_BIN" fix-doctor;         _hal_pause_enter ;;
      7)  hal_menu_memory_loop ;;
      8)  hal_menu_diagnostics_loop ;;
      9)  "$MQ_HAL_BIN" --list-repos;       _hal_pause_enter ;;
      10) hal_menu_prompt_loop ;;
      a|audit) "$MQ_HAL_BIN" audit;         _hal_pause_enter ;;
      h|help) "$MQ_HAL_BIN" --help;         _hal_pause_enter ;;
      b|B|back) break ;;
      x|X) exit 0 ;;
      !*)
        # Shell only when asked for, and only what follows the `!`.
        #
        # This arm used to be the `*` fallback: anything the menu did not
        # recognise went to `/bin/zsh -lc "$choice"`. A typo at the HAL prompt
        # was a shell command, and `2>/dev/null` meant it failed silently. The
        # prefix makes running a shell a decision rather than the default
        # consequence of mistyping.
        _hal_shell="${choice#!}"
        _hal_shell="${_hal_shell# }"
        if [[ -n "$_hal_shell" ]]; then
          printf '\n'
          /bin/zsh -lc "$_hal_shell" || true
          _hal_pause_enter
        fi
        ;;
      "") ;;
      *)
        printf 'Unknown HAL choice: %s\n' "$choice"
        printf 'Shell needs an explicit prefix:  ! ls -la\n'
        _hal_pause_enter
        ;;
    esac
  done
}

if ! hal_menu_is_sourced; then
  mq_hal_menu_main "$@"
fi
