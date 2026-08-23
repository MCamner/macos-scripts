#!/usr/bin/env bash
# Holds `mq.pulse.v1` — the machine surface a script is allowed to build on.
#
# The four properties this gate exists for, each of them a way the document
# could quietly stop meaning what it says:
#
#   1. full and scoped runs use the same schema, and a scoped run says which
#      areas it collected — an absent section is never a healthy area
#   2. SKIPPED and UNAVAILABLE survive into the document as themselves
#   3. attention is the same item objects the sections hold, in the engine's
#      order — not a second data kind that could drift from them
#   4. stdout is one JSON document and nothing else; diagnostics go to stderr
#
# Plus the exit codes, which are the contract for anything that does not parse
# the document at all, and are asserted equal across all three output modes: a
# script reading the status from `$?` must get the same answer as one reading
# `.status`.
#
# Everything runs against a stub tree. The real collectors reach mq-agent, gh
# and this repo's own gates, and a gate that ran those would be measuring this
# machine rather than the serializer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULSE="$ROOT/tools/scripts/pulse.sh"

echo "SMOKE: pulse machine surface (mq.pulse.v1)"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

stub="$run_dir/stub"
mkdir -p "$stub/tools/scripts" "$stub/scripts" "$stub/tests" "$stub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$PULSE" "$stub/tools/scripts/pulse.sh"

# The doctor and repos stubs are rewritten per case; the rest stay put.
make_doctor() {
  cat > "$stub/tools/scripts/doctor.sh"
  chmod +x "$stub/tools/scripts/doctor.sh"
}

make_repos() {
  cat > "$stub/tools/scripts/mq-repos.py"
}

make_doctor <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"},{"name":"gh","status":"ok"}]}'
EOF

make_repos <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [
  {"name": "mq-agent", "git": True, "clean": True, "modified": 0,
   "untracked": 0, "branch": "main", "upstream": "origin/main",
   "ahead": 0, "behind": 0},
  {"name": "mqobsidian", "git": True, "clean": False, "modified": 2,
   "untracked": 1, "branch": "main", "upstream": "origin/main",
   "ahead": 0, "behind": 0}],
  "summary": {"total": 2, "dirty": 1}}))
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

# One run of the stub tree. Prints stdout; stderr and the exit code land in
# files so that each can be asserted on separately.
pulse_run() {
  local out="$1"; shift
  set +e
  MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$run_dir/absent" NO_COLOR=1 \
    bash "$stub/tools/scripts/pulse.sh" "$@" \
    >"$run_dir/$out.out" 2>"$run_dir/$out.err" </dev/null
  echo $? > "$run_dir/$out.status"
  set -e
  cat "$run_dir/$out.out"
}

echo "[1/9] a full run prints one mq.pulse.v1 document and nothing else"
pulse_run full --json --no-network >/dev/null
python3 - "$run_dir/full.out" <<'PY'
import json, sys

raw = open(sys.argv[1], "rb").read()
assert b"\x1b" not in raw, "the document carries ANSI"
doc = json.loads(raw)  # one document, not a document plus a banner
assert doc["schema"] == "mq.pulse.v1", doc["schema"]
assert doc["status"] in {"PASS", "WARN", "FAIL", "INCOMPLETE"}, doc["status"]
assert doc["scope"] is None, doc["scope"]
assert set(doc["collected"]) == {
    "system", "repositories", "stack", "memory", "git", "quality"}, doc["collected"]
counted = sum(doc["summary"].values())
held = sum(len(v) for v in doc["sections"].values())
assert counted == held, f"summary counts {counted} items, sections hold {held}"
print(f"  ok: schema, status {doc['status']}, {held} items in "
      f"{len(doc['sections'])} sections")
PY

echo "[2/9] a noisy delegate cannot reach stdout, and is not read as healthy"
# The leak path that matters: a delegate that prints a warning line before its
# document. Passing that through would make `| jq .` fail on output the caller
# never asked for; treating the unparseable result as an empty run would be the
# contract's first line — "command failed + empty output is not healthy".
make_repos <<'EOF'
#!/usr/bin/env python3
import json, sys
print("mq-repos: warning, this line is not part of the document")
print("mq-repos: and this one went to stderr", file=sys.stderr)
print(json.dumps({"repos": [], "summary": {"total": 0, "dirty": 0}}))
EOF
pulse_run noisy repos --json >/dev/null
python3 - "$run_dir/noisy.out" <<'PY'
import json, sys

