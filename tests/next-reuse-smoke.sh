#!/usr/bin/env bash
# Holds document reuse between `mqlaunch pulse` and `mqlaunch next`.
#
# Running both by hand used to pay for the collection twice — about 4s each,
# most of it calls into other repos. v2.1.0 recorded that as an accepted cost
# because the fix needed a freshness contract nobody had written. v2.2.0 P0
# wrote it, so the reuse rule can be stated in terms of facts the document
# already carries rather than a TTL Pulse would have had to invent:
#
#   reuse   when the document is complete enough and young enough
#   collect otherwise
#
# Two halves, and they fail in opposite directions. Refusing to reuse costs 4s.
# Reusing something it should not — a scoped run, a `--no-network` run, or a
# document from an hour ago — answers a question about the machine as it is with
# an observation of the machine as it was, which is the failure the whole
# freshness contract exists to prevent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: next document reuse"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CACHE="$TMP/cache/pulse.json"
fail() { echo "FAIL: $1" >&2; exit 1; }

# ---------------------------------------------------------------- writing side
# The real pulse.sh, against stub collectors. What is under test here is which
# runs leave a document behind, which is pulse's decision and not next's.
wstub="$TMP/wstub"
mkdir -p "$wstub/tools/scripts" "$wstub/scripts" "$wstub/tests" "$wstub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$wstub/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/pulse.sh" "$wstub/tools/scripts/pulse.sh"
cat > "$wstub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$wstub/tools/scripts/doctor.sh"
cat > "$wstub/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [], "summary": {"total": 0, "dirty": 0}}))
EOF
printf 'raise SystemExit(0)\n' > "$wstub/tools/scripts/validate-command-registry.py"
for gate in "scripts/check-runtime-authority.sh" "scripts/check-skills.sh" \
            "tests/registry-consumer-parity-smoke.sh" "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$wstub/$gate"
  chmod +x "$wstub/$gate"
done
git -C "$wstub" init -q
git -C "$wstub" config user.email t@example.com
git -C "$wstub" config user.name Test
git -C "$wstub" add -A >/dev/null 2>&1
git -C "$wstub" commit -qm stub

run_pulse() {
  set +e
  MACOS_SCRIPTS_HOME="$wstub" MQ_AGENT_BIN="$TMP/absent" MQ_PULSE_CACHE="$CACHE" \
    NO_COLOR=1 bash "$wstub/tools/scripts/pulse.sh" "$@" >"$TMP/pulse.out" 2>"$TMP/pulse.err" </dev/null
  set -e
}

echo "[1/9] a complete run leaves a document behind, without being asked for one"
# The panel is the mode an operator actually types. If only --json wrote the
# cache, the exit gate for this block — pulse then next costs one collection —
# would be met by nobody.
rm -rf "$TMP/cache"
# No flags: a complete run is what the slot is for, and the test must not ask
# for one thing while measuring another.
run_pulse
test -s "$CACHE" || fail "a panel-mode run left no document at $CACHE"
python3 - "$CACHE" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc["schema"] == "mq.pulse.v1", doc["schema"]
assert doc["scope"] is None, doc["scope"]
assert "collected_at" in doc and "conditions" in doc, sorted(doc)
print("  ok: the panel run wrote a full mq.pulse.v1 document")
PY

echo "[2/9] a scoped run does not evict the complete one"
# One slot, so whoever writes last wins. A scoped run overwriting the full
# document would make the cache emptier the more Pulse gets used — and the next
# reader would collect again while a perfectly good document had just been
# thrown away.
before="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["collected_at"])' "$CACHE")"
run_pulse quality
after="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["collected_at"])' "$CACHE")"
scope_now="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["scope"])' "$CACHE")"
[[ "$before" == "$after" ]] || fail "a scoped run replaced the cached document"
[[ "$scope_now" == "None" ]] || fail "the cache now holds a scoped document: $scope_now"
echo "  ok: the slot still holds the full run"

