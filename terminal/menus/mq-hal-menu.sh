#!/usr/bin/env bash

# MQ HAL Menu
# Thin terminal UI for mq-hal.
#
# Rule:
#   This menu owns presentation only.
#   mq-hal owns all HAL logic.

if [[ -z "${BASE_DIR:-}" ]]; then
  BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

MQ_HAL_BIN="${MQ_HAL_BIN:-$HOME/mq-hal/bin/mq-hal}"

_hal_clear() {
  printf '\033[2J\033[H'
}

_hal_line() {
  printf '%s\n' "────────────────────────────────────────────────────────────"
}

_hal_pause() {
  printf '\n'
  read -r -p "Press Enter to continue..."
}

_hal_header() {
  _hal_clear
  printf '%s\n' "╔════════════════════════════════════════════════════════════╗"
  printf '%s\n' "║ MQ HAL                                                     ║"
  printf '%s\n' "║ Local command intelligence · Ollama · mq-hal · memory      ║"
  printf '%s\n' "╚════════════════════════════════════════════════════════════╝"
  printf '\n'
}

_hal_available() {
  [[ -x "$MQ_HAL_BIN" ]]
}

_hal_missing() {
  _hal_header
  printf '%s\n' "HAL backend not found."
  printf '\n'
  printf '%s\n' "Expected:"
  printf '  %s\n' "$MQ_HAL_BIN"
  printf '\n'
  printf '%s\n' "Check:"
  printf '  %s\n' "ls -l ~/mq-hal/bin/mq-hal"
  printf '  %s\n' "~/mq-hal/bin/mq-hal --list-repos"
  _hal_pause
}

_hal_run() {
  "$MQ_HAL_BIN" "$@"
}

_hal_prompt() {
  local choice=""
  printf '\n'
  printf '%s\n' "╭─ HAL PROMPT ───────────────────────────────────────────────╮"
  printf '%s\n' "│ number = run action · h = help · q = back                  │"
  printf '│ hal> '
  read -r choice
  printf '%s\n' "╰────────────────────────────────────────────────────────────╯"
  MQ_HAL_MENU_CHOICE="$choice"
}

_hal_text_prompt() {
  local title="$1"
  local hint="$2"
  local prompt_name="$3"
  local value=""
  printf '\n'
  printf '│ %-58s │\n' "$hint"
  printf '│ %s> ' "$prompt_name"
  read -r value
  printf '%s\n' "╰────────────────────────────────────────────────────────────╯"
  MQ_HAL_TEXT_VALUE="$value"
}

_hal_remember() {
  _hal_header
  printf '%s\n' "╭─ REMEMBER NOTE ────────────────────────────────────────────╮"
  _hal_text_prompt "REMEMBER NOTE" "Save a local HAL note in ~/.mq-hal/session.jsonl." "note"
  if [[ -z "${MQ_HAL_TEXT_VALUE// }" ]]; then
    printf '\n%s\n' "No note saved."
    _hal_pause
    return 0
  fi
  printf '\n'
  _hal_run remember "$MQ_HAL_TEXT_VALUE"
  _hal_pause
}

_hal_raw_intent() {
  _hal_header
  printf '%s\n' "╭─ RAW INTENT DEBUG ─────────────────────────────────────────╮"
  _hal_text_prompt "RAW INTENT DEBUG" "Print the parsed JSON intent. Nothing else is executed." "raw"
  if [[ -z "${MQ_HAL_TEXT_VALUE// }" ]]; then
    printf '\n%s\n' "No prompt provided."
    _hal_pause
    return 0
  fi
  printf '\n'
  _hal_run --raw-intent "$MQ_HAL_TEXT_VALUE"
  _hal_pause
}

_hal_free_prompt() {
  _hal_header
  printf '%s\n' "╭─ HAL FREE PROMPT ──────────────────────────────────────────╮"
  _hal_text_prompt "HAL FREE PROMPT" "Ask HAL to route a safe local command intent." "ask"
  if [[ -z "${MQ_HAL_TEXT_VALUE// }" ]]; then
    printf '\n%s\n' "No prompt provided."
    _hal_pause
    return 0
  fi
  printf '\n'
  _hal_run "$MQ_HAL_TEXT_VALUE"
  _hal_pause
}

_hal_show_menu() {
  _hal_header

  printf '%s\n' "OBSERVE"
  _hal_line
  printf '%s\n' "  1) Brief"
  printf '%s\n' "  2) Repo Status"
  printf '%s\n' "  3) CI Status"
  printf '%s\n' "  4) Doctor Summary"
  printf '%s\n' "  5) Timeline"
  printf '%s\n' "  6) Timeline with details"
  printf '\n'

  printf '%s\n' "PLAN"
  _hal_line
  printf '%s\n' "  7) Fix Doctor Plan"
  printf '\n'

  printf '%s\n' "MEMORY"
  _hal_line
  printf '%s\n' "  8) Session Memory"
  printf '%s\n' "  9) Last Memory Item"
  printf '%s\n' " 10) Remember Note"
  printf '\n'

  printf '%s\n' "DEBUG"
  _hal_line
  printf '%s\n' " 11) Repos"
  printf '%s\n' " 12) Raw Intent Debug"
  printf '%s\n' " 13) Free HAL Prompt"
  printf '%s\n' " 14) Memory Path"
  printf '%s\n' "  h) Help"
  printf '%s\n' "  q) Back"
  _hal_line
}

mq_hal_menu_main() {
  if ! _hal_available; then
    _hal_missing
    return 127
  fi

  while true; do
    _hal_show_menu
    _hal_prompt

    case "${MQ_HAL_MENU_CHOICE}" in
      1)
        _hal_header
        _hal_run brief
        _hal_pause
        ;;
      2)
        _hal_header
        _hal_run repo-status
        _hal_pause
        ;;
      3)
        _hal_header
        _hal_run ci
        _hal_pause
        ;;
      4)
        _hal_header
        _hal_run doctor-summary
        _hal_pause
        ;;
      5)
        _hal_header
        _hal_run timeline
        _hal_pause
        ;;
      6)
        _hal_header
        _hal_run timeline --details
        _hal_pause
        ;;
      7)
        _hal_header
        _hal_run fix-doctor
        _hal_pause
        ;;
      8)
        _hal_header
        _hal_run session
        _hal_pause
        ;;
      9)
        _hal_header
        _hal_run last
        _hal_pause
        ;;
      10)
        _hal_remember
        ;;
      11)
        _hal_header
        _hal_run --list-repos
        _hal_pause
        ;;
      12)
        _hal_raw_intent
        ;;
      13)
        _hal_free_prompt
        ;;
      14)
        _hal_header
        _hal_run memory-path
        _hal_pause
        ;;
      h|help)
        _hal_header
        _hal_run --help
        _hal_pause
        ;;
      q|quit|back|0|b|B|x|X)
        return 0
        ;;
      *)
        printf '\nUnknown choice: %s\n' "${MQ_HAL_MENU_CHOICE}"
        _hal_pause
        ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mq_hal_menu_main "$@"
fi
