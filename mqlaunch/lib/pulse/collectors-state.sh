#!/usr/bin/env bash
# Pulse state collectors — memory, Git/GitHub, quality.
#
# Split from collectors.sh along the line the roadmap's PR sequence draws: the
# core three describe what the machine and the repos *are*, these three describe
# what is *going on* — what memory knows, what is in flight on GitHub, and
# whether the repo's own gates still hold.
#
# The rule is the same one, and it is the whole design: a collector reports what
# its owner actually knows. It never fills a gap with a conclusion of its own.
# That is why the review queue is missing from MEMORY rather than parsed out of
# a screen, and why QUALITY runs the real gates rather than counting green
# tests — "some checks passed" is a verdict this repo would be inventing.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/collectors.sh"

PULSE_GH_TIMEOUT="${PULSE_GH_TIMEOUT:-15}"

# Runs mq-agent with the same invocation the agent bridge uses.
#
# Prints nothing and returns non-zero when mq-agent is not installed, so each
# caller can report the gap in its own area rather than sharing one message.
pulse_agent_json() {
  local agent_home="${MQ_AGENT_BIN:-$HOME/mq-agent}"
  [[ -d "$agent_home" ]] || return 1
  pulse_run_bounded "$PULSE_STACK_TIMEOUT" \
    env -u VIRTUAL_ENV UV_NO_CONFIG=1 \
    uv --project "$agent_home" run mq-agent "$@" 2>/dev/null
}

# MEMORY — what mq-agent reports about semantic memory and stack truth.
#
# Two readings, both published by their owner as JSON:
#
#   mq-agent memory status --json   semantic store, vector store, repo-signal
#   mq-agent stack cockpit --json   brain_export.status — stack-truth freshness
#
# The held/review queue is deliberately absent. `mq-agent memory review-status`
# exists and is read-only, but prints only for a human; reading it would make
# mq-agent's screen layout a contract this repo depends on, which is the same
# mistake as parsing `repos status` instead of adding `--json` to it. The gap is
# recorded in ROADMAP.md against the box, not papered over with a guess.
pulse_collect_memory() {
  local started ended
  started="$(pulse_now_ms)"

  local document
  if ! document="$(pulse_agent_json memory status "$BASE_DIR" --json)" || [[ -z "$document" ]]; then
    ended="$(pulse_now_ms)"
    pulse_item_add memory memory UNAVAILABLE "Semantic memory" \
      "mq-agent did not report memory status" \
      next_command="mqlaunch srm inspect" \
      duration_ms="$((ended - started))"
  else
    ended="$(pulse_now_ms)"
    local parsed
    parsed="$(printf '%s' "$document" | python3 -c '
import json, sys

try:
    doc = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

state = doc.get("status")
store = doc.get("vector_store_id") or ""
# The owner publishes the word. Anything other than the one word it uses for
# working is reported as it came, not translated into a verdict here.
status = "PASS" if state == "ready" else ("UNAVAILABLE" if not state else "WARN")
summary = f"semantic store {state}" if state else "semantic store state not reported"
if not doc.get("repo_signal_available", True):
    summary += ", repo-signal unavailable"
    if status == "PASS":
        status = "WARN"
print(status)
print(summary)
print(store)
')"
    if [[ "$parsed" == PARSE* ]]; then
      pulse_item_add memory memory UNAVAILABLE "Semantic memory" \
        "memory status output was not readable" \
        next_command="mqlaunch srm inspect" \
        duration_ms="$((ended - started))"
    else
      local mem_status summary store
      {
        read -r mem_status || true
        read -r summary || true
        read -r store || true
      } <<< "$parsed"
      local -a extra=(duration_ms="$((ended - started))")
      # The vector store id is the source, which the roadmap asks for where it
      # is already exposed. It is evidence rather than summary: an operator
      # scanning the screen wants the state, not a 32-character id.
      [[ -n "$store" ]] && extra+=(evidence="vector store $store")
      [[ "$mem_status" != "PASS" ]] && extra+=(next_command="mqlaunch srm inspect")
      pulse_item_add memory memory "$mem_status" "Semantic memory" "$summary" "${extra[@]}"
    fi
  fi

  # Stack truth freshness, from the cockpit's brain_export block.
  started="$(pulse_now_ms)"
  local cockpit
  if ! cockpit="$(pulse_agent_json stack cockpit --json)" || [[ -z "$cockpit" ]]; then
    ended="$(pulse_now_ms)"
    pulse_item_add memory memory UNAVAILABLE "Stack truth" \
      "mq-agent did not report stack-truth freshness" \
      next_command="mqlaunch stack cockpit" \
      duration_ms="$((ended - started))"
    return 0
  fi
  ended="$(pulse_now_ms)"

  local truth
  truth="$(printf '%s' "$cockpit" | python3 -c '
import json, sys

try:
    doc = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

export = doc.get("brain_export") or {}
state = export.get("status")
age = export.get("age_days")
if not state:
    print("UNAVAILABLE")
    print("stack-truth freshness not reported")
    raise SystemExit(0)

# "fresh" is the owners word for fine. Every other word it may use is a reason
# to look, and the age it published says how much of one.
status = "PASS" if state == "fresh" else "WARN"
suffix = ""
if isinstance(age, int):
    suffix = ", 1 day old" if age == 1 else f", {age} days old"
print(status)
print(f"stack truth {state}{suffix}")
')"

  if [[ "$truth" == PARSE* ]]; then
    pulse_item_add memory memory UNAVAILABLE "Stack truth" \
      "cockpit output was not readable" \
      next_command="mqlaunch stack cockpit" \
      duration_ms="$((ended - started))"
    return 0
  fi

  local truth_status truth_summary
  {
    read -r truth_status || true
    read -r truth_summary || true
  } <<< "$truth"

  local -a truth_extra=(duration_ms="$((ended - started))")
  [[ "$truth_status" != "PASS" ]] && truth_extra+=(next_command="mqlaunch obsidian status")
  pulse_item_add memory memory "$truth_status" "Stack truth" "$truth_summary" "${truth_extra[@]}"
}

