#!/usr/bin/env bash
# demo-flow — MQ stack end-to-end demo: signal → review → release-check → brain
set -euo pipefail

MQ_AGENT_BIN="${MQ_AGENT_BIN:-$HOME/mq-agent}"

# Coordinates run agent behavior.
_run_agent() {
  (cd "$MQ_AGENT_BIN" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$MQ_AGENT_BIN" run mq-agent "$@")
}

TARGET="${1:-.}"

printf '\n\033[1;36m── MQ Demo Flow ──────────────────────────────────────────\033[0m\n'
printf '\033[0;37mTarget: %s\033[0m\n\n' "$TARGET"

printf '\033[1;33m[1/3] repo-signal readiness → brain\033[0m\n'
_run_agent signal "$TARGET" --brain

printf '\n\033[1;33m[2/3] review repo → brain\033[0m\n'
_run_agent review repo "$TARGET" --brain

printf '\n\033[1;33m[3/3] release-check (contract gate)\033[0m\n'
_run_agent release-check --dry-run

printf '\n\033[1;32m── Demo flow complete ────────────────────────────────────\033[0m\n'
