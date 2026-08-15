#!/usr/bin/env bash
# Pulse core collectors — system, repositories, MQ stack.
#
# Each one runs a read-only command this repo already has, reads its machine
# output, and turns it into Pulse items. None of them derives a verdict: where
# a delegate publishes one, it is mapped; where it does not, the collector says
# so with UNAVAILABLE rather than guessing. That is the line
# docs/PULSE_CONTRACT.md draws between normalization and domain logic.
#
# Every collector is read-only, and every one of them is bounded by a timeout.
# A status command that hangs is worse than one that reports a gap: the stack
# collector shells into another repo through `uv`, which on a cold cache takes
# long enough that an operator would reach for Ctrl-C. The bounds are sized from
# measurement below, and a spent bound reports UNAVAILABLE with the timeout
# named — never FAIL on the subject that was being looked at.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/item.sh"

# The budgets, in seconds. Each one is a ceiling on a hang, not a performance
# target: a collector that finishes in 130 ms and one that finishes in 3 s are
# both fine, and a collector that never finishes is not.
#
# Sized from measurement rather than taste — the numbers are in ROADMAP.md under
# "Pulse performance and degradation", taken on an M-series Mac with a warm uv
# cache:
#
#   doctor 132 ms · repos 519 ms · quality gate ~270 ms each
#   mq-agent 1.2–1.5 s per call · gh ~800 ms per call
#
# The multiplier is deliberately large. `uv` on a cold cache is slower than
# anything measured here by an order of magnitude, and cutting a first run off
# would make Pulse look broken exactly once per dependency change — so the stack
# budget keeps room for it while still bounding a hang.
PULSE_COLLECTOR_TIMEOUT="${PULSE_COLLECTOR_TIMEOUT:-10}"
PULSE_STACK_TIMEOUT="${PULSE_STACK_TIMEOUT:-30}"

# The exit status `timeout` reports when it kills the command it was given.
PULSE_TIMEOUT_STATUS=124

# Runs a command with a wall-clock bound, whichever timeout binary exists.
#
# macOS ships neither `timeout` nor `gtimeout` by default — coreutils provides
# them — so the fallback runs the command unbounded rather than failing outright.
# A machine without coreutils still gets Pulse; it just does not get the bound,
# which is stated here rather than discovered.
pulse_run_bounded() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  else
    "$@"
  fi
}

# Why a delegate produced nothing, in the words the item will carry.
#
#   pulse_gap_reason STATUS FALLBACK [SECONDS]
#
# A spent budget is a fact about the observation, never about the subject:
#
#   timeout  is not  FAIL on the subject
#   timeout  is      UNAVAILABLE on the observation
#
# GitHub taking too long to answer does not mean CI is broken, and a gate that
# was killed at its budget is not a gate that failed. Every collector reports
# UNAVAILABLE for both cases and uses this to say which one happened, so an
# operator can tell "could not ask" from "asked, got nothing".
pulse_gap_reason() {
  local gap_status="$1" fallback="$2" seconds="${3:-$PULSE_COLLECTOR_TIMEOUT}"
  if [[ "$gap_status" -eq "$PULSE_TIMEOUT_STATUS" ]]; then
    printf 'timed out after %ss' "$seconds"
  else
    printf '%s' "$fallback"
  fi
}

# Milliseconds since the epoch, for the optional duration metadata.
#
# bash 5 publishes the clock as a variable, which costs no process at all. That
# matters here because this is called twice per collector: fifteen python3
# spawns measured 287 ms, which was 16% of a local-only run spent asking what
# time it was.
#
# The fallback covers bash 3.2, a zsh without `zsh/datetime`, and any locale
# whose decimal separator is not a point — `date +%s%3N` is a GNU extension and
# prints a literal "3N" on macOS, so python3 is what is left, and it is already
# a dependency of every other part of Pulse.
pulse_now_ms() {
  local now="${EPOCHREALTIME:-}"
  if [[ -n "$now" && "$now" == *.* ]]; then
    printf '%s' "$(( ${now%.*} * 1000 + 10#${now#*.} / 1000 ))"
    return 0
  fi
  python3 -c 'import time; print(int(time.time() * 1000))'
}

