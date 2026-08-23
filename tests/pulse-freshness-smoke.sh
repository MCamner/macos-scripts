#!/usr/bin/env bash
# Holds the freshness half of `mq.pulse.v1`: when the run was collected, and
# under which conditions.
#
# The rule this file exists for is one step past the contract's absence rule.
# `collected` says which areas ran and `scope` says what was asked for, but
# neither says anything about *when*, and a document read from a file is not
# distinguishable from one collected a second ago:
#
#   an age  is a fact about the observation      Pulse states it
#   a TTL   is a claim about the subject         Pulse must not state it
#
# So the document carries the stamp and the flags, and the decision about
# whether that is fresh enough belongs to whoever reads it. Nothing here checks
# a tolerance, because publishing one would be the invented freshness claim
# docs/PULSE_CONTRACT.md forbids.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULSE="$ROOT/tools/scripts/pulse.sh"

echo "SMOKE: pulse freshness"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

stub="$run_dir/stub"
mkdir -p "$stub/tools/scripts" "$stub/scripts" "$stub/tests" "$stub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$PULSE" "$stub/tools/scripts/pulse.sh"

cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$stub/tools/scripts/doctor.sh"

pulse_run() {
  local out="$1"; shift
  set +e
  MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$run_dir/absent" NO_COLOR=1 \
    "$@" >"$run_dir/$out.out" 2>"$run_dir/$out.err" </dev/null
  echo $? > "$run_dir/$out.status"
  set -e
}

echo "[1/5] the document says when it was collected, in a form with an offset"
# Seconds and an explicit offset, both required. A stamp without an offset is
# only readable by someone who already knows which machine produced it, which
# is the opposite of what a published document is for.
pulse_run stamped bash "$stub/tools/scripts/pulse.sh" system --json
python3 - "$run_dir/stamped.out" <<'PY'
import datetime, json, sys

doc = json.load(open(sys.argv[1]))
assert "collected_at" in doc, "the document does not say when it was collected"
stamp = doc["collected_at"]
parsed = datetime.datetime.fromisoformat(stamp)
assert parsed.utcoffset() is not None, f"no UTC offset in {stamp!r}"
assert parsed.second is not None and len(stamp) >= 25, \
    f"expected RFC 3339 with seconds and an offset, got {stamp!r}"
print(f"  ok: collected_at {stamp}")
PY

echo "[2/5] conditions are the flags the operator gave, not their effect"
# The distinction the field exists for. `pulse system` reaches neither the
# stack nor the network, so a document that recorded what the run happened to
# touch would report the same conditions for both of these runs — and a reused
# document would then read as more complete than it is.
pulse_run declared bash "$stub/tools/scripts/pulse.sh" system --json --no-stack --no-network
python3 - "$run_dir/stamped.out" "$run_dir/declared.out" <<'PY'
import json, sys

plain = json.load(open(sys.argv[1]))
flagged = json.load(open(sys.argv[2]))

assert plain["conditions"] == {"no_stack": False, "no_network": False}, \
    plain["conditions"]
assert flagged["conditions"] == {"no_stack": True, "no_network": True}, \
    flagged["conditions"]
print("  ok: an unflagged run and a flagged one declare different conditions")
PY

echo "[3/5] collected_at marks the start of collection, not the print"
# Stamping when the document is written understates its age by however long the
# run took, and understating age is the one direction a freshness field must
# never err in: a consumer that reuses a document decides on this number.
cat > "$stub/scripts/check-skills.sh" <<'EOF'
#!/usr/bin/env bash
sleep 3
EOF
chmod +x "$stub/scripts/check-skills.sh"
for gate in "scripts/check-runtime-authority.sh" "tests/registry-consumer-parity-smoke.sh" \
            "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/$gate"
  chmod +x "$stub/$gate"
done
printf 'raise SystemExit(0)\n' > "$stub/tools/scripts/validate-command-registry.py"
pulse_run slow bash "$stub/tools/scripts/pulse.sh" quality --json
printed="$(date +%s)"
python3 - "$run_dir/slow.out" "$printed" <<'PY'
import datetime, json, sys

doc = json.load(open(sys.argv[1]))
stamp = datetime.datetime.fromisoformat(doc["collected_at"])
elapsed = int(sys.argv[2]) - stamp.timestamp()
assert elapsed >= 2, (
    f"the run took at least 3s and the stamp is {elapsed:.1f}s old — "
    "it was taken when the document was printed, not when collection began")
print(f"  ok: a 3s run publishes a stamp {elapsed:.0f}s before it printed")
PY

echo "[4/5] the screen reads the run's stamp and never the clock"
# A renderer that called date would print a time the document does not carry,
# and the two would disagree the moment a document is rendered after the fact.
# The stamp below is deliberately not today's.
PULSE_RENDER_PROBE="$run_dir/render.out"
bash -c '
  set -uo pipefail
  source "'"$ROOT"'/mqlaunch/lib/pulse/item.sh"
  source "'"$ROOT"'/mqlaunch/lib/pulse/render.sh"
  pulse_items_reset
  pulse_item_add system system PASS "Shell" "bash 5.2"
  PULSE_COLLECTED_AT="2019-03-04T05:06:07+01:00" pulse_render PASS
  echo "---"
  PULSE_COLLECTED_AT="" pulse_render PASS
' > "$PULSE_RENDER_PROBE" 2>"$run_dir/render.err" </dev/null

with_stamp="$(sed -n '1,/^---$/p' "$PULSE_RENDER_PROBE")"
without_stamp="$(sed -n '/^---$/,$p' "$PULSE_RENDER_PROBE")"

if ! grep -q '05:06:07' <<<"$with_stamp"; then
  echo "FAIL: the panel did not print the stamp the run carried" >&2
  cat "$PULSE_RENDER_PROBE" >&2
  exit 1
fi
if grep -qE '[0-9]{2}:[0-9]{2}:[0-9]{2}' <<<"$without_stamp"; then
  echo "FAIL: with no stamp the panel printed a time anyway — it read the clock" >&2
  cat "$PULSE_RENDER_PROBE" >&2
  exit 1
fi
echo "  ok: the panel shows 05:06:07, and shows nothing when the run has no stamp"

echo "[5/5] a run that cannot stamp itself publishes no document"
# The same rule the gates were held to in #216, one floor down: an unstamped
# document is not a document with one field missing, it is a freshness claim
# nobody can evaluate. Refusing is what keeps a consumer from having to guess.
set +e
unstamped="$(bash -c '
  set -uo pipefail
  source "'"$ROOT"'/mqlaunch/lib/pulse/item.sh"
  source "'"$ROOT"'/mqlaunch/lib/pulse/document.sh"
  pulse_items_reset
  pulse_item_add system system PASS "Shell" "bash 5.2"
  PULSE_COLLECTED_AT="" pulse_document PASS "" system
' 2>"$run_dir/unstamped.err")"
unstamped_status=$?
set -e

if [[ $unstamped_status -eq 0 ]]; then
  echo "FAIL: an unstamped run serialized a document anyway" >&2
  printf '%s\n' "$unstamped" >&2
  exit 1
fi
if ! grep -qi 'collected_at\|stamp' "$run_dir/unstamped.err"; then
  echo "FAIL: the refusal does not say what was missing" >&2
  cat "$run_dir/unstamped.err" >&2
  exit 1
fi
echo "  ok: refused, and the diagnostic names the missing stamp"

echo "OK: pulse freshness smoke test passed"