# GIT / GITHUB — what is in flight for the repo mqlaunch is running from.
#
# Two halves, and the split matters. The local half — a dirty worktree, commits
# that are not pushed — is git in this checkout and always runs. The GitHub half
# needs the network and the `gh` credential, so it is skippable and reports
# UNAVAILABLE rather than silence when `gh` is missing or refuses.
#
# Read-only throughout: `git status`, `git rev-list`, `gh pr list`, `gh run
# list`. No push, no merge, no checkout, no branch mutation, and nothing that
# writes to the repo at all.
pulse_collect_git() {
  local skip_network="${1:-0}"
  local started ended
  started="$(pulse_now_ms)"

  # Ask whether this is a repository before reading anything out of it.
  #
  # Without this, `git status --short` fails, its output is empty, and empty is
  # indistinguishable from a clean tree — so a directory that is not a
  # repository at all reported "Worktree: clean". That is the failure mode this
  # whole contract exists to prevent, arrived at through a silent error rather
  # than a wrong reading. The branch lookup fails the same way, and an empty
  # branch name passed to `gh run list --branch ''` answers about the whole
  # repository, which is worse than answering nothing.
  if ! git -C "$BASE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    pulse_item_add git git UNAVAILABLE "Worktree" \
      "not a git repository" evidence="$BASE_DIR"
    return 0
  fi

  # The repositories collector walks the MQ repos and sees this checkout among
  # them; this one reads the same worktree from the other end. Both label the
  # observation `worktree:<repo>` so the attention list raises one dirty tree
  # once instead of twice.
  # Parameter expansion, not `basename`: one less external command on a path
  # that already reports what it cannot reach, and the collector should not be
  # the thing that fails when PATH is thin.
  local repo_name="${BASE_DIR%/}"
  repo_name="${repo_name##*/}"

  local changes modified untracked
  # `|| true` for the same reason as everywhere else in these collectors: an
  # assignment from a failing command ends the run under `set -e`. The guard
  # above catches the common cause, but a repository can fail `git status` for
  # reasons of its own — a broken index, a lock — and that is a reading this
  # collector should report, not a crash it should take.
  changes="$(git -C "$BASE_DIR" status --short 2>/dev/null || true)"
  if [[ -z "$changes" ]]; then
    pulse_item_add git git PASS "Worktree" "clean"
  else
    modified="$(printf '%s\n' "$changes" | grep -cv '^??' || true)"
    untracked="$(printf '%s\n' "$changes" | grep -c '^??' || true)"
    pulse_item_add git git WARN "Worktree" \
      "$modified modified, $untracked untracked" \
      next_command="mqlaunch git" \
      dedupe_key="worktree:$repo_name"
  fi

  local ahead
  ahead="$(git -C "$BASE_DIR" rev-list --count '@{u}..HEAD' 2>/dev/null || printf '')"
  if [[ -z "$ahead" ]]; then
    # No upstream is a normal state for a fresh branch, not a failure — and not
    # something to report as healthy either.
    pulse_item_add git git UNAVAILABLE "Unpushed commits" \
      "this branch has no upstream" \
      next_command="mqlaunch git"
  elif [[ "$ahead" -gt 0 ]]; then
    pulse_item_add git git WARN "Unpushed commits" \
      "$ahead ahead of upstream" \
      next_command="mqlaunch git"
  else
    pulse_item_add git git PASS "Unpushed commits" "none"
  fi

  if [[ "$skip_network" -eq 1 ]]; then
    pulse_item_add git git SKIPPED "GitHub" "skipped by --no-network"
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    pulse_item_add git git UNAVAILABLE "GitHub" \
      "gh is not installed, so pull requests and CI cannot be read" \
      evidence="brew install gh"
    return 0
  fi

  local prs
  prs="$(pulse_run_bounded "$PULSE_GH_TIMEOUT" \
    gh pr list --state open --limit 30 \
    --json number,isDraft,mergeable 2>/dev/null || true)"
  ended="$(pulse_now_ms)"

  if [[ -z "$prs" ]]; then
    pulse_item_add git git UNAVAILABLE "Pull requests" \
      "GitHub did not answer" \
      next_command="mqlaunch git" \
      duration_ms="$((ended - started))"
  else
    local pr_line
    pr_line="$(printf '%s' "$prs" | python3 -c '
import json, sys

try:
    prs = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

if not prs:
    print("PASS")
    print("none open")
    raise SystemExit(0)

# Mergeability is reported where GitHub reports it. UNKNOWN means the merge
# commit is still being computed, which is a fact about GitHub rather than
# about the PR, so it is named instead of counted as a conflict.
conflicting = [p for p in prs if p.get("mergeable") == "CONFLICTING"]
unknown = [p for p in prs if p.get("mergeable") not in ("MERGEABLE", "CONFLICTING")]
drafts = [p for p in prs if p.get("isDraft")]

summary = f"{len(prs)} open"
if drafts:
    summary += f", {len(drafts)} draft"
if conflicting:
    summary += f", {len(conflicting)} conflicting"
if unknown:
    summary += f", {len(unknown)} mergeability unknown"

print("WARN" if conflicting else "PASS")
print(summary)
')"
    if [[ "$pr_line" == PARSE* ]]; then
      pulse_item_add git git UNAVAILABLE "Pull requests" \
        "pull request list was not readable" \
        duration_ms="$((ended - started))"
    else
      local pr_status pr_summary
      {
        read -r pr_status || true
        read -r pr_summary || true
      } <<< "$pr_line"
      local -a pr_extra=(duration_ms="$((ended - started))")
      [[ "$pr_status" != "PASS" ]] && pr_extra+=(next_command="mqlaunch git")
      pulse_item_add git git "$pr_status" "Pull requests" "$pr_summary" "${pr_extra[@]}"
    fi
  fi

  # CI for the branch that is checked out, which is the run an operator is
  # waiting on. A branch with no runs is not a pass — nothing ran.
  local branch
  branch="$(git -C "$BASE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '')"
  if [[ -z "$branch" ]]; then
    pulse_item_add git git UNAVAILABLE "CI" "no branch to ask about"
    return 0
  fi
  started="$(pulse_now_ms)"
  local runs
  runs="$(pulse_run_bounded "$PULSE_GH_TIMEOUT" \
    gh run list --branch "$branch" --limit 10 \
    --json status,conclusion,workflowName 2>/dev/null || true)"
  ended="$(pulse_now_ms)"

  if [[ -z "$runs" ]]; then
    pulse_item_add git git UNAVAILABLE "CI" \
      "GitHub did not answer for $branch" \
      duration_ms="$((ended - started))"
    return 0
  fi

  local ci_line
  ci_line="$(printf '%s' "$runs" | BRANCH="$branch" python3 -c '
