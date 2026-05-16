#!/usr/bin/env bash
set -euo pipefail

# MQ HAL Menu
# Thin terminal UI for mq-hal.
#
# Rule:
#   This menu owns presentation only.
#   mq-hal owns all HAL logic.

MQ_HAL_BIN="${MQ_HAL_BIN:-$HOME/mq-hal/bin/mq-hal}"

mq_hal_menu_clear() {
  printf '\033[2J\033[H'
}

mq_hal_menu_line() {
  printf '%s\n' "────────────────────────────────────────────────────────────"
}

mq_hal_menu_pause() {
  printf '\n'
  read -r -p "Press Enter to continue..."
}

mq_hal_menu_header() {
  mq_hal_menu_clear
  printf '%s\n' "╔════════════════════════════════════════════════════════════╗"
  printf '%s\n' "║ MQ HAL                                                     ║"
  printf '%s\n' "║ Local command intelligence · Ollama · mq-hal · memory      ║"
  printf '%s\n' "╚════════════════════════════════════════════════════════════╝"
  printf '\n'
}

mq_hal_menu_available() {
  [[ -x "$MQ_HAL_BIN" ]]
}

mq_hal_menu_missing() {
  mq_hal_menu_header
  printf '%s\n' "HAL backend not found."
  printf '\n'
  printf '%s\n' "Expected:"
  printf '  %s\n' "$MQ_HAL_BIN"
  printf '\n'
  printf '%s\n' "Check:"
  printf '  %s\n' "ls -l ~/mq-hal/bin/mq-hal"
  printf '  %s\n' "~/mq-hal/bin/mq-hal --list-repos"
  mq_hal_menu_pause
}

# Private: execute mq-hal binary directly.
# Named distinctly to avoid conflicting with hal-bridge.sh's mq_hal_run().
_hal_menu_exec() {
  "$MQ_HAL_BIN" "$@"
}

mq_hal_menu_prompt() {
  local choice=""

  printf '\n'
  printf '%s\n' "╭─ HAL PROMPT ───────────────────────────────────────────────╮"
  printf '%s\n' "│ number = run action · h = help · q = back                  │"
  printf '│ hal> '
  read -r choice
  printf '%s\n' "╰────────────────────────────────────────────────────────────╯"

  MQ_HAL_MENU_CHOICE="$choice"
}

mq_hal_menu_remember() {
  local note=""

  printf '\n'
  printf '%s\n' "╭─ REMEMBER NOTE ────────────────────────────────────────────╮"
  printf '%s\n' "│ Write a local HAL note. It is saved in ~/.mq-hal/session.  │"
  printf '│ note> '
  read -r note
  printf '%s\n' "╰────────────────────────────────────────────────────────────╯"

  if [[ -z "${note// }" ]]; then
    printf '\n%s\n' "No note saved."
    mq_hal_menu_pause
    return 0
  fi

  printf '\n'
  _hal_menu_exec remember "$note"
  mq_hal_menu_pause
}

mq_hal_menu_raw_intent() {
  local prompt=""

  printf '\n'
  printf '%s\n' "╭─ RAW INTENT DEBUG ─────────────────────────────────────────╮"
  printf '%s\n' "│ Ask HAL something. It will print the parsed JSON intent.   │"
  printf '│ raw> '
  read -r prompt
  printf '%s\n' "╰────────────────────────────────────────────────────────────╯"

  if [[ -z "${prompt// }" ]]; then
    printf '\n%s\n' "No prompt provided."
    mq_hal_menu_pause
    return 0
  fi

  printf '\n'
  _hal_menu_exec --raw-intent "$prompt"
  mq_hal_menu_pause
}

mq_hal_menu_free_prompt() {
  local prompt=""

  printf '\n'
  printf '%s\n' "╭─ HAL FREE PROMPT ──────────────────────────────────────────╮"
  printf '%s\n' "│ Ask HAL to route a safe local command intent.              │"
  printf '│ ask> '
  read -r prompt
  printf '%s\n' "╰────────────────────────────────────────────────────────────╯"

  if [[ -z "${prompt// }" ]]; then
    printf '\n%s\n' "No prompt provided."
    mq_hal_menu_pause
    return 0
  fi

  printf '\n'
  _hal_menu_exec "$prompt"
  mq_hal_menu_pause
}

mq_hal_menu_show() {
  mq_hal_menu_header

  printf '%s\n' "Command Surface"
  mq_hal_menu_line
  printf '%s\n' "  1) Doctor Summary"
  printf '%s\n' "  2) Fix Doctor Plan"
  printf '%s\n' "  3) Timeline"
  printf '%s\n' "  4) Timeline with details"
  printf '%s\n' "  5) Session Memory"
  printf '%s\n' "  6) Last Memory Item"
  printf '%s\n' "  7) Remember Note"
  printf '%s\n' "  8) Repos"
  printf '%s\n' "  9) Raw Intent Debug"
  printf '%s\n' " 10) Free HAL Prompt"
  printf '%s\n' " 11) Memory Path"
  printf '%s\n' "  h) Help"
  printf '%s\n' "  q) Back"
  mq_hal_menu_line
}

mq_hal_menu_main() {
  if ! mq_hal_menu_available; then
    mq_hal_menu_missing
    return 127
  fi

  while true; do
    mq_hal_menu_show
    mq_hal_menu_prompt

    case "${MQ_HAL_MENU_CHOICE}" in
      1)
        mq_hal_menu_header
        _hal_menu_exec doctor-summary
        mq_hal_menu_pause
        ;;

      2)
        mq_hal_menu_header
        _hal_menu_exec fix-doctor
        mq_hal_menu_pause
        ;;

      3)
        mq_hal_menu_header
        _hal_menu_exec timeline
        mq_hal_menu_pause
        ;;

      4)
        mq_hal_menu_header
        _hal_menu_exec timeline --details
        mq_hal_menu_pause
        ;;

      5)
        mq_hal_menu_header
        _hal_menu_exec session
        mq_hal_menu_pause
        ;;

      6)
        mq_hal_menu_header
        _hal_menu_exec last
        mq_hal_menu_pause
        ;;

      7)
        mq_hal_menu_header
        mq_hal_menu_remember
        ;;

      8)
        mq_hal_menu_header
        _hal_menu_exec --list-repos
        mq_hal_menu_pause
        ;;

      9)
        mq_hal_menu_header
        mq_hal_menu_raw_intent
        ;;

      10)
        mq_hal_menu_header
        mq_hal_menu_free_prompt
        ;;

      11)
        mq_hal_menu_header
        _hal_menu_exec memory-path
        mq_hal_menu_pause
        ;;

      h|help)
        mq_hal_menu_header
        _hal_menu_exec --help 2>/dev/null || printf '%s\n' "Use mqlaunch hal <command>."
        mq_hal_menu_pause
        ;;

      q|quit|back|0)
        return 0
        ;;

      *)
        printf '\nUnknown choice: %s\n' "${MQ_HAL_MENU_CHOICE}"
        mq_hal_menu_pause
        ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mq_hal_menu_main "$@"
fi
