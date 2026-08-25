#!/usr/bin/env bash
# The test suite must not wait on whoever invoked it.
#
# tools/scripts/test-all.sh inherits the caller's stdin and hands it to every
# test unchanged. A test that reads stdin then waits on the caller, and the three
# cases behave differently:
#
#   a terminal        the surfaces that read stdin check for one and return
#   already at EOF    the read returns immediately
#   an open pipe      the read blocks until the writer closes, or forever
#
# The third is how an agent, a CI step, or a terminal running something else
# alongside invokes this suite, and it is the one that was observed: a full run
# stopped inside pulse-contract-smoke.sh at `pulse_overall_state` with no
# arguments, which reads its states from stdin when given none.
#
# It did not reproduce on the next run, because whatever held the pipe open had
# gone away. That is the worst shape a defect can have in a test suite — the
# command passes the second time, and the run that hung gets written off as a
# fluke. So the fix is a guarantee rather than a fix to one call site, and this
# file holds the guarantee.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT/tools/scripts/test-all.sh"

echo "SMOKE: the suite does not wait on the caller's stdin"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

echo "[1/3] the runner detaches stdin before it runs anything"
# Asserted against the script rather than by running it, for the reason
# tests/release-secret-scan-smoke.sh gives about its own step 1: the wrong
# version passes every behavioural test there is, as long as the machine running
# it happens to have stdin at EOF.
test -f "$RUNNER" || fail "the runner is missing: $RUNNER"

# Comments stripped first. This file and the runner both explain the redirection
# in prose, and prose about doing something reads exactly like doing it to a
# grep — the trap tests/pulse-menu-smoke.sh already records.
code="$(sed 's/#.*//' "$RUNNER")"
grep -q 'exec[[:space:]]*<[[:space:]]*/dev/null' <<<"$code" \
  || fail "the runner does not detach stdin"

# Before the first test, or it is not a guarantee — a redirection after the
# first invocation protects everything except the thing that already ran.
guard_line="$(grep -n 'exec[[:space:]]*<[[:space:]]*/dev/null' <<<"$code" | head -1 | cut -d: -f1)"
first_test="$(grep -n 'tests/\|test-mqlaunch' <<<"$code" | head -1 | cut -d: -f1)"
[[ -n "$guard_line" && -n "$first_test" ]] || fail "could not locate the guard or the first test"
[[ "$guard_line" -lt "$first_test" ]] \
  || fail "stdin is detached at line $guard_line, after the first test at line $first_test"
echo "  ok: line $guard_line, before the first test at line $first_test"

echo "[2/3] a reader inside the suite returns when stdin is an open pipe"
# The behavioural half, on a miniature of the real thing: a runner shaped like
# test-all.sh, a test that reads stdin the way pulse_overall_state does, and an
# open pipe with no writer — which is the case that hung.
cat > "$TMP/reader.sh" <<'EOF'
#!/usr/bin/env bash
# Stands in for any test that reads its states from stdin.
while IFS= read -r line; do :; done
echo "reader finished"
EOF
chmod +x "$TMP/reader.sh"

cat > "$TMP/runner.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec </dev/null
"$TMP/reader.sh"
EOF
chmod +x "$TMP/runner.sh"

fifo="$TMP/held"
mkfifo "$fifo"
# A writer that holds the pipe open and never writes. Without the redirection in
# the runner, the reader waits on this for the full 30s.
sleep 30 > "$fifo" &
writer=$!
# shellcheck disable=SC2064
trap "kill $writer 2>/dev/null || true; rm -rf '$TMP'" EXIT

"$TMP/runner.sh" < "$fifo" > "$TMP/mini.out" 2>&1 &
runner_pid=$!

waited=0
while kill -0 "$runner_pid" 2>/dev/null && [[ "$waited" -lt 5 ]]; do
  sleep 1
  waited=$((waited + 1))
done

if kill -0 "$runner_pid" 2>/dev/null; then
  kill -9 "$runner_pid" 2>/dev/null || true
  fail "the runner was still waiting on the held pipe after ${waited}s"
fi
wait "$runner_pid" 2>/dev/null || fail "the miniature runner exited non-zero"
grep -q "reader finished" "$TMP/mini.out" || fail "the reader did not run"
echo "  ok: finished in under ${waited}s with the pipe still held open"

echo "[3/3] the same runner without the guard does hang, so step 2 means something"
# A passing step 2 is worth nothing unless the shape it exercises can fail. This
# is the same miniature with the one line removed.
cat > "$TMP/unguarded.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
"$TMP/reader.sh"
EOF
chmod +x "$TMP/unguarded.sh"

"$TMP/unguarded.sh" < "$fifo" > "$TMP/unguarded.out" 2>&1 &
unguarded_pid=$!

waited=0
while kill -0 "$unguarded_pid" 2>/dev/null && [[ "$waited" -lt 3 ]]; do
  sleep 1
  waited=$((waited + 1))
done

still_running=0
kill -0 "$unguarded_pid" 2>/dev/null && still_running=1
kill -9 "$unguarded_pid" 2>/dev/null || true

[[ "$still_running" -eq 1 ]] \
  || fail "the unguarded runner returned anyway — this machine cannot show the hang, so step 2 proves nothing here"
echo "  ok: without the line it was still blocked after ${waited}s"

echo "OK: suite stdin detachment smoke test passed"