import json, os, sys

branch = os.environ["BRANCH"]
try:
    runs = json.load(sys.stdin)
except json.JSONDecodeError:
    print("PARSE")
    raise SystemExit(0)

if not runs:
    print("UNAVAILABLE")
    print(f"no runs for {branch}")
    raise SystemExit(0)

pending = [r for r in runs if r.get("status") != "completed"]
failed = [r for r in runs if r.get("conclusion") in ("failure", "timed_out", "cancelled")]

if failed:
    names = ", ".join(sorted({r.get("workflowName", "?") for r in failed}))
    print("FAIL")
    print(f"failing on {branch}: {names}")
elif pending:
    print("WARN")
    print(f"{len(pending)} run(s) still going on {branch}")
else:
    print("PASS")
    print(f"passing on {branch}")
')"

  if [[ "$ci_line" == PARSE* ]]; then
    pulse_item_add git git UNAVAILABLE "CI" \
      "run list was not readable" \
      duration_ms="$((ended - started))"
    return 0
  fi

  local ci_status ci_summary
  {
    read -r ci_status || true
    read -r ci_summary || true
  } <<< "$ci_line"

  local -a ci_extra=(duration_ms="$((ended - started))")
  [[ "$ci_status" != "PASS" ]] && ci_extra+=(next_command="gh run list --branch $branch")
  pulse_item_add git git "$ci_status" "CI" "$ci_summary" "${ci_extra[@]}"
}

