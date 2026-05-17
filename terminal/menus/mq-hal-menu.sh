#!/usr/bin/env bash

# MQ HAL Menu — self-contained, no surface_* dependency.
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

: "${MQ_HAL_BIN:=$HOME/mq-hal/bin/mq-hal}"

_hal_clear() { printf '\033[2J\033[H'; }

_hal_line() { printf '%s\n' "────────────────────────────────────────────────────────────"; }

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

_hal_menu_show() {
  _hal_header

  printf '%s\n' "OBSERVE"
  _hal_line
  printf '%s\n' "  1) Brief"
  printf '%s\n' "  2) Audit"
  printf '%s\n' "  3) Release Brief"
  printf '%s\n' "  4) Repo Status"
  printf '%s\n' "  5) CI Status"
  printf '%s\n' "  6) Doctor Summary"
  printf '%s\n' "  7) Timeline"
  printf '%s\n' "  8) Timeline with details"
  printf '\n'

  printf '%s\n' "PLAN"
  _hal_line
  printf '%s\n' "  9) Fix Doctor Plan"
  printf '\n'

  printf '%s\n' "MEMORY"
  _hal_line
  printf '%s\n' " 10) Session Memory"
  printf '%s\n' " 11) Last Memory Item"
  printf '%s\n' " 12) Remember Note"
  printf '\n'

  printf '%s\n' "DEBUG"
  _hal_line
  printf '%s\n' " 13) Repos"
  printf '%s\n' " 14) Raw Intent Debug"
  printf '%s\n' " 15) Free HAL Prompt"
  printf '%s\n' " 16) Memory Path"
  printf '%s\n' "  h) Help"
  printf '%s\n' "  q) Back"
  _hal_line
  printf '\n'
  printf 'hal> '
}

_hal_remember() {
  _hal_header
  printf 'note> '
  local note=""
  read -r note
  [[ -z "${note// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" remember "$note"
  _hal_pause
}

_hal_raw_intent() {
  _hal_header
  printf 'raw> '
  local prompt=""
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" --raw-intent "$prompt"
  _hal_pause
}

_hal_free_prompt() {
  _hal_header
  printf 'hal> '
  local prompt=""
  read -r prompt
  [[ -z "${prompt// }" ]] && return 0
  printf '\n'
  "$MQ_HAL_BIN" "$prompt"
  _hal_pause
}

mq_hal_menu_main() {
  local choice

  if [[ ! -x "$MQ_HAL_BIN" ]]; then
    _hal_header
    printf '%s\n' "HAL backend not found: $MQ_HAL_BIN"
    printf '\n'
    printf '%s\n' "Check:"
    printf '  %s\n' "ls -l ~/mq-hal/bin/mq-hal"
    _hal_pause
    return 127
  fi

  while true; do
    _hal_menu_show
    read -r choice
    printf '\n'

    case "$choice" in
      1)  _hal_header; "$MQ_HAL_BIN" brief;            _hal_pause ;;
      2)  _hal_header; "$MQ_HAL_BIN" audit;            _hal_pause ;;
      3)  _hal_header; "$MQ_HAL_BIN" release-brief;    _hal_pause ;;
      4)  _hal_header; "$MQ_HAL_BIN" repo-status;      _hal_pause ;;
      5)  _hal_header; "$MQ_HAL_BIN" ci;               _hal_pause ;;
      6)  _hal_header; "$MQ_HAL_BIN" doctor-summary;   _hal_pause ;;
      7)  _hal_header; "$MQ_HAL_BIN" timeline;         _hal_pause ;;
      8)  _hal_header; "$MQ_HAL_BIN" timeline --details; _hal_pause ;;
      9)  _hal_header; "$MQ_HAL_BIN" fix-doctor;       _hal_pause ;;
      10) _hal_header; "$MQ_HAL_BIN" session;          _hal_pause ;;
      11) _hal_header; "$MQ_HAL_BIN" last;             _hal_pause ;;
      12) _hal_remember ;;
      13) _hal_header; "$MQ_HAL_BIN" --list-repos;     _hal_pause ;;
      14) _hal_raw_intent ;;
      15) _hal_free_prompt ;;
      16) _hal_header; "$MQ_HAL_BIN" memory-path;      _hal_pause ;;
      h|help)
          _hal_header; "$MQ_HAL_BIN" --help;           _hal_pause ;;
      q|quit|back|0|b|B|x|X) return 0 ;;
      "")  ;;
      *)
          printf 'Unknown choice: %s\n' "$choice"
          _hal_pause
          ;;
    esac
  done
}

if ! hal_menu_is_sourced; then
  mq_hal_menu_main "$@"
fi
