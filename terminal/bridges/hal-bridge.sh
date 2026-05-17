#!/usr/bin/env bash

# MQ HAL bridge
# Thin bridge from mqlaunch to ~/mq-hal.
#
# Rule:
#   mqlaunch owns UX.
#   mq-hal owns HAL logic.

if [[ -z "${BASE_DIR:-}" ]]; then
  BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
fi

MQ_HAL_BIN="${MQ_HAL_BIN:-$HOME/mq-hal/bin/mq-hal}"

mq_hal_available() {
  [[ -x "$MQ_HAL_BIN" ]]
}

mq_hal_usage() {
  cat <<'USAGE'
MQ HAL — local Ollama command router

Usage:
  mqlaunch hal                         # open HAL menu
  mqlaunch hal brief                   # compact repo status brief
  mqlaunch hal release-brief           # release readiness brief
  mqlaunch hal audit                   # publish quality + README score via repo-signal
  mqlaunch hal doctor                  # doctor summary
  mqlaunch hal fix-doctor              # safe fix plan
  mqlaunch hal timeline                # session timeline
  mqlaunch hal timeline --details      # session timeline with details
  mqlaunch hal session                 # session memory
  mqlaunch hal last                    # latest memory item
  mqlaunch hal remember "note"         # save memory note
  mqlaunch hal repos                   # list HAL-known repos
  mqlaunch hal raw "kör doctor"        # show parsed JSON intent
  mqlaunch hal "visa git status"       # free HAL prompt

Requirements:
  ~/mq-hal/bin/mq-hal
  Ollama running locally for AI-backed commands
  qwen3:4b-instruct pulled, or OLLAMA_MODEL set
USAGE
}

mq_hal_missing() {
  echo "ERROR: mq-hal not found or not executable: $MQ_HAL_BIN" >&2
  echo >&2
  echo "Check:" >&2
  echo "  ls -l ~/mq-hal/bin/mq-hal" >&2
  echo "  ~/mq-hal/bin/mq-hal --list-repos" >&2
  return 127
}

mq_hal_main() {
  if ! mq_hal_available; then
    mq_hal_missing
    return $?
  fi

  local sub="${1:-}"

  case "$sub" in
    "")
      # shellcheck source=/dev/null
      source "$BASE_DIR/terminal/menus/mq-hal-menu.sh"
      mq_hal_menu_main
      ;;

    -h|--help|help)
      mq_hal_usage
      ;;

    audit)
      shift || true
      "$MQ_HAL_BIN" audit "$@"
      ;;

    brief)
      shift || true
      "$MQ_HAL_BIN" brief "$@"
      ;;

    release-brief|release)
      shift || true
      "$MQ_HAL_BIN" release-brief "$@"
      ;;

    repo-status|repo)
      shift || true
      "$MQ_HAL_BIN" repo-status "$@"
      ;;

    ci|ci-status)
      shift || true
      "$MQ_HAL_BIN" ci "$@"
      ;;

    doctor|doctor-summary|summary)
      shift || true
      "$MQ_HAL_BIN" doctor-summary "$@"
      ;;

    fix-doctor|doctor-fix|fix-planner|plan-fix)
      shift || true
      "$MQ_HAL_BIN" fix-doctor "$@"
      ;;

    session|memory)
      shift || true
      "$MQ_HAL_BIN" session "$@"
      ;;

    last)
      shift || true
      "$MQ_HAL_BIN" last "$@"
      ;;

    remember)
      shift || true
      "$MQ_HAL_BIN" remember "$@"
      ;;

    timeline)
      shift || true
      "$MQ_HAL_BIN" timeline "$@"
      ;;

    memory-path|session-path)
      shift || true
      "$MQ_HAL_BIN" memory-path "$@"
      ;;

    repos|list|list-repos|--list-repos)
      "$MQ_HAL_BIN" --list-repos
      ;;

    cd)
      shift || true
      if [[ $# -ne 1 ]]; then
        echo "usage: mqlaunch hal cd <repo-name>" >&2
        return 2
      fi
      "$MQ_HAL_BIN" --cd "$1"
      ;;

    raw|intent|--raw-intent)
      shift || true
      if [[ $# -lt 1 ]]; then
        echo 'usage: mqlaunch hal raw "your prompt"' >&2
        return 2
      fi
      "$MQ_HAL_BIN" --raw-intent "$*"
      ;;

    *)
      "$MQ_HAL_BIN" "$*"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  mq_hal_main "$@"
fi
