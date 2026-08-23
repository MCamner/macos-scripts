#!/usr/bin/env bash
# `mqlaunch next` — one deterministic next action.
#
# The CLI layer over the selector in mqlaunch/lib/next/select.sh. The division
# is the point, and docs/NEXT_CONTRACT.md states it:
#
#   the CLI layer may produce the pulse document
#   the selector never does
#
# So `mqlaunch next` with no arguments collects fresh Pulse state itself — a
# command that required the operator to run `mqlaunch pulse --json > file` first
# would be a library contract wearing a command's name. `--input FILE` is there
# for a caller that already has a document and should not pay for the collection
# twice.
set -uo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/next/select.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/next/render.sh"
# shellcheck source=/dev/null
source "$BASE_DIR/mqlaunch/lib/pulse/cache.sh"

# How old a document may be before this command re-measures instead of reusing.
#
# The tolerance is declared here, by the reader, and that is the whole shape of
# the freshness contract rather than an implementation detail:
#
#   Pulse publishes the age    it cannot know what the answer is for
#   next declares its window   it knows exactly what it is about to answer
#
# Two minutes is sized to the flow this reuse exists for — look at the cockpit,
# then ask what to do about it. Past that the operator has done something in
# between, which is the point at which an observation of the machine as it was
# stops answering a question about the machine as it is. Overridable, because a
# script driving both commands back to back and a person leaving a terminal open
# are not the same reader.
NEXT_MAX_AGE="${NEXT_MAX_AGE:-120}"

usage() {
  cat <<'HELP'
Usage: mqlaunch next [--input FILE] [--fresh] [--json] [-h|--help]

The single next thing to do, selected from what Pulse already prioritized.
With no arguments it reuses the last complete Pulse run when that run is
recent enough, and collects fresh state otherwise.

Options:
  --input FILE   select from an existing mq.pulse.v1 document instead of
                 collecting, for a caller that already ran Pulse
  --fresh        collect now, whatever the last run left behind
  --json         print the mq.next.v1 document instead of the screen
  --plain        one tab-separated row, no panel and no colour:
                 status, item_status, area, subject, summary, next_command
  -h, --help     show this help

A document is reused only when it is a complete run — full scope, neither
skip flag — and younger than NEXT_MAX_AGE seconds (120 by default). A run
made under --no-network answers a narrower question and never stands in for
a full one. Reuse is always visible on the screen, with the age, and
`collected_at` in the machine document says how old the observation is
whether it was reused or not.

This command ranks nothing. The answer is the head of Pulse's attention
list, whatever it is — including an UNAVAILABLE, which means an area stopped
being measured and is the next thing to look at. Reordering here would make
two commands in this repo disagree about what matters most.

Exit codes:
  0  nothing needs attention in what was collected
  1  the selected item is WARN or UNAVAILABLE
  2  the selected item is FAIL
  3  the pulse document could not be read, or the run measured nothing

3 is this command failing at its own job, not a verdict about the machine.
"Pulse measured nothing" and "nothing needs attention" are different answers
and never collapse into one.
HELP
}

json_mode=0
plain_mode=0
fresh=0
input=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      json_mode=1
      shift
      ;;
    --fresh)
      fresh=1
      shift
      ;;
    --plain)
      plain_mode=1
      shift
      ;;
    --input)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        printf 'next: --input needs a file\n' >&2
        exit 2
      fi
      input="$2"
      shift 2
      ;;
    --input=*)
      input="${1#--input=}"
      if [[ -z "$input" ]]; then
        printf 'next: --input needs a file\n' >&2
        exit 2
      fi
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      # A usage error is 2, the same as everywhere else in this surface. It is
      # deliberately not 3: 3 means the command could not read Pulse, and a
      # typo is not an observation gap.
      printf 'next: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

document="$work/pulse.json"

# Set when the answer came from a document this run did not collect, so the
# screen can say so. Rendering reused state as live state is the one thing this
# block must not do — v2.1.0 held that box open as a condition on any cache, and
# it is an acceptance criterion here rather than a separate item.
reused_age=""

if [[ -n "$input" ]]; then
  # A caller that named a document gets that document, whatever the cache holds
  # and whatever age it is. The cache is neither read nor written here: writing
  # it would let any caller install an arbitrary document as this machine's last
  # observation.
  document="$input"
else
  if [[ $fresh -eq 0 ]]; then
    reused_age="$(next_reusable_age "$(pulse_cache_path)" "$NEXT_MAX_AGE")" || reused_age=""
    if [[ -n "$reused_age" ]]; then
      document="$(pulse_cache_path)"
    fi
  fi
fi

if [[ -z "$input" && -z "$reused_age" ]]; then
  # Pulse's exit code is a verdict about the machine — 1 means it found
  # warnings, 2 means it found failures — and a run that exits 1 or 2 has still
  # produced a complete, valid document. Treating that as a failure to collect
  # would make `mqlaunch next` answer UNAVAILABLE exactly when there was
  # something to report, which is the one case it exists for.
  #
  #   wrong:  mqlaunch pulse --json > "$document" || exit $?
  #
  # The exit code is deliberately dropped. What Pulse produced is the only
  # input, and whether it is usable is decided by parsing it, not by $?.
  "$BASE_DIR/tools/scripts/pulse.sh" --json > "$document" 2>"$work/pulse.err" || true

  if [[ ! -s "$document" ]]; then
    # An empty document is not a quiet NONE. Pulse produced nothing, which is a
    # gap in the observation, and the stderr it left behind is the diagnostic.
    if [[ -s "$work/pulse.err" ]]; then
      cat "$work/pulse.err" >&2
    fi
    printf 'next: pulse produced no document\n' >&2
  fi
fi

selected="$work/next.json"
# Not `status`. This file is bash, where the name is ordinary, but the trap
# documented in skills/mqlaunch-command-surface is one `source` away: in zsh
# `status` is read-only and assigning to it aborts the enclosing function.
next_select "$document" > "$selected" 2>"$work/select.err"
select_status=$?

if [[ -s "$work/select.err" ]]; then
  cat "$work/select.err" >&2
fi

if [[ "$json_mode" -eq 1 && "$plain_mode" -eq 1 ]]; then
  # Two machine formats named at once is a caller that has not decided which one
  # it parses. Picking one silently would make the other's absence look like a
  # bug in this command.
  printf 'next: --json and --plain are two different formats; pick one\n' >&2
  exit 2
fi

if [[ "$json_mode" -eq 1 ]]; then
  cat "$selected"
elif [[ "$plain_mode" -eq 1 ]]; then
  next_render_plain "$selected"
else
  next_render "$selected"
  # On the human screen only. The machine modes carry the same fact as
  # `collected_at` in the document, where a consumer can read it without parsing
  # a sentence, and a notice on stdout would break `--json` being one document.
  if [[ -n "$reused_age" ]]; then
    next_render_reuse_notice "$reused_age"
  fi
fi

exit "$select_status"