# ---------------------------------------------------------------- reading side
# A stub pulse.sh that records every call, so "did it collect" is countable
# rather than inferred from how long the run took.
rstub="$TMP/rstub"
mkdir -p "$rstub/tools/scripts" "$rstub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/next" "$rstub/mqlaunch/lib/next"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$rstub/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/next.sh" "$rstub/tools/scripts/next.sh"
chmod +x "$rstub/tools/scripts/next.sh"
cat > "$rstub/tools/scripts/pulse.sh" <<EOF
#!/usr/bin/env bash
echo collected >> "$TMP/collect.log"
python3 - <<'PY'
import datetime, json
now = datetime.datetime.now().astimezone().replace(microsecond=0).isoformat()
print(json.dumps({
    "schema": "mq.pulse.v1", "status": "WARN", "scope": None,
    "collected": ["system"], "collected_at": now,
    "conditions": {"no_stack": False, "no_network": False},
    "summary": {"pass": 0, "warn": 1, "fail": 0, "unavailable": 0, "skipped": 0},
    "sections": {"system": []},
    "attention": [{"source": "stub", "area": "system", "status": "WARN",
                   "subject": "Freshly collected", "summary": "from the stub",
                   "next_command": "mqlaunch doctor", "priority": 0}],
}, indent=2))
PY
exit 1
EOF
chmod +x "$rstub/tools/scripts/pulse.sh"

# Plants a document in the cache. AGE is seconds in the past.
plant() { # AGE SCOPE NO_STACK NO_NETWORK SUBJECT
  mkdir -p "$(dirname "$CACHE")"
  AGE="$1" SCOPE="$2" NO_STACK="$3" NO_NETWORK="$4" SUBJECT="$5" \
  python3 - "$CACHE" <<'PY'
import datetime, json, os, sys
when = datetime.datetime.now().astimezone().replace(microsecond=0) \
    - datetime.timedelta(seconds=int(os.environ["AGE"]))
json.dump({
    "schema": "mq.pulse.v1", "status": "WARN",
    "scope": os.environ["SCOPE"] or None,
    "collected": ["system"], "collected_at": when.isoformat(),
    "conditions": {"no_stack": os.environ["NO_STACK"] == "1",
                   "no_network": os.environ["NO_NETWORK"] == "1"},
    "summary": {"pass": 0, "warn": 1, "fail": 0, "unavailable": 0, "skipped": 0},
    "sections": {"system": []},
    "attention": [{"source": "cache", "area": "system", "status": "WARN",
                   "subject": os.environ["SUBJECT"], "summary": "from the cache",
                   "next_command": "mqlaunch doctor", "priority": 0}],
}, open(sys.argv[1], "w"), indent=2)
PY
}

run_next() {
  set +e
  OUT="$(MACOS_SCRIPTS_HOME="$rstub" MQ_PULSE_CACHE="$CACHE" NO_COLOR=1 \
    "$rstub/tools/scripts/next.sh" "$@" 2>"$TMP/next.err")"
  RC=$?
  set -e
}

collections() { [[ -f "$TMP/collect.log" ]] && wc -l < "$TMP/collect.log" | tr -d ' ' || echo 0; }

echo "[3/9] a fresh complete document is reused, and the screen says so"
rm -f "$TMP/collect.log"
plant 41 "" 0 0 "From the cache"
run_next
[[ "$(collections)" == "0" ]] || fail "next collected although a fresh document was there"
grep -q "From the cache" <<<"$OUT" || fail "next did not select from the cached document: $OUT"
grep -qi "reused" <<<"$OUT" || fail "the screen did not say the document was reused: $OUT"
grep -q "41s\|4[0-9]s" <<<"$OUT" || fail "the screen did not print the age: $OUT"
grep -q -- "--fresh" <<<"$OUT" || fail "the screen did not name the way to re-measure: $OUT"
# Where the answer came from must not change what `$?` means. A reused WARN is
# still a WARN, and a script that branches on the exit code cannot be made to
# see something different by the cache having been warm.
[[ "$RC" == "1" ]] || fail "a reused WARN finding exited $RC, not 1"
echo "  ok: reused, labelled with its age, exit code unchanged"

echo "[4/9] a document past the tolerance is not reused"
# Stale cached data must never render as live state. The window is next's own
# declaration, not a TTL Pulse published: the reader owns the tolerance.
rm -f "$TMP/collect.log"
plant 9000 "" 0 0 "From the cache"
run_next
[[ "$(collections)" == "1" ]] || fail "an hours-old document was reused"
grep -q "Freshly collected" <<<"$OUT" || fail "next did not collect: $OUT"
echo "  ok: collected instead, and the stale document did not reach the screen"

echo "[5/9] a document collected under a skip flag does not satisfy a full run"
# The asymmetry is the point. A full document answers a narrower question; a
# narrower document cannot answer a full one, and reusing it would report on
# areas the run never reached.
for flags in "1 0" "0 1"; do
  # shellcheck disable=SC2086
  set -- $flags
  rm -f "$TMP/collect.log"
  plant 10 "" "$1" "$2" "From the cache"
  run_next
  [[ "$(collections)" == "1" ]] \
    || fail "a document with no_stack=$1 no_network=$2 was reused for a full run"
