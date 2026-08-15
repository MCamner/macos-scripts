#!/usr/bin/env bash
# `mqlaunch pulse` — the read-only operator cockpit.
#
# Collects, normalizes, renders, and points at existing commands. It owns no
# verdict of its own: every state on the screen came from a repo that publishes
# it, and every suggested command already exists. The rules are in
# docs/PULSE_CONTRACT.md and enforced in mqlaunch/lib/pulse/model.sh.
#
# This release carries the three core collectors — system, repositories and MQ
# stack. Memory, Git/GitHub and quality are later blocks; they are absent rather
# than stubbed, because a collector that reports nothing and a subject that is
# healthy must never look the same.
set -uo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/collectors.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/render.sh"

usage() {
  cat <<'HELP'
Usage: mqlaunch pulse [--no-stack]

Read-only operator cockpit: system, repositories and MQ stack in one view.

Options:
  --no-stack   skip the mq-agent stack collector, which shells into another
               repo and is the slow one
  -h, --help   show this help

Exit codes: 0 healthy, 1 warnings, 2 failures, 3 pulse could not complete.
HELP
}

skip_stack=0
for arg in "$@"; do
  case "$arg" in
    --no-stack) skip_stack=1 ;;
    -h|--help)  usage; exit 0 ;;
    --no-color) : ;;  # parsed globally by the launcher; accepted here too
    *)
      printf 'ERROR: unknown mqlaunch pulse flag: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

pulse_items_reset

pulse_collect_system
pulse_collect_repos

if [[ $skip_stack -eq 1 ]]; then
  # SKIPPED, not omitted. The operator asked for this, so it must not count
  # against the verdict — and it must still be visible, or a run with the flag
  # would look like a run where the stack was fine.
  pulse_item_add stack stack SKIPPED "MQ stack" "skipped by --no-stack"
else
  pulse_collect_stack
fi

overall="$(pulse_overall_state < <(pulse_items_states))" || {
  printf 'ERROR: pulse could not determine a state\n' >&2
  exit 3
}

pulse_render "$overall"

exit "$(pulse_exit_code "$overall")"
