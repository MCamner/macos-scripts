#!/usr/bin/env bash
# Holds the memory, Git/GitHub and quality collectors.
#
# Same discipline as tests/pulse-collectors-smoke.sh: every delegate is stubbed,
# so the assertions are about the collector rather than about whether this
# machine happens to have mq-agent installed, a GitHub credential, or a clean
# worktree. None of these steps touches the network.
#
# The rule these three exist to keep is narrower than the core collectors', and
# it is the one an operator's trust rests on:
#
#   a collector reports what its owner knows, and never fills a gap with a
#   conclusion of its own
#
# For QUALITY that means running the repo's real gates and reporting each
# verdict separately — never "some checks passed, so quality is fine", a verdict
# that exists nowhere in this repo and would therefore be invented here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BASE_DIR="$ROOT"

echo "SMOKE: pulse memory, git and quality collectors"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/8] the state collectors exist and load"
test -f "$ROOT/mqlaunch/lib/pulse/collectors-state.sh"
# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/collectors-state.sh"
for fn in pulse_collect_memory pulse_collect_git pulse_collect_quality; do
  declare -f "$fn" >/dev/null || { echo "FAIL: $fn is not defined" >&2; exit 1; }
done

# A stub mq-agent: `uv` on PATH answers with whatever the case below matches, so
# the collector's own invocation is exercised rather than bypassed.
agent_home="$run_dir/mq-agent"
mkdir -p "$agent_home" "$run_dir/bin"
export MQ_AGENT_BIN="$agent_home"
export PATH="$run_dir/bin:$PATH"

write_agent() {
  cat > "$run_dir/bin/uv"
  chmod +x "$run_dir/bin/uv"
}

echo "[2/8] memory maps the owner's words, and carries the vector store as evidence"
write_agent <<'EOF'
#!/bin/sh
case "$*" in
  *"memory status"*)
    echo '{"status":"ready","enabled":true,"vector_store_id":"vs_abc123","repo_signal_available":true}' ;;
  *"stack cockpit"*)
    echo '{"brain_export":{"status":"fresh","age_days":1}}' ;;
esac
EOF
pulse_items_reset
pulse_collect_memory
states="$(pulse_items_states | tr '\n' ' ')"
[[ "$states" == "PASS PASS " ]] || { echo "FAIL: healthy memory gave '$states'" >&2; exit 1; }
evidence="$(pulse_item_field "${PULSE_ITEMS[0]}" evidence)"
[[ "$evidence" == "vector store vs_abc123" ]] || {
  echo "FAIL: vector store not carried: '$evidence'" >&2; exit 1; }
truth="$(pulse_item_field "${PULSE_ITEMS[1]}" summary)"
[[ "$truth" == "stack truth fresh, 1 day old" ]] || {
  echo "FAIL: freshness summary was '$truth'" >&2; exit 1; }
echo "  ok: ready and fresh both PASS, store id is evidence not summary"

echo "[3/8] memory never translates an unknown state into a pass"
# The owner's word is reported as it came. Anything that is not the word it uses
# for working is a reason to look, and a state it does not report at all is a
# gap rather than health.
write_agent <<'EOF'
#!/bin/sh
case "$*" in
  *"memory status"*)
    echo '{"status":"degraded","vector_store_id":"vs_abc123","repo_signal_available":false}' ;;
  *"stack cockpit"*)
    echo '{"brain_export":{"status":"stale","age_days":31}}' ;;
esac
EOF
pulse_items_reset
pulse_collect_memory
states="$(pulse_items_states | tr '\n' ' ')"
[[ "$states" == "WARN WARN " ]] || { echo "FAIL: degraded memory gave '$states'" >&2; exit 1; }
summary="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
[[ "$summary" == *"degraded"* && "$summary" == *"repo-signal unavailable"* ]] || {
  echo "FAIL: summary lost the owner's words: '$summary'" >&2; exit 1; }
aging="$(pulse_item_field "${PULSE_ITEMS[1]}" summary)"
[[ "$aging" == "stack truth stale, 31 days old" ]] || {
  echo "FAIL: aging summary was '$aging'" >&2; exit 1; }

write_agent <<'EOF'
#!/bin/sh
case "$*" in
  *"memory status"*) echo '{"enabled":true}' ;;
  *"stack cockpit"*) echo '{}' ;;
esac
EOF
pulse_items_reset
pulse_collect_memory
states="$(pulse_items_states | tr '\n' ' ')"
[[ "$states" == "UNAVAILABLE UNAVAILABLE " ]] || {
  echo "FAIL: a report with no state gave '$states'" >&2; exit 1; }
