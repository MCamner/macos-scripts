#!/usr/bin/env bash
# Holds the canonical item model and the three core collectors.
#
# Every collector is driven against stubbed delegates rather than against
# whatever this machine happens to look like. A test that reads the real doctor
# passes or fails on the tester's laptop, which is the defect
# tests/doctor-status-contract-smoke.sh already had to fix once: it builds a
# provisioned and a stripped machine instead of trusting the inventory of the
# one running the suite. The same discipline applies here, and it is what lets
# this test assert the cases that matter — a delegate that is missing, one that
# answers with garbage, and one that reports trouble.
#
# The rule under all of it: a collector must never turn "could not measure" into
# a pass. Steps 5, 6 and 10 are that rule — the last one for the case that
# reached it through a silent error rather than a missing delegate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BASE_DIR="$ROOT"

echo "SMOKE: pulse item model and core collectors"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/11] the model, the collectors and the entrypoint exist"
test -f "$ROOT/mqlaunch/lib/pulse/item.sh"
test -f "$ROOT/mqlaunch/lib/pulse/collectors.sh"
test -f "$ROOT/mqlaunch/lib/pulse/render.sh"
test -x "$ROOT/tools/scripts/pulse.sh"

# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/collectors.sh"
# The git collector lives with the state collectors, and step 10 needs it: the
# non-repository case is a core reading failure, so it is held here next to the
# other "could not measure" cases rather than filed by which file it sits in.
# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/collectors-state.sh"
# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/render.sh"
# The serializer, so that step 3 gates the document the product actually emits
# rather than a second one written for the test.
# shellcheck source=/dev/null
source "$ROOT/mqlaunch/lib/pulse/document.sh"

echo "[2/11] an item requires its five fields and a real state"
pulse_items_reset
if pulse_item_add doctor system PASS "Subject" 2>/dev/null; then
  echo "FAIL: an item with four fields was accepted" >&2
  exit 1
fi
if pulse_item_add doctor system PASS "" "summary" 2>/dev/null; then
  echo "FAIL: an item with an empty required field was accepted" >&2
  exit 1
fi
if pulse_item_add doctor system HEALTHY "Subject" "summary" 2>/dev/null; then
  echo "FAIL: an item with an invented state was accepted" >&2
  exit 1
fi
if pulse_item_add doctor system PASS "Subject" "summary" severity=high 2>/dev/null; then
  echo "FAIL: an item with an invented field name was accepted" >&2
  exit 1
fi
if [[ "${#PULSE_ITEMS[@]}" -ne 0 ]]; then
  echo "FAIL: a refused item was recorded anyway" >&2
  exit 1
fi
echo "  ok: four malformed items refused, none recorded"

echo "[3/11] the model round-trips to JSON without losing a field"
# Values chosen to break a hand-rolled serializer: a quote, a comma, a colon,
# a backslash and a non-ASCII character. This is why JSON is emitted by python3
# rather than assembled in shell.
pulse_items_reset
pulse_item_add doctor system PASS "Environment" '12 of 12 checks pass'
pulse_item_add repos repositories WARN 'macos-scripts' \
  'dirty: 2 modified, "one" and C:\temp — ✓' \
  evidence='git status --short' next_command='mqlaunch git' priority=60 \
  freshness='just now' duration_ms=142
document="$(pulse_document WARN "" system repositories)"
printf '%s' "$document" | python3 -c '
import json, sys

doc = json.load(sys.stdin)
assert doc["status"] == "WARN", doc["status"]
items = [i for section in doc["sections"].values() for i in section]
assert len(items) == 2, items

first, second = items
assert first["priority"] == 0, "priority must default to 0"
assert second["summary"] == "dirty: 2 modified, \"one\" and C:\\temp — ✓", second["summary"]
assert second["evidence"] == "git status --short"
assert second["next_command"] == "mqlaunch git"
assert second["priority"] == 60 and isinstance(second["priority"], int)
assert second["freshness"] == "just now"
assert second["duration_ms"] == 142 and isinstance(second["duration_ms"], int)
print("  ok: 2 items, every field intact, numbers restored as numbers")
'

echo "[4/11] rendering derives nothing of its own"
# The screen must be a function of the items. Asserted by rendering a run whose
# states disagree with what a naive renderer would infer from the words.
pulse_items_reset
pulse_item_add doctor system FAIL "Environment" "everything is fine"
pulse_item_add repos repositories PASS "Repositories" "3 broken repos"
rendered="$(pulse_render FAIL 2>&1)"
grep -qF '✖ Environment' <<< "$rendered"
grep -qF '✔ Repositories' <<< "$rendered"
grep -qF 'Pulse: FAIL' <<< "$rendered"
echo "  ok: glyphs follow the state, not the prose"

