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
# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/document.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/cache.sh"

usage() {
  cat <<'HELP'
Usage: mqlaunch pulse [scope] [--json|--plain] [--no-stack] [--no-network] [--verbose]

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
  --json         print the mq.pulse.v1 document instead of the panel
  --plain        one tab-separated line per item, no panel and no colour
  --no-stack     skip the mq-agent collectors, which shell into another repo
  --no-network   skip everything that talks to GitHub
  --verbose      show the evidence behind each row
  -h, --help     show this help

Both skip flags mark their area SKIPPED rather than dropping it: a run
with a flag must not look like a run where the subject was fine.

Exit codes: 0 healthy, 1 warnings, 2 failures, 3 pulse could not complete.
The exit code is the same in every output mode. A scoped run reports on its
scope — `pulse quality` exits 0 when the gates pass, whatever the rest of the
machine looks like.
HELP
}

skip_stack=0
skip_network=0
scope=""
mode="panel"

for arg in "$@"; do
  case "$arg" in
    --no-stack)   skip_stack=1 ;;
    --no-network) skip_network=1 ;;
    --verbose)    PULSE_VERBOSE=1 ;;
    --json|--plain)
      # Refused rather than resolved by precedence. Two output modes on one
      # command line is a caller who does not know what they will get, and
      # picking one for them is how a pipeline ends up parsing the other.
      if [[ "$mode" != "panel" ]]; then
        printf 'ERROR: mqlaunch pulse takes one output mode, got --%s and %s\n' \
          "$mode" "$arg" >&2
        exit 2
      fi
      mode="${arg#--}"
      ;;
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

# Stamped before the first collector, not after the last one.
#
# The run takes seconds, so the two differ by exactly how long collection took,
# and a consumer deciding whether a document is still worth reusing reads this
# number. Understating the age is the direction that quietly hands back a stale
# answer, so the stamp names the oldest observation in the document rather than
# the youngest. tests/pulse-freshness-smoke.sh holds it with a deliberately slow
# gate.
# Read by document.sh and render.sh, which shellcheck cannot see from here.
# shellcheck disable=SC2034
PULSE_COLLECTED_AT="$(pulse_timestamp)" || {
  printf 'ERROR: pulse could not read the clock\n' >&2
  exit 3
}

# The flags as declared, so the document records the invocation rather than what
# it happened to touch — see pulse_document. Globals rather than parameters, for
# the reason given there: they describe the run, not any one item.
# shellcheck disable=SC2034
PULSE_NO_STACK="$skip_stack"
# shellcheck disable=SC2034
PULSE_NO_NETWORK="$skip_network"

# The areas this run accounted for, in collection order.
#
# It is recorded here rather than derived from the items, because a collector
# that ran and produced nothing and a collector that never ran are different
# facts and only this file knows which happened. `mq.pulse.v1` publishes the
# list so that a consumer reading a scoped document cannot mistake an absent
# section for a healthy area — docs/PULSE_CONTRACT.md, "What absence means".
collected=()
note() { collected+=("$1"); }

# The stack and memory collectors, in one lane and in that order.
#
# They are the pair the serial rule is actually about: both shell into mq-agent
# through the same `uv` project, so they stay sequential with respect to each
# other while running alongside everything else. Running them concurrently would
# put two processes into one project environment to save a second, which is a
# trade this command does not need to make.
agent_lane() {
  wanted stack && pulse_collect_stack
  wanted memory && pulse_collect_memory
  return 0
}

# Five lanes, launched together and read back in list order.
#
# Before this, a full run cost the sum of six delegates — 3853 ms measured, of
# which the four calls into other repos were most of it. The lanes make it the
# slowest lane instead, and the slowest lane is the mq-agent pair.
#
# `collected` is still recorded here, in the parent, and still in list order. It
# says which areas this run accounted for, and that is a fact about the
# invocation rather than about who finished first.
lanes="$(mktemp -d)"

if wanted system; then
  note system
  pulse_area_probe "$lanes/system" pulse_collect_system &
fi

if wanted repos; then
  note repositories
  pulse_area_probe "$lanes/repositories" pulse_collect_repos &
fi