echo "  ok: degraded and stale warn, an unreported state is UNAVAILABLE"

echo "[4/8] memory reports the gap when mq-agent is not installed"
( export MQ_AGENT_BIN="$run_dir/absent"
  pulse_items_reset
  pulse_collect_memory
  states="$(pulse_items_states | tr '\n' ' ')"
  [[ "$states" == "UNAVAILABLE UNAVAILABLE " ]] || {
    echo "FAIL: absent mq-agent gave '$states'" >&2; exit 1; }
)
echo "  ok: two UNAVAILABLE items, no guesses"

echo "[5/8] the git collector reads the worktree and never writes to it"
# A scratch repo, so the assertions do not depend on the state of this checkout.
work="$run_dir/repo"
mkdir -p "$work"
git -C "$work" init -q
git -C "$work" config user.email t@example.com
git -C "$work" config user.name Test
printf 'one\n' > "$work/file.txt"
git -C "$work" add file.txt
git -C "$work" commit -qm "first"

before="$(git -C "$work" rev-parse HEAD)"
( export BASE_DIR="$work"
  pulse_items_reset
  pulse_collect_git 1
  states="$(pulse_items_states | tr '\n' ' ')"
  # clean worktree, no upstream, GitHub skipped
  [[ "$states" == "PASS UNAVAILABLE SKIPPED " ]] || {
    echo "FAIL: clean scratch repo gave '$states'" >&2; exit 1; }
  # No upstream is a normal state for a fresh branch. Reporting it as PASS would
  # claim nothing is unpushed, which is not something the collector can know.
  summary="$(pulse_item_field "${PULSE_ITEMS[1]}" summary)"
  [[ "$summary" == "this branch has no upstream" ]] || {
    echo "FAIL: no-upstream summary was '$summary'" >&2; exit 1; }
)

printf 'two\n' >> "$work/file.txt"
printf 'new\n' > "$work/untracked.txt"
( export BASE_DIR="$work"
  pulse_items_reset
  pulse_collect_git 1
  summary="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
  [[ "$summary" == "1 modified, 1 untracked" ]] || {
    echo "FAIL: dirty summary was '$summary'" >&2; exit 1; }
)

after="$(git -C "$work" rev-parse HEAD)"
[[ "$before" == "$after" ]] || { echo "FAIL: the git collector moved HEAD" >&2; exit 1; }
status_after="$(git -C "$work" status --short | wc -l | tr -d ' ')"
[[ "$status_after" == "2" ]] || {
  echo "FAIL: the git collector changed the worktree" >&2; exit 1; }
echo "  ok: clean, dirty and no-upstream all read correctly, nothing mutated"

echo "[6/8] --no-network marks GitHub SKIPPED rather than dropping it"
( export BASE_DIR="$work"
  pulse_items_reset
  pulse_collect_git 1
  found=0
  for record in "${PULSE_ITEMS[@]}"; do
    [[ "$(pulse_item_field "$record" subject)" == "GitHub" ]] || continue
    found=1
    [[ "$(pulse_item_field "$record" status)" == "SKIPPED" ]] || {
      echo "FAIL: GitHub was not SKIPPED under --no-network" >&2; exit 1; }
  done
  [[ $found -eq 1 ]] || { echo "FAIL: --no-network dropped the GitHub row" >&2; exit 1; }
)

# And with the network allowed but `gh` absent, the gap is named rather than
# passed over: PATH is trimmed to a directory holding only git.
gh_free="$run_dir/nogh"
mkdir -p "$gh_free"
for tool in bash git grep python3 timeout gtimeout; do
  target="$(command -v "$tool" 2>/dev/null)" || continue
  ln -sf "$target" "$gh_free/$tool"
done
( export BASE_DIR="$work"; export PATH="$gh_free"
  pulse_items_reset
  pulse_collect_git 0
  found=0
  for record in "${PULSE_ITEMS[@]}"; do
    [[ "$(pulse_item_field "$record" subject)" == "GitHub" ]] || continue
    found=1
    [[ "$(pulse_item_field "$record" status)" == "UNAVAILABLE" ]] || {
      echo "FAIL: a missing gh did not report UNAVAILABLE" >&2; exit 1; }
  done
  [[ $found -eq 1 ]] || { echo "FAIL: a missing gh produced no GitHub row" >&2; exit 1; }
)
echo "  ok: skipped when asked, UNAVAILABLE when gh is missing"