# --- stubbed delegates -----------------------------------------------------
# Each collector is pointed at a fake BASE_DIR holding stub delegates, so the
# assertions are about the collector rather than about this machine.
stub_root="$run_dir/stub"
mkdir -p "$stub_root/tools/scripts"

make_doctor() {
  cat > "$stub_root/tools/scripts/doctor.sh"
  chmod +x "$stub_root/tools/scripts/doctor.sh"
}

echo "[5/11] --verbose prints what the collector saw, and nothing it did not"
# The flag prints evidence and timing that were already on the item; it must not
# make the collector look at anything more, and the default screen must stay
# short enough to scan.
pulse_items_reset
pulse_item_add repos repositories WARN 'macos-scripts' 'dirty' \
  evidence='git status --short' duration_ms=142
quiet="$(PULSE_VERBOSE=0 pulse_render WARN 2>&1)"
loud="$(PULSE_VERBOSE=1 pulse_render WARN 2>&1)"
grep -qF 'git status --short' <<< "$quiet" && {
  echo "FAIL: the default screen printed the evidence" >&2; exit 1; }
grep -qF 'git status --short' <<< "$loud" || {
  echo "FAIL: --verbose did not print the evidence" >&2; exit 1; }
grep -qF '142 ms' <<< "$loud" || {
  echo "FAIL: --verbose did not print the collector's duration" >&2; exit 1; }
echo "  ok: evidence and timing on demand, off by default"

echo "[6/11] the system collector maps doctor's verdict, and never invents one"
make_doctor <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"project":"macos-scripts","status":"warn",
 "checks":[{"name":"git","status":"ok"},{"name":"jq","status":"warn"},
           {"name":"fzf","status":"warn"}],
 "summary":{"ok":1,"warn":2,"fail":0},"next":"brew install jq"}
JSON
EOF
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_system
  states="$(pulse_items_states)"
  [[ "$states" == "WARN" ]] || { echo "FAIL: warn checks gave $states" >&2; exit 1; }
  summary="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
  [[ "$summary" == "1 of 3 checks pass" ]] || { echo "FAIL: summary was '$summary'" >&2; exit 1; }
  next="$(pulse_item_field "${PULSE_ITEMS[0]}" next_command)"
  [[ "$next" == "brew install jq" ]] || { echo "FAIL: next was '$next'" >&2; exit 1; }
  evidence="$(pulse_item_field "${PULSE_ITEMS[0]}" evidence)"
  [[ "$evidence" == *"jq"* ]] || { echo "FAIL: evidence lost the failing names: '$evidence'" >&2; exit 1; }
)

make_doctor <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"},{"name":"gh","status":"fail"}]}'
EOF
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_system
  states="$(pulse_items_states)"
  [[ "$states" == "FAIL" ]] || { echo "FAIL: a failing check gave $states" >&2; exit 1; }
)

# A delegate that reports correctly *and* exits non-zero. This is the ordinary
# case, not an edge: `doctor --json` exits 1 whenever any check needs attention.
# `document="$(cmd)"` on its own ends the run under `set -e` — which this file
# sets — so the collector would die on exactly the input it exists to read. The
# exit status is deliberately not consulted: it is doctor's verdict about the
# machine, and the collector takes that from the document.
make_doctor <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"},{"name":"jq","status":"warn"}]}'
exit 1
EOF
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_system
  states="$(pulse_items_states)"
  [[ "$states" == "WARN" ]] || {
    echo "FAIL: a delegate that exited 1 with a valid report gave '$states'" >&2
    exit 1
  }
)
echo "  ok: warn maps to WARN, fail to FAIL, and a non-zero exit does not end the run"

echo "[7/11] a missing or unreadable delegate is UNAVAILABLE, never PASS"
# The whole point of the state. A collector that cannot reach its subject must
# not report the subject as healthy.
rm -f "$stub_root/tools/scripts/doctor.sh"
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_system
  states="$(pulse_items_states)"
  [[ "$states" == "UNAVAILABLE" ]] || { echo "FAIL: missing doctor gave $states" >&2; exit 1; }
)

make_doctor <<'EOF'
#!/usr/bin/env bash
echo 'this is not json'
EOF
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_system
  states="$(pulse_items_states)"
  [[ "$states" == "UNAVAILABLE" ]] || { echo "FAIL: unreadable doctor gave $states" >&2; exit 1; }
)

