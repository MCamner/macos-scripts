#!/usr/bin/env bash
# `mqlaunch pulse` — the read-only operator cockpit.
#
# Collects, normalizes, renders, and points at existing commands. It owns no
# verdict of its own: every state on the screen came from a repo that publishes
# it, and every suggested command already exists. The rules are in
# docs/PULSE_CONTRACT.md and enforced in mqlaunch/lib/pulse/model.sh.
#
# Six collectors: system, repositories and MQ stack describe what the machine
# and the repos are; memory, Git/GitHub and quality describe what is going on.
# A collector that cannot reach its subject reports UNAVAILABLE and the run
# continues — one unreachable delegate must not take the other five with it.
set -uo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/collectors-state.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/render.sh"

usage() {
  cat <<'HELP'
Usage: mqlaunch pulse [--no-stack] [--no-network]

Read-only operator cockpit: system, repositories, MQ stack, memory,
Git/GitHub and the repo's own quality gates in one view.

Options:
  --no-stack     skip the mq-agent stack collector, which shells into
                 another repo
  --no-network   skip everything that talks to GitHub
  -h, --help     show this help

Both flags mark their area SKIPPED rather than dropping it: a run with a
flag must not look like a run where the subject was fine.

Exit codes: 0 healthy, 1 warnings, 2 failures, 3 pulse could not complete.
HELP
}

skip_stack=0
skip_network=0
for arg in "$@"; do
  case "$arg" in
    --no-stack)   skip_stack=1 ;;
    --no-network) skip_network=1 ;;
    -h|--help)    usage; exit 0 ;;
    --no-color)   : ;;  # parsed globally by the launcher; accepted here too
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
  # Memory reads mq-agent too, through `memory status` and the cockpit. Skipping
  # the stack collector and then spending two more mq-agent calls next to it
  # would make the flag a lie about what the run costs.
  pulse_item_add memory memory SKIPPED "Memory" "skipped by --no-stack"
else
  pulse_collect_stack
  pulse_collect_memory
fi

pulse_collect_git "$skip_network"
pulse_collect_quality

overall="$(pulse_overall_state < <(pulse_items_states))" || {
  printf 'ERROR: pulse could not determine a state\n' >&2
  exit 3
}

pulse_render "$overall"

exit "$(pulse_exit_code "$overall")"