echo "[7/8] quality runs the real gates and reports each verdict separately"
# The rule this step exists for: no aggregate verdict. One failing gate must
# show as that gate failing, next to the others still passing.
gate_root="$run_dir/gates"
mkdir -p "$gate_root/tools/scripts" "$gate_root/scripts" "$gate_root/tests"
cat > "$gate_root/tools/scripts/validate-command-registry.py" <<'EOF'
#!/usr/bin/env python3
print("OK: 77 commands")
EOF
cat > "$gate_root/scripts/check-runtime-authority.sh" <<'EOF'
#!/usr/bin/env bash
echo "[FAIL] a live path reaches the frozen tree"
exit 1
EOF
cat > "$gate_root/scripts/check-skills.sh" <<'EOF'
#!/usr/bin/env bash
echo "check-skills: OK"
EOF
cat > "$gate_root/tests/registry-consumer-parity-smoke.sh" <<'EOF'
#!/usr/bin/env bash
echo "OK: consumers agree"
EOF
chmod +x "$gate_root/tools/scripts/validate-command-registry.py" \
  "$gate_root/scripts/check-runtime-authority.sh" \
  "$gate_root/scripts/check-skills.sh" \
  "$gate_root/tests/registry-consumer-parity-smoke.sh"
# tests/test-inventory-smoke.sh is deliberately absent.

( export BASE_DIR="$gate_root"
  pulse_items_reset
  pulse_collect_quality
  states="$(pulse_items_states | tr '\n' ' ')"
  [[ "$states" == "PASS FAIL PASS PASS UNAVAILABLE " ]] || {
    echo "FAIL: gate states were '$states'" >&2; exit 1; }
  # The failing gate carries its own last line, so the operator does not have to
  # run it again to learn what broke.
  evidence="$(pulse_item_field "${PULSE_ITEMS[1]}" evidence)"
  [[ "$evidence" == *"frozen tree"* ]] || {
    echo "FAIL: the gate's own output was not carried: '$evidence'" >&2; exit 1; }
  # A gate that is not there is not a gate that passed.
  missing="$(pulse_item_field "${PULSE_ITEMS[4]}" summary)"
  [[ "$missing" == "gate is missing" ]] || {
    echo "FAIL: an absent gate reported '$missing'" >&2; exit 1; }
)
echo "  ok: five items, one per gate, no aggregate verdict"

echo "[8/8] one unreachable delegate does not take the run with it"
# The P1 exit gate: every collector runs independently, and a failure becomes a
# state rather than a crash. Driven end to end with mq-agent absent, gh absent,
# and one quality gate failing — the run must still finish and report 2.
stub_root="$run_dir/stub"
mkdir -p "$stub_root/tools/scripts" "$stub_root/scripts" "$stub_root/tests" "$stub_root/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub_root/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/pulse.sh" "$stub_root/tools/scripts/pulse.sh"
chmod +x "$stub_root/tools/scripts/pulse.sh"
cat > "$stub_root/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
cat > "$stub_root/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [{"name": "mq-agent", "git": True, "clean": True,
  "modified": 0, "untracked": 0, "branch": "main", "upstream": "origin/main",
  "ahead": 0, "behind": 0}], "summary": {"total": 1, "dirty": 0}}))
EOF
cp "$gate_root/scripts/check-runtime-authority.sh" "$stub_root/scripts/"
cp "$gate_root/scripts/check-skills.sh" "$stub_root/scripts/"
cp "$gate_root/tools/scripts/validate-command-registry.py" "$stub_root/tools/scripts/"
cp "$gate_root/tests/registry-consumer-parity-smoke.sh" "$stub_root/tests/"
chmod +x "$stub_root/tools/scripts/doctor.sh"

status=0
# PATH is left alone here: the run is already --no-network, so `gh` is never
# reached, and trimming PATH would only test whether the stub directory happened
# to hold every tool the entrypoint shells out to.
out="$(MACOS_SCRIPTS_HOME="$stub_root" MQ_AGENT_BIN="$run_dir/absent" \
  bash "$stub_root/tools/scripts/pulse.sh" --no-network </dev/null 2>&1)" || status=$?
if [[ "$status" -ne 2 ]]; then
  echo "FAIL: a run with a failing gate exited $status, expected 2" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
for heading in SYSTEM REPOSITORIES 'MQ STACK' MEMORY 'GIT / GITHUB' QUALITY; do
  grep -qF "$heading" <<< "$out" || {
    echo "FAIL: the run lost the $heading area" >&2
    printf '%s\n' "$out" >&2
    exit 1
  }
done
grep -qF 'Pulse: FAIL' <<< "$out"
echo "  ok: six areas rendered, unreachable delegates reported, exit 2"

echo "PASS: pulse memory, git and quality collectors"