# SYSTEM — the environment and the tools mqlaunch shells out to.
#
# Reads `tools/scripts/doctor.sh --json`, which already owns these checks, their
# hints and their verdict. Doctor's own exit code is deliberately ignored: it is
# 1 whenever anything needs attention, which is a fact this collector is reading
# out of the document rather than a failure of the collection.
pulse_collect_system() {
  local doctor="$BASE_DIR/tools/scripts/doctor.sh"
  local started ended
  started="$(pulse_now_ms)"

  if [[ ! -x "$doctor" ]]; then
    pulse_item_add doctor system UNAVAILABLE "Environment" \
      "doctor is not runnable" \
      evidence="$doctor" \
      next_command="mqlaunch doctor"
    return 0
  fi

  local document read_status=0
  # The status is captured rather than discarded, but it is only consulted when
  # the document is empty. `doctor --json` exits 1 whenever any check needs
  # attention — the common case — and that is doctor's verdict about the
  # machine, which this collector takes from the document. What the status is
  # needed for is the other case: telling a spent budget apart from a delegate
  # that answered with nothing.
  document="$(pulse_run_bounded "$PULSE_COLLECTOR_TIMEOUT" bash "$doctor" --json 2>/dev/null)" \
    || read_status=$?
  ended="$(pulse_now_ms)"

  if [[ -z "$document" ]]; then
    pulse_item_add doctor system UNAVAILABLE "Environment" \
      "$(pulse_gap_reason "$read_status" "doctor produced no report")" \
      next_command="mqlaunch doctor" \
      duration_ms="$((ended - started))"
    return 0
  fi

  # One item per doctor status class rather than one per check: twelve rows for
  # twelve tools is doctor's own screen, and Pulse exists to be shorter than the
  # commands it summarises. The failing names are carried in the summary, so
  # nothing an operator needs is dropped.
  local parsed
  parsed="$(printf '%s' "$document" | python3 -c '
import json, sys

try:
    doc = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

checks = doc.get("checks", [])
bad = [c for c in checks if c.get("status") != "ok"]
status = "PASS" if not bad else ("FAIL" if any(c.get("status") == "fail" for c in bad) else "WARN")
names = ", ".join(c.get("name", "?") for c in bad[:4])
if len(bad) > 4:
    names += f", and {len(bad) - 4} more"
summary = f"{len(checks) - len(bad)} of {len(checks)} checks pass"
detail = f"needs attention: {names}" if bad else ""
print(status)
print(summary)
print(detail)
print(doc.get("next") or "")
')"

  if [[ "$parsed" == "PARSE" ]]; then
    pulse_item_add doctor system UNAVAILABLE "Environment" \
      "doctor output was not readable" \
      next_command="mqlaunch doctor" \
      duration_ms="$((ended - started))"
    return 0
  fi

  # Each read is allowed to fail, and the reason is not defensiveness. The last
  # two lines are optional — a healthy machine has no failing names and doctor
  # may report no next step — and `$(...)` strips the trailing newline, so the
  # final `read` meets EOF and returns 1. Under `set -e` in the caller that
  # ended the run silently, on the healthiest input the collector can get.
  #
  # `check_status` rather than `status`: this is sourced material, and `status`
  # is a read-only variable in zsh, which is what the launcher is written in.
  local check_status summary detail next
  {
    read -r check_status || true
    read -r summary || true
    read -r detail || true
    read -r next || true
  } <<< "$parsed"

  local -a extra=(duration_ms="$((ended - started))")
  [[ -n "$detail" ]] && extra+=(evidence="$detail")
  [[ -n "$next" ]] && extra+=(next_command="$next")

  pulse_item_add doctor system "$check_status" "Environment" "$summary" "${extra[@]}"
}