raw = open(sys.argv[1], "rb").read().decode()
assert "not part of the document" not in raw, "a delegate's stdout noise leaked through"
assert "went to stderr" not in raw, "a delegate's stderr reached the JSON stdout"
doc = json.loads(raw)  # still exactly one document
states = {i["status"] for i in doc["sections"]["repositories"]}
assert states == {"UNAVAILABLE"}, f"an unreadable delegate reported {states}"
assert doc["status"] == "WARN", doc["status"]
print("  ok: one clean document, and the unreadable area is UNAVAILABLE")
PY
# Back to the good stub — every later step reads a run that worked.
make_repos <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [
  {"name": "mq-agent", "git": True, "clean": True, "modified": 0,
   "untracked": 0, "branch": "main", "upstream": "origin/main",
   "ahead": 0, "behind": 0},
  {"name": "mqobsidian", "git": True, "clean": False, "modified": 2,
   "untracked": 1, "branch": "main", "upstream": "origin/main",
   "ahead": 0, "behind": 0}],
  "summary": {"total": 2, "dirty": 1}}))
EOF

echo "[3/9] a scoped run uses the same schema and says what it collected"
# The failure this prevents: reading a scoped document as though the five
# absent areas had been checked and found healthy.
pulse_run scoped repos --json >/dev/null
python3 - "$run_dir/scoped.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
assert doc["schema"] == "mq.pulse.v1", doc["schema"]
assert set(doc) == {"schema", "status", "scope", "collected", "collected_at",
                    "conditions", "summary", "sections", "attention"}, sorted(doc)
assert doc["scope"] == "repos", doc["scope"]
assert doc["collected"] == ["repositories"], doc["collected"]
assert set(doc["sections"]) == {"repositories"}, sorted(doc["sections"])
print("  ok: same keys as a full run, one area collected and declared")
PY

echo "[4/9] SKIPPED and UNAVAILABLE are in the document as themselves"
# mq-agent is absent here, so the stack is UNAVAILABLE; --no-stack makes it
# SKIPPED instead. Both must be present and distinct — a document that dropped
# them would make a skipped run and a healthy run identical.
pulse_run unavailable stack --json >/dev/null
pulse_run skipped stack --json --no-stack >/dev/null
python3 - "$run_dir/unavailable.out" "$run_dir/skipped.out" <<'PY'
import json, sys

unavailable = json.load(open(sys.argv[1]))
skipped = json.load(open(sys.argv[2]))

states = {i["status"] for i in unavailable["sections"]["stack"]}
assert states == {"UNAVAILABLE"}, f"unreachable mq-agent reported {states}"
assert unavailable["summary"]["unavailable"] == 1, unavailable["summary"]

states = {i["status"] for i in skipped["sections"]["stack"]}
assert states == {"SKIPPED"}, f"--no-stack reported {states}"
assert skipped["summary"]["skipped"] == 1, skipped["summary"]
assert skipped["collected"] == ["stack"], skipped["collected"]
print("  ok: UNAVAILABLE and SKIPPED both present, and not each other")
PY

echo "[5/9] attention holds the section's own items, in the engine's order"
# Not a parallel list. Every entry must appear in a section byte for byte, so
# the two can never describe the run differently.
python3 - "$run_dir/full.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
in_sections = [i for items in doc["sections"].values() for i in items]
serialized = [json.dumps(i, sort_keys=True) for i in in_sections]

for entry in doc["attention"]:
    key = json.dumps(entry, sort_keys=True)
    assert key in serialized, f"attention entry is in no section: {entry}"
    assert entry["status"] in {"WARN", "FAIL", "UNAVAILABLE"}, entry["status"]

findings = [i for i in in_sections
            if i["status"] in {"WARN", "FAIL", "UNAVAILABLE"}]
keyed = {i.get("dedupe_key") for i in findings if i.get("dedupe_key")}
lowest = len(findings) - max(0, len(
    [i for i in findings if i.get("dedupe_key")]) - len(keyed))
assert len(doc["attention"]) == lowest, \
    f"{len(findings)} findings, {len(doc['attention'])} in attention, expected {lowest}"
