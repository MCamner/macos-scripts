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
Usage: mqlaunch pulse [scope] [--no-stack] [--no-network] [--verbose]

Read-only operator cockpit: system, repositories, MQ stack, memory,
Git/GitHub and the repo's own quality gates in one view.

Scopes (one area instead of all six):
  system      the environment and the tools mqlaunch shells out to
  repos       clean/dirty, branch and ahead/behind for the MQ repos
  stack       what mq-agent reports about the stack
  memory      semantic memory and stack-truth freshness
  git         worktree, unpushed commits, pull requests and CI
  quality     this repo's own gates, one verdict each
  attention   only what needs attention, from every area

Options:
  --no-stack     skip the mq-agent collectors, which shell into another repo
  --no-network   skip everything that talks to GitHub
  --verbose      show the evidence behind each row
  -h, --help     show this help

Both skip flags mark their area SKIPPED rather than dropping it: a run
with a flag must not look like a run where the subject was fine.

Exit codes: 0 healthy, 1 warnings, 2 failures, 3 pulse could not complete.
A scoped run reports on its scope — `pulse quality` exits 0 when the gates
pass, whatever the rest of the machine looks like.
HELP
}

skip_stack=0
skip_network=0
scope=""

for arg in "$@"; do
  case "$arg" in
    --no-stack)   skip_stack=1 ;;
    --no-network) skip_network=1 ;;
    --verbose)    PULSE_VERBOSE=1 ;;
    -h|--help)    usage; exit 0 ;;
    --no-color)   : ;;  # parsed globally by the launcher; accepted here too
    system|repos|stack|memory|git|quality|attention)
      if [[ -n "$scope" ]]; then
        printf 'ERROR: mqlaunch pulse takes one scope, got %s and %s\n' "$scope" "$arg" >&2
        exit 2
      fi
      scope="$arg"
      ;;
    *)
      printf 'ERROR: unknown mqlaunch pulse argument: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done
export PULSE_VERBOSE="${PULSE_VERBOSE:-0}"

# Whether an area's collector runs for this invocation.
#
# `attention` is not an area — it is a view over all of them, so it needs the
# whole run collected and only changes what is rendered. Scoping it to one
# collector would make the most important screen the least informed.
wanted() {
  [[ -z "$scope" || "$scope" == "attention" || "$scope" == "$1" ]]
}

pulse_items_reset

wanted system && pulse_collect_system
wanted repos && pulse_collect_repos

if wanted stack || wanted memory; then
  if [[ $skip_stack -eq 1 ]]; then
    # SKIPPED, not omitted. The operator asked for this, so it must not count
    # against the verdict — and it must still be visible, or a run with the flag
    # would look like a run where the stack was fine.
    wanted stack && pulse_item_add stack stack SKIPPED "MQ stack" "skipped by --no-stack"
    # Memory reads mq-agent too, through `memory status` and the cockpit.
    # Skipping the stack collector and then spending two more mq-agent calls
    # next to it would make the flag a lie about what the run costs.
    wanted memory && pulse_item_add memory memory SKIPPED "Memory" "skipped by --no-stack"
  else
    wanted stack && pulse_collect_stack
    wanted memory && pulse_collect_memory
  fi
fi

wanted git && pulse_collect_git "$skip_network"
wanted quality && pulse_collect_quality

overall="$(pulse_overall_state < <(pulse_items_states))" || {
  printf 'ERROR: pulse could not determine a state\n' >&2
  exit 3
}

if [[ "$scope" == "attention" ]]; then
  pulse_render_attention_only "$overall"
else
  pulse_render "$overall"
fi

exit "$(pulse_exit_code "$overall")"
