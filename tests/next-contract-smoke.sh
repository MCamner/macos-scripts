#!/usr/bin/env bash
# Holds `mq.next.v1` — the selection contract for `mqlaunch next`.
#
# The selector reads `mq.pulse.v1` and returns one item from it. Everything this
# gate asserts is a way that could quietly stop being true:
#
#   1. the selected item is attention[0] verbatim — no re-ranking, ever, and in
#      particular no skipping past an UNAVAILABLE to reach a "more concrete" FAIL
#   2. an empty attention list from a run that measured something is NONE
#   3. an empty attention list from a run that measured nothing is not NONE
#   4. a missing, malformed or foreign document is not NONE either
#   5. scope and collected are echoed, so a scoped NONE cannot read as a full one
#   6. stdout is one JSON document; diagnostics go to stderr
#
# Cases 2, 3 and 4 are the same absence distinction docs/PULSE_CONTRACT.md keeps
# between SKIPPED, UNAVAILABLE and PASS, one level up. They all produce an empty
# attention list, and collapsing any two of them tells an operator that nothing
# needs doing on a machine nobody looked at.
#
# Fixtures are written by hand rather than produced by running Pulse. A gate that
# ran the real collectors would be measuring this machine, and the point here is
# the selector's behavior on documents this machine may never produce.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELECT_LIB="$ROOT/mqlaunch/lib/next/select.sh"

echo "SMOKE: next selection contract (mq.next.v1)"

if [[ ! -f "$SELECT_LIB" ]]; then
  echo "FAIL: missing selector library: $SELECT_LIB" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$SELECT_LIB"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Runs the selector on a fixture, capturing stdout, stderr and the exit code.
run_select() {
  set +e
  OUT="$(next_select "$1" 2>"$TMP/err")"
  RC=$?
  set -e
  ERR="$(cat "$TMP/err")"
}

# Reads one field out of the emitted document with a real JSON parser, so a test
# cannot pass on a document that only looks right to grep.
field() {
  printf '%s' "$OUT" | python3 -c \
    'import json,sys; d=json.load(sys.stdin); print(json.dumps(d[sys.argv[1]]))' "$1"
}

echo "[1/9] a WARN finding is selected verbatim, exit 1"
cat > "$TMP/warn.json" <<'JSON'
{
  "schema": "mq.pulse.v1",
  "status": "WARN",
  "scope": null,
  "collected": ["system", "repositories", "stack", "memory", "git", "quality"],
  "summary": { "pass": 11, "warn": 1, "fail": 0, "unavailable": 0, "skipped": 0 },
  "sections": {
    "repositories": [
      {
        "source": "repos",
        "area": "repositories",
        "status": "WARN",
        "subject": "macos-scripts",
        "summary": "feat/pulse · 3 modified, 1 untracked",
        "evidence": "git status --short",
        "next_command": "mqlaunch repos status",
        "priority": 0
      }
    ]
  },
  "attention": [
    {
      "source": "repos",
      "area": "repositories",
      "status": "WARN",
      "subject": "macos-scripts",
      "summary": "feat/pulse · 3 modified, 1 untracked",
      "evidence": "git status --short",
      "next_command": "mqlaunch repos status",
      "priority": 0
    }
  ]
}
JSON
run_select "$TMP/warn.json"
[[ "$RC" -eq 1 ]] || fail "WARN selection should exit 1, got $RC"
[[ "$(field status)" == '"SELECTED"' ]] || fail "expected SELECTED, got $(field status)"
[[ "$(field schema)" == '"mq.next.v1"' ]] || fail "wrong schema: $(field schema)"
# Verbatim: every key of attention[0] survives into item, unchanged.
printf '%s' "$OUT" > "$TMP/emitted.json"
python3 - "$TMP/emitted.json" "$TMP/warn.json" <<'PY' || fail "item is not attention[0] verbatim"
import json, sys


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


emitted, pulse = load(sys.argv[1]), load(sys.argv[2])
sys.exit(0 if emitted["item"] == pulse["attention"][0] else 1)
PY

echo "[2/9] a FAIL finding exits 2"
python3 - "$TMP/warn.json" > "$TMP/fail.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    doc = json.load(handle)
doc["status"] = "FAIL"
doc["attention"][0]["status"] = "FAIL"
print(json.dumps(doc))
PY
run_select "$TMP/fail.json"
[[ "$RC" -eq 2 ]] || fail "FAIL selection should exit 2, got $RC"
[[ "$(field status)" == '"SELECTED"' ]] || fail "expected SELECTED, got $(field status)"

