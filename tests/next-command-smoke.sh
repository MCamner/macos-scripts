#!/usr/bin/env bash
# Holds the `mqlaunch next` command surface — the CLI layer over the selector.
#
# The selection semantics are gated by tests/next-contract-smoke.sh. This gate is
# about the layer above them, where a command can be correct about the answer and
# still wrong about how it got it:
#
#   1. with no arguments it collects Pulse state itself, so it is typable
#   2. Pulse's exit code is not control flow — a run that exits 1 or 2 still
#      produced a document, and that document is the input
#   3. --input selects from a document the caller already has, and does not
#      collect
#   4. the selector's exit code reaches the caller, unchanged, in both modes
#   5. --json is one JSON document on stdout and nothing else
#   6. a usage error is 2, not 3 — a typo is not an observation gap
#
# Case 2 is the one worth the whole file. `pulse --json > doc || exit $?` reads
# as ordinary care and would make `mqlaunch next` answer UNAVAILABLE in exactly
# the situation it exists for: a machine with something wrong on it.
#
# Everything runs against a stub tree with a fake pulse.sh. A gate that ran the
# real collectors would be measuring this machine, and the documents below are
# ones this machine may never produce.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: next command surface"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

stub="$TMP/stub"
mkdir -p "$stub/tools/scripts" "$stub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/next" "$stub/mqlaunch/lib/next"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/next.sh" "$stub/tools/scripts/next.sh"
chmod +x "$stub/tools/scripts/next.sh"

NEXT="$stub/tools/scripts/next.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Writes the stub pulse.sh: it prints the document on stdin and exits with CODE.
make_pulse() { # CODE
  local code="$1"
  local body
  body="$(cat)"
  {
    echo '#!/usr/bin/env bash'
    echo "printf '%s\\n' \"\$(cat <<'DOC'"
    printf '%s\n' "$body"
    echo "DOC"
    echo ')"'
    echo "exit $code"
  } > "$stub/tools/scripts/pulse.sh"
  chmod +x "$stub/tools/scripts/pulse.sh"
}

run_next() {
  set +e
  OUT="$(MACOS_SCRIPTS_HOME="$stub" NO_COLOR=1 "$NEXT" "$@" 2>"$TMP/err")"
  RC=$?
  set -e
  ERR="$(cat "$TMP/err")"
}

WARN_DOC='{
  "schema": "mq.pulse.v1",
  "status": "WARN",
  "scope": null,
  "collected": ["system", "git"],
  "sections": {},
  "attention": [
    {
      "source": "git",
      "area": "git",
      "status": "WARN",
      "subject": "Worktree",
      "summary": "3 modified",
      "next_command": "mqlaunch git",
      "priority": 0
    }
  ]
}'

FAIL_DOC='{
  "schema": "mq.pulse.v1",
  "status": "FAIL",
  "scope": null,
  "collected": ["quality"],
  "sections": {},
  "attention": [
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
}'

echo "[1/8] with no arguments it collects Pulse state itself"
printf '%s' "$WARN_DOC" | make_pulse 0
run_next
[[ "$OUT" == *"Worktree"* ]] || fail "did not select from the collected document: $OUT"
[[ "$OUT" == *"mqlaunch git"* ]] || fail "did not repeat the item's next_command"

echo "[2/8] a Pulse run that exits 1 still reaches the selector"
printf '%s' "$WARN_DOC" | make_pulse 1
run_next
[[ "$RC" -eq 1 ]] || fail "expected exit 1 from the WARN selection, got $RC"
[[ "$OUT" == *"Worktree"* ]] \
  || fail "pulse exit 1 was treated as control flow — the document was discarded"
[[ "$OUT" != *"unavailable"* ]] \
  || fail "a pulse run with findings reported UNAVAILABLE: $OUT"

echo "[3/8] a Pulse run that exits 2 still reaches the selector"
printf '%s' "$FAIL_DOC" | make_pulse 2
run_next
[[ "$RC" -eq 2 ]] || fail "expected exit 2 from the FAIL selection, got $RC"
[[ "$OUT" == *"Runtime authority"* ]] \
  || fail "pulse exit 2 was treated as control flow — the document was discarded"

echo "[4/8] a Pulse that produces nothing is UNAVAILABLE, not a quiet NONE"
cat > "$stub/tools/scripts/pulse.sh" <<'STUB'
#!/usr/bin/env bash
echo "pulse: collectors unavailable" >&2
exit 3
STUB
chmod +x "$stub/tools/scripts/pulse.sh"
run_next
[[ "$RC" -eq 3 ]] || fail "an empty pulse should exit 3, got $RC"
[[ "$OUT" != *"Nothing needs attention"* ]] \
  || fail "an empty pulse printed the all-clear — 'could not measure' collapsed into 'nothing to do'"
[[ "$OUT" == *"unavailable"* ]] || fail "expected an unavailable screen, got: $OUT"
[[ -n "$ERR" ]] || fail "an empty pulse must leave a diagnostic on stderr"

echo "[5/8] --input selects from an existing document and does not collect"
# The stub records that it ran, rather than announcing it on stderr. A wasted
# collection whose output went nowhere leaves no diagnostic to assert on, and
# "it was silent" is not evidence that it did not happen.
cat > "$stub/tools/scripts/pulse.sh" <<STUB
#!/usr/bin/env bash
touch "$TMP/pulse-ran"
exit 0
STUB
chmod +x "$stub/tools/scripts/pulse.sh"
rm -f "$TMP/pulse-ran"
printf '%s' "$FAIL_DOC" > "$TMP/given.json"
run_next --input "$TMP/given.json"
[[ "$RC" -eq 2 ]] || fail "expected exit 2 from the given document, got $RC"
[[ "$OUT" == *"Runtime authority"* ]] || fail "did not select from --input: $OUT"
[[ ! -e "$TMP/pulse-ran" ]] \
  || fail "--input still ran Pulse — the caller pays for the collection twice"

echo "[6/8] --json is one JSON document on stdout, with the same exit code"
run_next --input "$TMP/given.json" --json
[[ "$RC" -eq 2 ]] || fail "--json changed the exit code: $RC"
printf '%s' "$OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' \
  || fail "--json stdout is not exactly one JSON document"
schema="$(printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["schema"])')"
[[ "$schema" == "mq.next.v1" ]] || fail "wrong schema in --json: $schema"

echo "[7/8] a clean run reports NONE at exit 0 and says what it collected"
cat > "$TMP/clean.json" <<'JSON'
{
  "schema": "mq.pulse.v1",
  "status": "PASS",
  "scope": "repos",
  "collected": ["repositories"],
  "sections": {},
  "attention": []
}
JSON
run_next --input "$TMP/clean.json"
[[ "$RC" -eq 0 ]] || fail "NONE should exit 0, got $RC"
[[ "$OUT" == *"Nothing needs attention"* ]] || fail "expected the all-clear, got: $OUT"
[[ "$OUT" == *"Scope: repos"* ]] \
  || fail "a scoped all-clear must name its scope, or it reads as a full one: $OUT"

echo "[8/8] a usage error is 2, and --input without a file is refused"
run_next --nonsense
[[ "$RC" -eq 2 ]] || fail "an unknown option should exit 2, got $RC"
[[ "$ERR" == *"unknown option"* ]] || fail "no diagnostic for the unknown option"
run_next --input
[[ "$RC" -eq 2 ]] || fail "--input without a file should exit 2, got $RC"

echo "OK: next command surface smoke test passed"
