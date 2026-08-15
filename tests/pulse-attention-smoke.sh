#!/usr/bin/env bash
# Holds the attention engine: what it selects, how it orders, what it merges,
# and what it is not allowed to do.
#
# Every step builds items by hand. That is not a convenience — it is the
# contract. The engine reads Pulse items and nothing else, so a test that had to
# run a collector to reach it would be evidence the separation had already been
# lost.
#
# Two invariants matter more than the ordering, and both come out of defects the
# collector work found: a finding that could not be measured is still a finding,
# and two rows are only the same problem when a collector said so.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BASE_DIR="$ROOT"

echo "SMOKE: pulse attention engine"

# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/attention.sh"
# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/render.sh"

# Prints the subjects of the attention list, in order, space separated.
subjects() {
  local record out=""
  while IFS= read -r record; do
    [[ -z "$record" ]] && continue
    out+="$(pulse_item_field "$record" subject) "
  done < <(pulse_attention_list)
  printf '%s' "$out"
}

echo "[1/8] only findings are selected"
pulse_items_reset
pulse_item_add doctor system PASS "Environment" "12 of 12 checks pass"
pulse_item_add stack stack SKIPPED "MQ stack" "skipped by --no-stack"
pulse_item_add repos repositories WARN "atlas-one" "main · 1 untracked"
pulse_item_add quality quality FAIL "Runtime authority" "failing"
got="$(subjects)"
[[ "$got" == "Runtime authority atlas-one " ]] || {
  echo "FAIL: selection was '$got'" >&2; exit 1; }
echo "  ok: PASS and SKIPPED excluded, WARN and FAIL kept"

echo "[2/8] an unmeasurable finding is still a finding"
# The roadmap's task says "all WARN and FAIL". UNAVAILABLE belongs here anyway:
# a run holding one unreachable collector and nothing else reports WARN, so
# leaving it out would print a heading that says something needs attention above
# an empty list — the screen contradicting its own verdict.
pulse_items_reset
pulse_item_add stack stack UNAVAILABLE "MQ stack" "mq-agent is not installed"
got="$(subjects)"
[[ "$got" == "MQ stack " ]] || { echo "FAIL: UNAVAILABLE was dropped: '$got'" >&2; exit 1; }
count="$(pulse_attention_count)"
[[ "$count" == "1" ]] || { echo "FAIL: count was $count" >&2; exit 1; }
echo "  ok: UNAVAILABLE is listed, and counted"

echo "[3/8] the priority order is the roadmap's"
pulse_items_reset
pulse_item_add quality quality WARN "Test inventory" "maintenance"
pulse_item_add memory memory WARN "Stack truth" "stale state"
pulse_item_add repos repositories WARN "mq-mcp" "repo divergence"
pulse_item_add git git WARN "CI" "failing CI"
pulse_item_add doctor system WARN "Environment" "broken runtime"
pulse_item_add repos repositories FAIL "mq-hal" "a failure outranks everything"
got="$(subjects)"
[[ "$got" == "mq-hal Environment CI mq-mcp Stack truth Test inventory " ]] || {
  echo "FAIL: order was '$got'" >&2; exit 1; }
echo "  ok: FAIL, runtime, CI, divergence, stale, maintenance"

echo "[4/8] the order does not depend on the order they were collected"
# Determinism is the exit gate, so it is asserted by building the same run
# backwards and requiring the same list.
pulse_items_reset
pulse_item_add repos repositories FAIL "mq-hal" "a failure outranks everything"
pulse_item_add doctor system WARN "Environment" "broken runtime"
pulse_item_add git git WARN "CI" "failing CI"
pulse_item_add repos repositories WARN "mq-mcp" "repo divergence"
pulse_item_add memory memory WARN "Stack truth" "stale state"
pulse_item_add quality quality WARN "Test inventory" "maintenance"
reversed="$(subjects)"
[[ "$reversed" == "mq-hal Environment CI mq-mcp Stack truth Test inventory " ]] || {
  echo "FAIL: reversed input gave '$reversed'" >&2; exit 1; }

# Two findings of equal rank are ordered by area then subject, so ties are
# resolved rather than left to whichever collector ran first.
pulse_items_reset
pulse_item_add repos repositories WARN "zulu" "same rank"
pulse_item_add repos repositories WARN "alpha" "same rank"
got="$(subjects)"
[[ "$got" == "alpha zulu " ]] || { echo "FAIL: tie-break gave '$got'" >&2; exit 1; }
echo "  ok: same list from reversed input, ties broken by area then subject"

echo "[5/8] two rows are one problem only when a collector says so"
# The real case: this checkout is dirty, and two collectors see it from opposite
# ends — one walking the MQ repos, one reading the repo mqlaunch runs in.
pulse_items_reset
pulse_item_add repos repositories WARN "macos-scripts" "main · 4 modified" \
  dedupe_key="worktree:macos-scripts"