# REPOSITORIES — clean/dirty, branch, and ahead/behind for the known MQ repos.
#
# Reads `tools/scripts/mq-repos.py status --json`, which is the same code path
# `mqlaunch repos status` prints from, so Pulse and that command cannot disagree
# about what dirty means.
pulse_collect_repos() {
  local repos="$BASE_DIR/tools/scripts/mq-repos.py"
  local started ended
  started="$(pulse_now_ms)"

  if [[ ! -f "$repos" ]]; then
    pulse_item_add repos repositories UNAVAILABLE "Repositories" \
      "mq-repos.py is missing" \
      evidence="$repos"
    return 0
  fi

  local document read_status=0
  document="$(pulse_run_bounded "$PULSE_COLLECTOR_TIMEOUT" python3 "$repos" status --json 2>/dev/null)" \
    || read_status=$?
  ended="$(pulse_now_ms)"

  if [[ -z "$document" ]]; then
    pulse_item_add repos repositories UNAVAILABLE "Repositories" \
      "$(pulse_gap_reason "$read_status" "repo status produced no report")" \
      next_command="mqlaunch repos status" \
      duration_ms="$((ended - started))"
    return 0
  fi

  # One item per repo that needs attention, plus one summary item for the rest.
  # A row per clean repo is what `mqlaunch repos status` is for.
  local rows
  rows="$(printf '%s' "$document" | python3 -c '
import json, sys

try:
    doc = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

repos = doc.get("repos", [])
clean = []
for repo in repos:
    name = repo.get("name", "?")
    if not repo.get("git"):
        print(f"UNAVAILABLE\t{name}\tnot a git repo\t")
        continue
    branch = repo.get("branch", "?")
    ahead, behind = repo.get("ahead"), repo.get("behind")
    modified = repo.get("modified", 0)
    untracked = repo.get("untracked", 0)
    notes = []
    if not repo.get("clean"):
        notes.append(f"{modified} modified, {untracked} untracked")
    if ahead:
        notes.append(f"{ahead} ahead")
    if behind:
        notes.append(f"{behind} behind")
    if repo.get("upstream") == "no-upstream":
        notes.append("no upstream")
    if notes:
        print(f"WARN\t{name}\t{branch} · " + ", ".join(notes) + "\t")
    else:
        clean.append(name)

print(f"CLEAN\t{len(clean)}\t{len(repos)}\t")
'
)"

  if [[ "$rows" == PARSE* ]]; then
    pulse_item_add repos repositories UNAVAILABLE "Repositories" \
      "repo status output was not readable" \
      next_command="mqlaunch repos status" \
      duration_ms="$((ended - started))"
    return 0
  fi

  local state subject summary rest
  while IFS=$'\t' read -r state subject summary rest; do
    [[ -z "$state" ]] && continue
    if [[ "$state" == "CLEAN" ]]; then
      pulse_item_add repos repositories PASS "Repositories" \
        "$subject of $summary repos clean" \
        duration_ms="$((ended - started))"
      continue
    fi
    # The dedupe key names the thing observed, not the collector that saw it.
    # The Git collector reads the same worktree from the other end — it looks at
    # the repo mqlaunch is running in, which is one of the repos walked here —
    # and both use `worktree:<repo>` so the attention list raises it once.
    pulse_item_add repos repositories "$state" "$subject" "$summary" \
      next_command="mqlaunch repos status" \
      dedupe_key="worktree:$subject"
  done <<< "$rows"
}

# MQ STACK — whether each repo in the stack is present and what mq-agent says
# about it.
#
# `mq-agent stack status --json` is the canonical stack truth, and mqlaunch
# delegates to it rather than deriving a second one. When mq-agent is not
# installed the whole area is UNAVAILABLE — one item, not five guesses.
pulse_collect_stack() {
  local agent_home="${MQ_AGENT_BIN:-$HOME/mq-agent}"
  local started ended
  started="$(pulse_now_ms)"

  if [[ ! -d "$agent_home" ]]; then
    pulse_item_add stack stack UNAVAILABLE "MQ stack" \
      "mq-agent is not installed, so stack truth cannot be read" \
      evidence="$agent_home" \
      next_command="mqlaunch stack"
    return 0
  fi

  local document read_status=0
  document="$(pulse_run_bounded "$PULSE_STACK_TIMEOUT" \
    env -u VIRTUAL_ENV UV_NO_CONFIG=1 \
    uv --project "$agent_home" run mq-agent stack status --json 2>/dev/null)" \
    || read_status=$?
  ended="$(pulse_now_ms)"

  if [[ -z "$document" ]]; then
    pulse_item_add stack stack UNAVAILABLE "MQ stack" \
      "$(pulse_gap_reason "$read_status" "mq-agent did not report stack status" \
         "$PULSE_STACK_TIMEOUT")" \
      next_command="mqlaunch stack" \
      duration_ms="$((ended - started))"
    return 0
  fi

  local rows
  rows="$(printf '%s' "$document" | python3 -c '
import json, sys

try:
    repos = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

if not isinstance(repos, list):
    print("PARSE")
    raise SystemExit(0)

present = []
for repo in repos:
    name = repo.get("name", "?")
    if not repo.get("exists", False):
        print(f"UNAVAILABLE\t{name}\tnot present locally\t")
        continue
    action = (repo.get("next_action") or "").strip()
    if action:
        print(f"WARN\t{name}\t{action}\t")
        continue
    present.append(name)

print(f"PRESENT\t{len(present)}\t{len(repos)}\t")
'
)"

  if [[ "$rows" == PARSE* ]]; then
    pulse_item_add stack stack UNAVAILABLE "MQ stack" \
      "stack status output was not readable" \
      next_command="mqlaunch stack" \
      duration_ms="$((ended - started))"
    return 0
  fi

  local state subject summary rest
  while IFS=$'\t' read -r state subject summary rest; do
    [[ -z "$state" ]] && continue
    if [[ "$state" == "PRESENT" ]]; then
      pulse_item_add stack stack PASS "MQ stack" \
        "$subject of $summary repos present, none flagged" \
        duration_ms="$((ended - started))"
      continue
    fi
    pulse_item_add stack stack "$state" "$subject" "$summary" \
      next_command="mqlaunch stack"
  done <<< "$rows"
}