make_doctor <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_system
  states="$(pulse_items_states)"
  [[ "$states" == "UNAVAILABLE" ]] || { echo "FAIL: silent doctor gave $states" >&2; exit 1; }
)
echo "  ok: missing, unreadable and silent all report UNAVAILABLE"

echo "[8/11] the repositories collector reports per repo and summarises the rest"
cat > "$stub_root/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [
  {"name": "mq-agent", "git": True, "clean": True, "modified": 0, "untracked": 0,
   "branch": "main", "upstream": "origin/main", "ahead": 0, "behind": 0},
  {"name": "mq-mcp", "git": True, "clean": True, "modified": 0, "untracked": 0,
   "branch": "main", "upstream": "origin/main", "ahead": 2, "behind": 0},
  {"name": "macos-scripts", "git": True, "clean": False, "modified": 3, "untracked": 1,
   "branch": "feat/pulse", "upstream": "origin/main", "ahead": 0, "behind": 0},
  {"name": "notes", "git": False}
], "summary": {"total": 4, "dirty": 2}}))
EOF
( BASE_DIR="$stub_root"; pulse_items_reset; pulse_collect_repos
  states="$(pulse_items_states | tr '\n' ' ')"
  [[ "$states" == "WARN WARN UNAVAILABLE PASS " ]] || {
    echo "FAIL: states were '$states'" >&2; exit 1; }
  # An unpushed branch is a warning even when the tree is clean — that is the
  # ahead/behind reading, and it is the reason --json was added to mq-repos.py.
  ahead_summary="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
  [[ "$ahead_summary" == *"2 ahead"* ]] || {
    echo "FAIL: ahead count missing from '$ahead_summary'" >&2; exit 1; }
  dirty_summary="$(pulse_item_field "${PULSE_ITEMS[1]}" summary)"
  [[ "$dirty_summary" == *"3 modified, 1 untracked"* ]] || {
    echo "FAIL: dirty counts missing from '$dirty_summary'" >&2; exit 1; }
  clean_summary="$(pulse_item_field "${PULSE_ITEMS[3]}" summary)"
  [[ "$clean_summary" == "1 of 4 repos clean" ]] || {
    echo "FAIL: clean summary was '$clean_summary'" >&2; exit 1; }
)
echo "  ok: dirty, unpushed and non-git repos each reported, clean ones counted"

echo "[9/11] the stack collector delegates, and says so when it cannot"
( BASE_DIR="$stub_root"; export MQ_AGENT_BIN="$run_dir/absent"; pulse_items_reset
  pulse_collect_stack
  states="$(pulse_items_states)"
  [[ "$states" == "UNAVAILABLE" ]] || { echo "FAIL: absent mq-agent gave $states" >&2; exit 1; }
  summary="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
  [[ "$summary" == *"mq-agent is not installed"* ]] || {
    echo "FAIL: summary did not name the cause: '$summary'" >&2; exit 1; }
  # One item for the area, not five invented repo rows.
  [[ "${#PULSE_ITEMS[@]}" -eq 1 ]] || {
    echo "FAIL: an unreachable stack produced ${#PULSE_ITEMS[@]} items" >&2; exit 1; }
)

# With mq-agent present, the delegate is stubbed through `uv` on PATH.
agent_home="$run_dir/mq-agent"
mkdir -p "$agent_home" "$run_dir/bin"
cat > "$run_dir/bin/uv" <<'EOF'
#!/bin/sh
cat <<'JSON'
[{"name":"mq-agent","exists":true,"next_action":""},
 {"name":"mq-mcp","exists":true,"next_action":"mq-agent stack release --repo mq-mcp"},
 {"name":"mqobsidian","exists":false,"next_action":""}]
JSON
EOF
chmod +x "$run_dir/bin/uv"
( BASE_DIR="$stub_root"; export MQ_AGENT_BIN="$agent_home"; PATH="$run_dir/bin:$PATH"
  pulse_items_reset; pulse_collect_stack
  states="$(pulse_items_states | tr '\n' ' ')"
  [[ "$states" == "WARN UNAVAILABLE PASS " ]] || {
    echo "FAIL: stack states were '$states'" >&2; exit 1; }
  action="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
  [[ "$action" == "mq-agent stack release --repo mq-mcp" ]] || {
    echo "FAIL: next_action not carried: '$action'" >&2; exit 1; }
)
echo "  ok: absent mq-agent is one UNAVAILABLE item; present, its verdict is mapped"