assert doc["attention"], "the stub tree has findings, so this must not be empty"
print(f"  ok: {len(doc['attention'])} findings, every one of them a section item")
PY

echo "[6/9] every output mode reports the same state and the same exit code"
pulse_run panel --no-network >/dev/null
pulse_run plain --plain --no-network >/dev/null
json_status="$(cat "$run_dir/full.status")"
for mode in panel plain; do
  if [[ "$(cat "$run_dir/$mode.status")" != "$json_status" ]]; then
    echo "FAIL: --$mode exited $(cat "$run_dir/$mode.status"), --json exited $json_status" >&2
    exit 1
  fi
done
overall="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' \
  "$run_dir/full.out")"
grep -qF "Pulse: $overall" "$run_dir/panel.out" || {
  echo "FAIL: the panel does not say $overall, which the document reports" >&2
  exit 1
}
grep -qF "# pulse	$overall" "$run_dir/plain.out" || {
  echo "FAIL: --plain does not say $overall, which the document reports" >&2
  exit 1
}
echo "  ok: $overall in all three modes, exit $json_status in all three"

echo "[7/9] --plain is flat, stable and free of the panel"
python3 - "$run_dir/plain.out" "$run_dir/full.out" <<'PY'
import json, sys

raw = open(sys.argv[1], "rb").read()
assert b"\x1b" not in raw, "--plain emitted ANSI"
for glyph in "✔✖⚠─│┌└╭╮":
    assert glyph not in raw.decode(), f"--plain emitted the panel character {glyph!r}"

rows = [l for l in raw.decode().splitlines() if l and not l.startswith("#")]
for row in rows:
    fields = row.split("\t")
    assert len(fields) == 5, f"row has {len(fields)} fields, expected 5: {row!r}"

doc = json.load(open(sys.argv[2]))
items = [i for section in doc["sections"].values() for i in section]
assert len(rows) == len(items), f"{len(rows)} plain rows, {len(items)} items"
seen = sorted((r.split("\t")[0], r.split("\t")[1], r.split("\t")[2]) for r in rows)
want = sorted((i["area"], i["status"], i["subject"]) for i in items)
assert seen == want, "plain rows and document items describe different runs"
print(f"  ok: {len(rows)} rows, five fields each, same items as the document")
PY

echo "[8/9] the exit codes are the ones the contract publishes"
# 0/1/2 driven end to end, from a doctor stub that reports what it reports.
# 3 is pulse failing at its own job and is covered by pulse-contract-smoke.sh.
make_doctor <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
pulse_run pass system --json >/dev/null
[[ "$(cat "$run_dir/pass.status")" == "0" ]] || {
  echo "FAIL: a healthy run exited $(cat "$run_dir/pass.status"), expected 0" >&2; exit 1; }

make_doctor <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"warn","detail":"old"}]}'
EOF
pulse_run warn system --json >/dev/null
[[ "$(cat "$run_dir/warn.status")" == "1" ]] || {
  echo "FAIL: a warning run exited $(cat "$run_dir/warn.status"), expected 1" >&2; exit 1; }

make_doctor <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"fail","detail":"missing"}]}'
EOF
pulse_run fail system --json >/dev/null
[[ "$(cat "$run_dir/fail.status")" == "2" ]] || {
  echo "FAIL: a failing run exited $(cat "$run_dir/fail.status"), expected 2" >&2; exit 1; }
for state in pass warn fail; do
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$run_dir/$state.out"
done
echo "  ok: 0, 1 and 2 driven end to end, each with a valid document"

echo "[9/9] two output modes on one command line are refused"
# Picking one for the caller is how a pipeline ends up parsing the other.
pulse_run both --json --plain >/dev/null || true
[[ "$(cat "$run_dir/both.status")" == "2" ]] || {
  echo "FAIL: --json --plain exited $(cat "$run_dir/both.status"), expected 2" >&2
  exit 1
}
[[ -s "$run_dir/both.out" ]] && {
  echo "FAIL: a refused invocation still wrote to stdout" >&2
  exit 1
}
grep -qF 'one output mode' "$run_dir/both.err" || {
  echo "FAIL: the refusal does not say why" >&2
  exit 1
}
echo "  ok: refused, exit 2, nothing on stdout"

echo "PASS: pulse machine surface (mq.pulse.v1)"