# QUALITY — the repo's own gates, run and reported one by one.
#
# The temptation this avoids is "some checks passed, so quality is fine". That
# verdict does not exist anywhere in this repo, so Pulse would be inventing it.
# Each gate below already answers for itself with an exit code; the collector
# runs it and reports what it said, as its own item, so a failure names the gate
# an operator has to go and read.
#
# All five are read-only and take under half a second each, measured. A gate
# that is missing reports UNAVAILABLE, because a check that is not there is not
# a check that passed.
pulse_quality_gate() {
  local subject="$1" command_path="$2"
  shift 2

  if [[ ! -e "$command_path" ]]; then
    pulse_item_add quality quality UNAVAILABLE "$subject" \
      "gate is missing" evidence="$command_path"
    return 0
  fi

  # A failing gate is the interesting case, so the failure has to survive being
  # read. `output="$(cmd)"` on its own ends the run under `set -e` in a caller,
  # and `gate_status=$?` on the next line never executes — the collector would
  # take the whole Pulse down precisely when it had something to report.
  local started ended output gate_status=0
  started="$(pulse_now_ms)"
  output="$(pulse_run_bounded "$PULSE_COLLECTOR_TIMEOUT" "$@" 2>&1)" || gate_status=$?
  ended="$(pulse_now_ms)"

  if [[ $gate_status -eq 0 ]]; then
    pulse_item_add quality quality PASS "$subject" "passing" \
      duration_ms="$((ended - started))"
    return 0
  fi

  # The gate's own last line is the evidence. It is what a contributor would
  # read first when running the command by hand, and carrying it means the
  # operator does not have to run it again to learn what broke.
  local detail
  detail="$(printf '%s' "$output" | tail -1 | cut -c1-120)"
  pulse_item_add quality quality FAIL "$subject" "failing" \
    evidence="${detail:-exit $gate_status}" \
    next_command="mqlaunch selftest" \
    duration_ms="$((ended - started))"
}

pulse_collect_quality() {
  pulse_quality_gate "Command registry" \
    "$BASE_DIR/tools/scripts/validate-command-registry.py" \
    python3 "$BASE_DIR/tools/scripts/validate-command-registry.py"

  pulse_quality_gate "Runtime authority" \
    "$BASE_DIR/scripts/check-runtime-authority.sh" \
    bash "$BASE_DIR/scripts/check-runtime-authority.sh"

  pulse_quality_gate "Skills" \
    "$BASE_DIR/scripts/check-skills.sh" \
    bash "$BASE_DIR/scripts/check-skills.sh"

  pulse_quality_gate "Docs parity" \
    "$BASE_DIR/tests/registry-consumer-parity-smoke.sh" \
    bash "$BASE_DIR/tests/registry-consumer-parity-smoke.sh"

  pulse_quality_gate "Test inventory" \
    "$BASE_DIR/tests/test-inventory-smoke.sh" \
    bash "$BASE_DIR/tests/test-inventory-smoke.sh"
}