done
echo "  ok: neither a --no-stack nor a --no-network document is reused"

echo "[6/9] --fresh collects even when a reusable document is there"
rm -f "$TMP/collect.log"
plant 5 "" 0 0 "From the cache"
run_next --fresh
[[ "$(collections)" == "1" ]] || fail "--fresh reused the cache"
[[ "$RC" == "1" ]] || fail "a collected WARN finding exited $RC, not 1"
grep -q "Freshly collected" <<<"$OUT" || fail "--fresh did not collect: $OUT"
grep -qi "reused" <<<"$OUT" && fail "--fresh claimed a reuse: $OUT"
echo "  ok: collected unconditionally, and claimed no reuse"

echo "[7/9] --input neither reads the cache nor writes it"
# A caller that named a document gets that document, whatever the cache holds
# and whatever age it is. Writing the cache from --input would let a caller
# plant an arbitrary document as this machine's last observation.
rm -f "$TMP/collect.log"
plant 5 "" 0 0 "From the cache"
cp "$CACHE" "$TMP/named.json"
python3 - "$TMP/named.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
doc["attention"][0]["subject"] = "From the named file"
json.dump(doc, open(sys.argv[1], "w"), indent=2)
PY
cached_before="$(cat "$CACHE")"
run_next --input "$TMP/named.json"
[[ "$(collections)" == "0" ]] || fail "--input collected"
grep -q "From the named file" <<<"$OUT" || fail "--input did not use the named file: $OUT"
grep -qi "reused" <<<"$OUT" && fail "--input claimed a cache reuse: $OUT"
[[ "$cached_before" == "$(cat "$CACHE")" ]] || fail "--input wrote the cache"
echo "  ok: the named file was used, the cache untouched in both directions"

echo "[8/9] --json is one document, and it carries the age of what it read"
# The machine mode has the same duty the screen has: a consumer must be able to
# tell how old the observation is. The reuse notice is a human affordance and
# must not reach stdout here.
rm -f "$TMP/collect.log"
plant 12 "" 0 0 "From the cache"
run_next --json
printf '%s\n' "$OUT" > "$TMP/next.json"
python3 - "$TMP/next.json" <<'PY'
import datetime, json, sys
doc = json.load(open(sys.argv[1]))
assert doc["schema"] == "mq.next.v1", doc["schema"]
assert doc["item"]["subject"] == "From the cache", doc["item"]
stamp = datetime.datetime.fromisoformat(doc["collected_at"])
age = datetime.datetime.now().astimezone() - stamp
assert 5 <= age.total_seconds() <= 120, age.total_seconds()
print("  ok: mq.next.v1 echoes collected_at, and stdout is one document")
PY
grep -qi "reused" <<<"$OUT" && fail "the reuse notice reached stdout in --json"

echo "[9/9] the slot is per checkout, and stable for one"
# A Pulse document is not purely a statement about the machine: QUALITY is this
# repo running its own gates and GIT is this worktree. Two checkouts sharing one
# slot would let `next` in one answer with an observation of the other. Found by
# tests/next-command-smoke.sh reading the real user cache from inside its stub
# tree, which is the same defect from the other side.
paths="$(bash -c '
  source "'"$ROOT"'/mqlaunch/lib/pulse/cache.sh"
  BASE_DIR=/one/checkout pulse_cache_path; echo
  BASE_DIR=/another/checkout pulse_cache_path; echo
  BASE_DIR=/one/checkout pulse_cache_path; echo
  MQ_PULSE_CACHE=/named/file.json BASE_DIR=/one/checkout pulse_cache_path; echo
')"
first="$(sed -n 1p <<<"$paths")"
second="$(sed -n 2p <<<"$paths")"
again="$(sed -n 3p <<<"$paths")"
named="$(sed -n 4p <<<"$paths")"

[[ "$first" != "$second" ]] || fail "two checkouts share one slot: $first"
[[ "$first" == "$again" ]] || fail "the slot moved between two calls: $first vs $again"
[[ "$named" == "/named/file.json" ]] || fail "MQ_PULSE_CACHE did not win: $named"
echo "  ok: distinct per checkout, stable within one, and overridable"

echo "OK: next document reuse smoke test passed"