agent_skipped=0
if wanted stack || wanted memory; then
  if [[ $skip_stack -eq 1 ]]; then
    # SKIPPED, not omitted. The operator asked for this, so it must not count
    # against the verdict — and it must still be visible, or a run with the flag
    # would look like a run where the stack was fine.
    #
    # No lane: there is nothing to run, and the items are added below so they
    # land in the same place in the order as the collected ones would have.
    agent_skipped=1
    wanted stack && note stack
    # Memory reads mq-agent too, through `memory status` and the cockpit.
    # Skipping the stack collector and then spending two more mq-agent calls
    # next to it would make the flag a lie about what the run costs.
    wanted memory && note memory
  else
    wanted stack && note stack
    wanted memory && note memory
    pulse_area_probe "$lanes/agent" agent_lane &
  fi
fi

if wanted git; then
  note git
  pulse_area_probe "$lanes/git" pulse_collect_git "$skip_network" &
fi

if wanted quality; then
  note quality
  pulse_area_probe "$lanes/quality" pulse_collect_quality &
fi

# The lanes report through their files. A non-zero job status here would only be
# the shell's opinion about a collector whose findings have already been written,
# which is the same reason pulse_collect_quality ignores it one level down.
wait 2>/dev/null || true

pulse_area_absorb "$lanes/system"
pulse_area_absorb "$lanes/repositories"
if [[ $agent_skipped -eq 1 ]]; then
  wanted stack && pulse_item_add stack stack SKIPPED "MQ stack" "skipped by --no-stack"
  wanted memory && pulse_item_add memory memory SKIPPED "Memory" "skipped by --no-stack"
else
  pulse_area_absorb "$lanes/agent"
fi
pulse_area_absorb "$lanes/git"
pulse_area_absorb "$lanes/quality"

rm -rf "$lanes"

overall="$(pulse_overall_state < <(pulse_items_states))" || {
  printf 'ERROR: pulse could not determine a state\n' >&2
  exit 3
}

# The document is built once and used up to twice — printed by --json, kept by
# the cache — so a run that needs both does not serialize the same items twice.
#
# It is built at all only when something wants it. A scoped or flagged panel run
# is not worth keeping and is not being printed, and making every `mqlaunch
# pulse quality` pay for a python3 serialization nobody reads would be this
# command charging for a feature it is not delivering.
document=""
if [[ "$mode" == "json" ]] || pulse_cache_keeps "$scope" "$PULSE_NO_STACK" "$PULSE_NO_NETWORK"; then
  document="$(pulse_document "$overall" "$scope" ${collected+"${collected[@]}"})" || document=""
  if [[ -z "$document" && "$mode" == "json" ]]; then
    printf 'ERROR: pulse could not serialize the run\n' >&2
    exit 3
  fi
  # A panel run that could not serialize still has a screen to draw. The cache is
  # an optimization, and losing it costs the next reader 4s rather than an answer.
  if [[ -n "$document" ]] && pulse_cache_keeps "$scope" "$PULSE_NO_STACK" "$PULSE_NO_NETWORK"; then
    printf '%s\n' "$document" | pulse_cache_store
  fi
fi

case "$mode" in
  json)
    # Stdout carries the document and nothing else. Everything a collector had
    # to say about a delegate went to stderr on the way here, per
    # docs/RUNTIME_AUTHORITY.md: a consumer piping into jq must not have to
    # filter a banner out first.
    printf '%s\n' "$document"
    ;;
  plain)
    if [[ "$scope" == "attention" ]]; then
      # The scope decides which items, the mode decides the shape. Attention
      # narrows to the findings here exactly as it does on the panel, and the
      # engine still does the ordering.
      plain_items=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && plain_items+=("$line")
      done < <(pulse_attention_list)
      pulse_render_plain "$overall" ${plain_items+"${plain_items[@]}"}
    else
      pulse_render_plain "$overall" ${PULSE_ITEMS+"${PULSE_ITEMS[@]}"}
    fi
    ;;
  *)
    if [[ "$scope" == "attention" ]]; then
      pulse_render_attention_only "$overall"
    else
      pulse_render "$overall"
    fi
    ;;
esac

exit "$(pulse_exit_code "$overall")"
