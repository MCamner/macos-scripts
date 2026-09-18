#!/usr/bin/env bash
# Holds the rule the gate audit produced:
#
#     PASS requires evidence that the subject was examined.
#
# Two real defects motivated it, both found by running the tools rather than
# reading them. The release gate's secrets scan reported `0 commits scanned`
# and printed a tick (#214). `tools/scripts/lint.sh` answered 0 when its file
# enumeration produced nothing, so `test-all.sh` printed "All selftest checks
# passed" having linted no file at all.
#
# Neither was a wrong answer. Both were no answer, reported as a pass. It is the
# invariant docs/PULSE_CONTRACT.md already carries for collectors, applied to
# the gates instead:
#
#     could-not-measure  !=  measured-clean
#
# The three questions this file asks of a gate:
#
#   1. can it exit 0 when the tool never ran?
#   2. can it exit 0 when the input set came out empty by mistake?
#   3. can a failed measuring step followed by empty output read as PASS?
#
# Gates cleared by the same audit and deliberately not re-tested here, because
# they already answer correctly and their own smoke files cover them:
# scripts/check-skills.sh (exit 2 on an empty skills tree),
# scripts/check-runtime-authority.sh (exit 1 in an empty tree), and
# tools/scripts/test-all.sh, which names every test by path so a missing file is
# a hard failure rather than a shorter run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$ROOT/tools/scripts/lint.sh"

echo "SMOKE: gate evidence"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Marks a failing check.
fail() {
  echo "FAIL: $1" >&2
  exit 1
}

echo "[1/4] the linter refuses to pass when its enumeration finds nothing"
empty="$TMP/empty"
mkdir -p "$empty"
set +e
MACOS_SCRIPTS_HOME="$empty" bash "$LINT" >"$TMP/out" 2>"$TMP/err"
rc=$?
set -e
[[ "$rc" -ne 0 ]] \
  || fail "linting an empty tree exited 0 — nothing was measured and it passed"
[[ "$rc" -eq 3 ]] \
  || fail "expected 3 (could not measure), got $rc"
grep -q 'UNAVAILABLE' "$TMP/err" \
  || fail "the diagnostic does not say the run was unavailable: $(cat "$TMP/err")"
echo "  ok: exit 3, and it says so on stderr"

echo "[2/4] the linter refuses to pass when shellcheck is absent"
# A PATH holding everything the script needs except shellcheck. The gate must
# not treat "the tool is missing" as "the code is clean".
stub="$TMP/bin"
mkdir -p "$stub"
for tool in bash find sort head grep; do
  target="$(command -v "$tool" 2>/dev/null)" || continue
  ln -sf "$target" "$stub/$tool"
done
set +e
PATH="$stub" MACOS_SCRIPTS_HOME="$ROOT" bash "$LINT" >"$TMP/out2" 2>"$TMP/err2"
rc=$?
set -e
[[ "$rc" -ne 0 ]] \
  || fail "a missing shellcheck exited 0 — the suite would report PASS unlinted"
[[ "$rc" -eq 3 ]] || fail "expected 3 for a missing tool, got $rc"
echo "  ok: exit 3 rather than a silent skip"

echo "[3/4] the linter still passes, and reports how much it read"
set +e
MACOS_SCRIPTS_HOME="$ROOT" bash "$LINT" >"$TMP/out3" 2>&1
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "the real tree failed to lint: $(tail -3 "$TMP/out3")"
count="$(sed -n 's/.*(\([0-9][0-9]*\) files).*/\1/p' "$TMP/out3" | tail -1)"
[[ -n "$count" ]] || fail "the pass does not report a file count: $(tail -2 "$TMP/out3")"
# The heart of it. A pass that read zero files is the defect, not the fix.
[[ "$count" -gt 0 ]] || fail "the linter passed after reading $count files"
echo "  ok: passed over $count file(s), and the count is in the output"

echo "[4/4] the syntax sweep counts before it reports"
SWEEP="$ROOT/scripts/check-shell-syntax.sh"
[[ -x "$SWEEP" ]] || fail "the shared syntax sweep is missing at $SWEEP"

# It printed "All .sh files pass syntax check" unconditionally after a loop that
# ran zero times when find produced nothing. This used to be asserted by
# grepping quality.yml, because an inline workflow block cannot be executed
# here. The sweep is now a script, so the empty case can be run for real.
#
# The copy is named without a .sh suffix on purpose: the sweep resolves its
# tree from its own location, so a copy called *.sh would find itself and the
# enumeration would not be empty.
mkdir -p "$TMP/emptytree/bin"
cp "$SWEEP" "$TMP/emptytree/bin/sweep"
chmod +x "$TMP/emptytree/bin/sweep"
set +e
"$TMP/emptytree/bin/sweep" >"$TMP/out4" 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] \
  || fail "the syntax sweep passed on an empty enumeration (exit $rc)"
grep -q 'found no .sh files to check' "$TMP/out4" \
  || fail "the syntax sweep failed on an empty tree without saying why: $(cat "$TMP/out4")"
grep -q 'All \${#files\[@\]} .sh files' "$SWEEP" \
  || fail "the syntax sweep no longer reports how many files it checked"
echo "  ok: empty enumeration fails for real, and the success line carries the count"

echo "OK: gate evidence smoke test passed"
