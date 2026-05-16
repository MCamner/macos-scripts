#!/usr/bin/env bash

MQ_HAL_BIN="${MQ_HAL_BIN:-$HOME/mq-hal/bin/mq-hal}"

_mq_hal_check() {
  if [[ ! -x "$MQ_HAL_BIN" ]]; then
    echo "${C_ERR:-}ERROR: mq-hal not found or not executable: $MQ_HAL_BIN${C_RESET:-}" >&2
    echo "Install: git clone https://github.com/MCamner/mq-hal.git ~/mq-hal" >&2
    return 127
  fi
}

# Routes natural language or subcommands to mq-hal.
mq_hal_run() {
  _mq_hal_check || return $?

  local sub="${1:-}"

  case "$sub" in
    ""|-h|--help|help)
      cat <<'USAGE'
mqlaunch hal — local Ollama command router

Usage:
  mqlaunch hal "visa git status i macos-scripts"
  mqlaunch hal "kör doctor"
  mqlaunch hal "visa senaste commits i repo-signal"
  mqlaunch hal repos
  mqlaunch hal cd <repo-name>
  mqlaunch hal raw "kör release-check"
  mqlaunch hal doctor
USAGE
      ;;
    repos|list|list-repos)
      "$MQ_HAL_BIN" --list-repos
      ;;
    cd)
      shift
      if [[ $# -ne 1 ]]; then
        echo "usage: mqlaunch hal cd <repo-name>" >&2
        return 2
      fi
      "$MQ_HAL_BIN" --cd "$1"
      ;;
    doctor|doctor-summary|summary)
      shift || true
      "$MQ_HAL_BIN" doctor-summary "$@"
      ;;
    raw|intent)
      shift
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