echo "[10/11] the entrypoint honours --no-stack, and its exit code is the verdict"
# Driven end to end against the stubs, because the exit code is the part a
# script reads and the part a renderer could quietly overwrite.
cat > "$stub_root/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$stub_root/tools/scripts/doctor.sh"
cat > "$stub_root/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [
  {"name": "mq-agent", "git": True, "clean": True, "modified": 0, "untracked": 0,
   "branch": "main", "upstream": "origin/main", "ahead": 0, "behind": 0}
], "summary": {"total": 1, "dirty": 0}}))
EOF
mkdir -p "$stub_root/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub_root/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/pulse.sh" "$stub_root/tools/scripts/pulse.sh"
chmod +x "$stub_root/tools/scripts/pulse.sh"

# The stub tree needs the quality gates too, or this step measures whether they
# are present rather than what --no-stack does. Each is the smallest passing
# command that satisfies the gate's contract.
mkdir -p "$stub_root/scripts" "$stub_root/tests"
for gate in "scripts/check-runtime-authority.sh" "scripts/check-skills.sh" \
            "tests/registry-consumer-parity-smoke.sh" "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub_root/$gate"
  chmod +x "$stub_root/$gate"
done
# The registry gate is run with `python3`, not by its shebang, so a bash stub
# here would fail to parse and report the gate as broken rather than passing.
printf 'raise SystemExit(0)\n' > "$stub_root/tools/scripts/validate-command-registry.py"
chmod +x "$stub_root/tools/scripts/validate-command-registry.py"
# git init, because the git collector reads this tree — and reports UNAVAILABLE
# rather than "clean" when it is not a repository, which step 10 covers.
git -C "$stub_root" init -q
git -C "$stub_root" config user.email t@example.com
git -C "$stub_root" config user.name Test
git -C "$stub_root" add -A >/dev/null 2>&1
git -C "$stub_root" commit -qm "stub"

status=0
out="$(MACOS_SCRIPTS_HOME="$stub_root" bash "$stub_root/tools/scripts/pulse.sh" \
  --no-stack --no-network </dev/null 2>&1)" || status=$?
if [[ "$status" -ne 1 ]]; then
  # 1, not 0: the scratch repo has no upstream, which the git collector reports
  # as UNAVAILABLE rather than claiming nothing is unpushed. A run where one
  # thing genuinely cannot be measured is a warning, and that is the contract.
  echo "FAIL: the stub run exited $status, expected 1" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
for needed in 'skipped by --no-stack' 'skipped by --no-network' 'Pulse: WARN'; do
  grep -qF "$needed" <<< "$out" || {
    echo "FAIL: the run lost: $needed" >&2
    printf '%s\n' "$out" >&2
    exit 1
  }
done

# A skipped area must not be able to raise the verdict, and a warning must.
cat > "$stub_root/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"},{"name":"jq","status":"warn"}]}'
EOF
chmod +x "$stub_root/tools/scripts/doctor.sh"
status=0
MACOS_SCRIPTS_HOME="$stub_root" bash "$stub_root/tools/scripts/pulse.sh" \
  --no-stack --no-network </dev/null >/dev/null 2>&1 || status=$?
[[ "$status" -eq 1 ]] || { echo "FAIL: a warning run exited $status, expected 1" >&2; exit 1; }

status=0
MACOS_SCRIPTS_HOME="$stub_root" bash "$stub_root/tools/scripts/pulse.sh" --nonsense </dev/null >/dev/null 2>&1 || status=$?
[[ "$status" -eq 2 ]] || { echo "FAIL: an unknown flag exited $status, expected 2" >&2; exit 1; }
echo "  ok: 1 on a warning, 2 on a usage error, both skips stay visible"

echo "[11/11] a directory that is not a repository is never reported as clean"
# The failure this closes: `git status --short` fails in a non-repository, its
# output is empty, and empty reads exactly like a clean tree. The collector
# reported "Worktree: clean" about a directory with no .git at all — a wrong
# answer arrived at through a silent error, which is the shape docs/PULSE_CONTRACT.md
# exists to forbid.
not_a_repo="$run_dir/plain"
mkdir -p "$not_a_repo"
( export BASE_DIR="$not_a_repo"
  pulse_items_reset
  pulse_collect_git 1
  states="$(pulse_items_states | tr '\n' ' ')"
  [[ "$states" == "UNAVAILABLE " ]] || {
    echo "FAIL: a non-repository gave '$states'" >&2; exit 1; }
  summary="$(pulse_item_field "${PULSE_ITEMS[0]}" summary)"
  [[ "$summary" == "not a git repository" ]] || {
    echo "FAIL: summary was '$summary'" >&2; exit 1; }
)
echo "  ok: UNAVAILABLE, and the run stops before asking GitHub about no branch"

echo "PASS: pulse item model and core collectors"