echo "[3/9] an UNAVAILABLE at the head is returned, not skipped for a FAIL below"
cat > "$TMP/gap-first.json" <<'JSON'
{
  "schema": "mq.pulse.v1",
  "status": "FAIL",
  "scope": null,
  "collected": ["system", "git", "quality"],
  "sections": {},
  "attention": [
    {
      "source": "stack",
      "area": "stack",
      "status": "UNAVAILABLE",
      "subject": "mq-agent",
      "summary": "timed out after 8s",
      "next_command": "mqlaunch stack status",
      "priority": 0
    },
    {
      "source": "quality",
      "area": "quality",
      "status": "FAIL",
      "subject": "Runtime authority",
      "summary": "failing",
      "next_command": "mqlaunch selftest",
      "priority": 0
    }
  ]
}
JSON
run_select "$TMP/gap-first.json"
[[ "$(field status)" == '"SELECTED"' ]] || fail "expected SELECTED, got $(field status)"
subject="$(printf '%s' "$OUT" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["item"]["subject"])')"
[[ "$subject" == "mq-agent" ]] \
  || fail "selector re-ranked: picked '$subject' instead of the UNAVAILABLE head"
[[ "$RC" -eq 1 ]] \
  || fail "UNAVAILABLE selection should exit 1 (its own severity), got $RC"

echo "[4/9] empty attention on a run that measured something is NONE, exit 0"
cat > "$TMP/none.json" <<'JSON'
{
  "schema": "mq.pulse.v1",
  "status": "PASS",
  "scope": null,
  "collected": ["system", "repositories", "stack", "memory", "git", "quality"],
  "sections": {},
  "attention": []
}
JSON
run_select "$TMP/none.json"
[[ "$RC" -eq 0 ]] || fail "NONE should exit 0, got $RC"
[[ "$(field status)" == '"NONE"' ]] || fail "expected NONE, got $(field status)"
[[ "$(field item)" == "null" ]] || fail "NONE must carry a null item, got $(field item)"

echo "[5/9] empty attention on a run that measured nothing is NOT NONE"
cat > "$TMP/incomplete.json" <<'JSON'
{
  "schema": "mq.pulse.v1",
  "status": "INCOMPLETE",
  "scope": null,
  "collected": ["system", "repositories", "stack", "memory", "git", "quality"],
  "sections": {},
  "attention": []
}
JSON
run_select "$TMP/incomplete.json"
[[ "$(field status)" != '"NONE"' ]] \
  || fail "an INCOMPLETE run reported NONE — 'measured nothing' collapsed into 'nothing to do'"
[[ "$(field status)" == '"UNAVAILABLE"' ]] || fail "expected UNAVAILABLE, got $(field status)"
[[ "$RC" -eq 3 ]] || fail "INCOMPLETE should exit 3, got $RC"

echo "[6/9] a missing document is UNAVAILABLE, exit 3"
run_select "$TMP/does-not-exist.json"
[[ "$RC" -eq 3 ]] || fail "missing document should exit 3, got $RC"
[[ "$(field status)" == '"UNAVAILABLE"' ]] || fail "expected UNAVAILABLE, got $(field status)"
[[ -n "$ERR" ]] || fail "a missing document must say so on stderr"

echo "[7/9] a malformed document is UNAVAILABLE, not NONE"
printf '{ "schema": "mq.pulse.v1", "attention": [' > "$TMP/broken.json"
run_select "$TMP/broken.json"
[[ "$(field status)" == '"UNAVAILABLE"' ]] \
  || fail "malformed document gave $(field status), not UNAVAILABLE"
[[ "$RC" -eq 3 ]] || fail "malformed document should exit 3, got $RC"

echo "[8/9] a foreign schema is refused rather than guessed at"
printf '{ "schema": "mq.pulse.v2", "status": "PASS", "attention": [] }\n' > "$TMP/foreign.json"
run_select "$TMP/foreign.json"
[[ "$(field status)" == '"UNAVAILABLE"' ]] \
  || fail "foreign schema gave $(field status), not UNAVAILABLE"
[[ "$RC" -eq 3 ]] || fail "foreign schema should exit 3, got $RC"

echo "[9/9] scope and collected are echoed, and stdout is one JSON document"
python3 - "$TMP/none.json" > "$TMP/scoped.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    doc = json.load(handle)
doc["scope"] = "repos"
doc["collected"] = ["repositories"]
print(json.dumps(doc))
PY
run_select "$TMP/scoped.json"
[[ "$(field status)" == '"NONE"' ]] || fail "expected NONE, got $(field status)"
[[ "$(field scope)" == '"repos"' ]] \
  || fail "scope not echoed: $(field scope) — a scoped NONE would read as a full one"
[[ "$(field collected)" == '["repositories"]' ]] \
  || fail "collected not echoed: $(field collected)"
[[ -z "$ERR" ]] || fail "a clean NONE must not write to stderr, got: $ERR"
printf '%s' "$OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' \
  || fail "stdout is not exactly one JSON document"

echo "OK: next selection contract smoke test passed"
