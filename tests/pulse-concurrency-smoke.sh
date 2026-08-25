#!/usr/bin/env bash
# Holds what running the six collectors at once must not change.
#
# The gates inside `quality` and the two `gh` reads inside `git` were already
# concurrent. This is the same move one level up, and the reason it waited is a
# rule that is true but narrower than it was being applied: two collectors shell
# into mq-agent through the same `uv` project. That is a constraint on those two,
# and it had been read as a constraint on all six.
#
# Concurrency is not what this file tests. Speed is a number and numbers belong
# in ROADMAP.md; what belongs in a gate is the property that must survive:
#
#   the lanes decide when      the list decides the order
#
# A panel that reshuffled because a network call was fast would make two runs of
# the same command unreadable against each other, and the item order is also the
# order `attention` breaks ties in. The other half is subshell discipline: a
# child cannot append to PULSE_ITEMS, so a collector whose findings are lost on
# the way back is the failure this whole contract exists to prevent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: pulse collector concurrency"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

stub="$TMP/stub"
mkdir -p "$stub/tools/scripts" "$stub/scripts" "$stub/tests" "$stub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/pulse.sh" "$stub/tools/scripts/pulse.sh"

cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$stub/tools/scripts/doctor.sh"
cat > "$stub/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [], "summary": {"total": 0, "dirty": 0}}))
EOF
printf 'raise SystemExit(0)\n' > "$stub/tools/scripts/validate-command-registry.py"
for gate in "scripts/check-runtime-authority.sh" "scripts/check-skills.sh" \
            "tests/registry-consumer-parity-smoke.sh" "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/$gate"
  chmod +x "$stub/$gate"
done
git -C "$stub" init -q
git -C "$stub" config user.email t@example.com
git -C "$stub" config user.name Test
git -C "$stub" add -A >/dev/null 2>&1
git -C "$stub" commit -qm stub

pulse_run() {
  local out="$1"; shift
  set +e
  MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$TMP/absent" MQ_PULSE_CACHE="$TMP/cache.json" \
    NO_COLOR=1 bash "$stub/tools/scripts/pulse.sh" "$@" >"$TMP/$out.out" 2>"$TMP/$out.err" </dev/null
  echo $? > "$TMP/$out.status"
  set -e
}

echo "[1/6] the areas are reported in list order, whatever finished first"
# The slowest area is deliberately the first one on the screen. If the run were
# assembled in completion order, SYSTEM would sink to the bottom — which is
# exactly the drift the quality gates were held to at their own level.
cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
sleep 2
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$stub/tools/scripts/doctor.sh"
pulse_run slowfirst --json --no-network
python3 - "$TMP/slowfirst.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
order = [area for area in doc["sections"]]
expected = ["system", "repositories", "stack", "memory", "git", "quality"]
assert order == expected, f"areas came back as {order}"
assert doc["sections"]["system"], "the slow area lost its item"
print("  ok: system is still first, having finished last")
PY

echo "[2/6] the slowest lane bounds the run, not the sum of the lanes"
# The property concurrency is for, stated as a bound rather than as a number so
# the gate does not fail on a busy machine. Two collectors sleep two seconds
# each: serial they cost four, concurrent they cost about two.
cat > "$stub/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json, time
time.sleep(2)
print(json.dumps({"repos": [], "summary": {"total": 0, "dirty": 0}}))
EOF
started="$(python3 -c 'import time; print(time.time())')"
pulse_run twoslow --json --no-network
elapsed="$(python3 -c "import time; print(time.time() - $started)")"
python3 - "$elapsed" <<'PY'
import sys
elapsed = float(sys.argv[1])
assert elapsed < 3.5, (
    f"two 2s collectors took {elapsed:.1f}s — they ran one after the other")
print(f"  ok: two 2s collectors cost {elapsed:.1f}s together")
PY
cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$stub/tools/scripts/doctor.sh"
cat > "$stub/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [], "summary": {"total": 0, "dirty": 0}}))
EOF

echo "[3/6] no lane loses its items on the way back to the parent"
# A child cannot append to PULSE_ITEMS. The lane serializes and the parent
# absorbs, and this is the step that fails if that handover is ever replaced
# with something that looks simpler.
pulse_run whole --json --no-network
python3 - "$TMP/whole.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
for area in ("system", "repositories", "stack", "memory", "git", "quality"):
    assert doc["sections"].get(area), f"{area} came back with no items"
gates = doc["sections"]["quality"]
assert len(gates) == 5, f"the quality lane returned {len(gates)} gates, not 5"
held = sum(len(items) for items in doc["sections"].values())
counted = sum(doc["summary"].values())
assert held == counted, f"{held} items but the summary counts {counted}"
print(f"  ok: {held} items across six areas, and the summary agrees")
PY

echo "[4/6] a skipped pair keeps its place in the order"
# --no-stack runs no collector, so those items are added by the parent rather
# than absorbed from a lane. They must still land between REPOSITORIES and GIT:
# a skipped area that drifted to the end would read as a different run.
pulse_run skipped --json --no-network --no-stack
python3 - "$TMP/skipped.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
order = list(doc["sections"])
assert order == ["system", "repositories", "stack", "memory", "git", "quality"], order
for area in ("stack", "memory"):
    states = {i["status"] for i in doc["sections"][area]}
    assert states == {"SKIPPED"}, f"{area} reported {states}"
print("  ok: the skipped pair is still third and fourth, as SKIPPED")
PY

echo "[5/6] a scoped run collects one area and says so"
# Scoping decides which lanes are launched at all. A lane that ran anyway would
# make `pulse repos` pay for the stack, and `collected` would be a lie about it.
pulse_run scoped repos --json
python3 - "$TMP/scoped.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
assert doc["scope"] == "repos", doc["scope"]
assert doc["collected"] == ["repositories"], doc["collected"]
assert list(doc["sections"]) == ["repositories"], list(doc["sections"])
print("  ok: one lane launched, one area collected and declared")
PY

echo "[6/6] a collector that dies hands over what it had already found"
# The failure mode the lanes introduce and the in-process version did not have:
# items live in a child now, so a collector that exits early could take the
# whole area with it. The flush is on EXIT for this reason.
probe="$TMP/probe.out"
bash -c '
  set -uo pipefail
  source "'"$ROOT"'/mqlaunch/lib/pulse/collectors.sh"
  half_a_collector() {
    pulse_item_add system system PASS "First" "found before the exit"
    exit 0
    pulse_item_add system system PASS "Second" "never reached"
  }
  pulse_area_probe "'"$probe"'" half_a_collector
  pulse_items_reset
  pulse_area_absorb "'"$probe"'"
  printf "%s\n" "${#PULSE_ITEMS[@]}"
' > "$TMP/flush.out" 2>"$TMP/flush.err" </dev/null

count="$(tail -1 "$TMP/flush.out")"
[[ "$count" == "1" ]] || {
  cat "$TMP/flush.err" >&2
  fail "a collector that exited early handed over $count items, not 1"
}
grep -q "First" "$probe" || fail "the item found before the exit was lost"
echo "  ok: the item found before the exit survived the handover"

echo "OK: pulse collector concurrency smoke test passed"