pulse_item_add git git WARN "Worktree" "4 modified, 1 untracked" \
  dedupe_key="worktree:macos-scripts"
count="$(pulse_attention_count)"
[[ "$count" == "1" ]] || { echo "FAIL: the same key gave $count findings" >&2; exit 1; }

# Without a key, nothing is merged — however alike the rows look. Two findings
# that resemble each other are not evidence that they are one finding, and
# dropping one on that basis would hide a real problem.
pulse_items_reset
pulse_item_add repos repositories WARN "macos-scripts" "4 modified, 1 untracked"
pulse_item_add git git WARN "Worktree" "4 modified, 1 untracked"
count="$(pulse_attention_count)"
[[ "$count" == "2" ]] || {
  echo "FAIL: rows with no key were merged on resemblance ($count)" >&2; exit 1; }

# Different keys are different problems even when the text is identical.
pulse_items_reset
pulse_item_add repos repositories WARN "mq-mcp" "dirty" dedupe_key="worktree:mq-mcp"
pulse_item_add repos repositories WARN "mq-hal" "dirty" dedupe_key="worktree:mq-hal"
count="$(pulse_attention_count)"
[[ "$count" == "2" ]] || { echo "FAIL: distinct keys merged ($count)" >&2; exit 1; }
echo "  ok: merged on the collector's key, never on resemblance"

echo "[6/8] the default view shows five and counts the rest"
pulse_items_reset
for n in 1 2 3 4 5 6 7; do
  pulse_item_add repos repositories WARN "repo-$n" "dirty"
done
rendered="$(pulse_render WARN 2>&1)"
# Scoped to the ATTENTION section. The same seven items also print under
# REPOSITORIES, where there is no limit and should not be — the cap is about how
# much the operator is asked to read first, not about hiding the area's rows.
attention="$(awk '/^ATTENTION$/{on=1; next} /^Pulse:/{on=0} on' <<< "$rendered")"
shown="$(grep -c '⚠ repo-' <<< "$attention" || true)"
[[ "$shown" == "5" ]] || {
  echo "FAIL: $shown rows shown in ATTENTION, expected 5" >&2
  printf '%s\n' "$rendered" >&2
  exit 1
}
grep -qF '+ 2 more' <<< "$rendered" || {
  echo "FAIL: the remainder was not counted" >&2
  printf '%s\n' "$rendered" >&2
  exit 1
}
echo "  ok: 5 rows, '+ 2 more'"

echo "[7/8] nothing is recommended that an item did not carry"
# The line the roadmap draws: repeating a command an item supplied is fine;
# producing one is the engine deciding something. Asserted by a finding with no
# next_command — the row must appear with no arrow under it.
pulse_items_reset
pulse_item_add memory memory WARN "Stack truth" "stack truth stale, 31 days old" \
  next_command="mqlaunch stack truth-export"
pulse_item_add quality quality WARN "Docs parity" "failing"
rendered="$(pulse_render WARN 2>&1)"
grep -qF '→ mqlaunch stack truth-export' <<< "$rendered" || {
  echo "FAIL: a supplied next_command was dropped" >&2; exit 1; }
arrows="$(grep -c '→' <<< "$rendered" || true)"
# Two sections print the same two items, and only one of them has a command.
[[ "$arrows" == "2" ]] || {
  echo "FAIL: $arrows arrows drawn, expected 2 — one per section for the one item that has a command" >&2
  printf '%s\n' "$rendered" >&2
  exit 1
}
echo "  ok: supplied commands repeated, none invented"

echo "[8/8] the engine reads items and nothing else"
# A structural check, because this is the property that keeps the collector-era
# defects from reappearing one level up: a command that failed with empty output
# read as healthy. An engine that ran its own probes would be a fresh place for
# that, further from the contract that gates the collectors.
offenders="$(grep -nE '(^|[^[:alnum:]_-])(git|gh|uv|curl|ping|networksetup|wdutil)[[:space:]]' \
  "$ROOT/mqlaunch/lib/pulse/attention.sh" | grep -v '^[[:space:]]*[0-9]*:#' || true)"
if [[ -n "$offenders" ]]; then
  echo "FAIL: the attention engine reaches for the world:" >&2
  printf '%s\n' "$offenders" >&2
  exit 1
fi
# And it must not write: no redirection into a file, no mutation verb.
writes="$(grep -nE '(>[^&|)]*[[:alnum:]/])|(\brm\b|\bmv\b|\bmkdir\b|\btouch\b)' \
  "$ROOT/mqlaunch/lib/pulse/attention.sh" | grep -v '^[[:space:]]*[0-9]*:#' || true)"
if [[ -n "$writes" ]]; then
  echo "FAIL: the attention engine writes something:" >&2
  printf '%s\n' "$writes" >&2
  exit 1
fi
echo "  ok: no probes, no writes"

echo "PASS: pulse attention engine"
