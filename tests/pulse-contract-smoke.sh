#!/usr/bin/env bash
# Holds the v2.1.0 P0 Pulse contract: the five check states, the aggregation
# rule, the four exit codes, and the command word.
#
# The rules are asserted against mqlaunch/lib/pulse/model.sh by calling it, not
# by grepping docs/PULSE_CONTRACT.md. A roadmap or a contract document can claim
# anything; what a caller gets is what the functions return. The document is
# checked only for the parts a reader would act on and a test could otherwise
# let drift — the state names and the exit-code table.
#
# The truth table below is the whole contract in one place, and every row is
# there because it distinguishes two rules that would otherwise look the same:
# UNAVAILABLE from PASS, UNAVAILABLE from FAIL, SKIPPED from UNAVAILABLE, and an
# empty run from a passing one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="$ROOT/mqlaunch/lib/pulse/model.sh"
CONTRACT="$ROOT/docs/PULSE_CONTRACT.md"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"
DISPATCH="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"

echo "SMOKE: pulse contract"

echo "[1/9] the model and the contract document exist"
test -f "$MODEL"
test -f "$CONTRACT"

# shellcheck source=/dev/null
source "$MODEL"

echo "[2/9] exactly the five check states are valid"
for state in PASS WARN FAIL UNAVAILABLE SKIPPED; do
  if ! pulse_state_is_valid "$state"; then
    echo "FAIL: $state is not a valid check state" >&2
    exit 1
  fi
done
for bogus in "" ok OKAY pass INCOMPLETE UNKNOWN; do
  if pulse_state_is_valid "$bogus"; then
    echo "FAIL: '$bogus' was accepted as a check state" >&2
    exit 1
  fi
done
echo "  ok: PASS WARN FAIL UNAVAILABLE SKIPPED, and nothing else"

echo "[3/9] INCOMPLETE is an overall state, never a check state"
# It has to be reachable as an overall state and rejected as a check state, or
# a collector could report "the run failed to run" about one of its own checks.
if pulse_state_is_valid INCOMPLETE; then
  echo "FAIL: INCOMPLETE was accepted as a check state" >&2
  exit 1
fi
got="$(pulse_overall_state)"
if [[ "$got" != "INCOMPLETE" ]]; then
  echo "FAIL: a run with no checks reported $got, expected INCOMPLETE" >&2
  exit 1
fi
echo "  ok: rejected as a check state, reached as an overall state"

echo "[4/9] aggregation truth table"
# Each row: expected overall | expected exit | the check states of one run.
assert_run() {
  local want_state="$1" want_exit="$2"
  shift 2
  local got_state got_exit
  got_state="$(pulse_overall_state "$@")"
  got_exit="$(pulse_run_exit_code "$@")"
  if [[ "$got_state" != "$want_state" || "$got_exit" != "$want_exit" ]]; then
    echo "FAIL: run [$*] gave $got_state/$got_exit, expected $want_state/$want_exit" >&2
    exit 1
  fi
}

assert_run PASS       0 PASS
assert_run PASS       0 PASS PASS PASS
assert_run WARN       1 PASS WARN
assert_run FAIL       2 PASS FAIL
assert_run FAIL       2 WARN FAIL
# The order of the checks must not change the verdict.
assert_run FAIL       2 FAIL WARN
assert_run FAIL       2 FAIL PASS UNAVAILABLE SKIPPED
# UNAVAILABLE is a warning, not a pass: this is the rule the roadmap names.
assert_run WARN       1 PASS UNAVAILABLE
assert_run WARN       1 UNAVAILABLE
# ...and not a failure either.
assert_run WARN       1 UNAVAILABLE UNAVAILABLE
# SKIPPED contributes nothing, so it cannot raise or lower a verdict.
assert_run PASS       0 PASS SKIPPED
assert_run WARN       1 WARN SKIPPED
assert_run FAIL       2 FAIL SKIPPED
# ...but it cannot stand in for a measurement either.
assert_run INCOMPLETE 3 SKIPPED
assert_run INCOMPLETE 3 SKIPPED SKIPPED
echo "  ok: 15 runs, including UNAVAILABLE vs PASS, vs FAIL, and SKIPPED vs empty"

echo "[5/9] an unknown check state is refused rather than absorbed"
# Absorbing it would let a typo in a collector read as healthy.
if pulse_overall_state PASS BROKEN 2>/dev/null; then
  echo "FAIL: an unknown state was accepted by pulse_overall_state" >&2
  exit 1
fi
got_exit="$(pulse_run_exit_code PASS BROKEN 2>/dev/null || printf '%s' "$?")"
if [[ "$got_exit" != "3" ]]; then
  echo "FAIL: a run with an unknown state gave exit $got_exit, expected 3" >&2
  exit 1
fi
echo "  ok: refused, and the run reports 3 rather than a verdict"

echo "[6/9] states arrive on stdin as well as in arguments, and never from a keyboard"
# The collectors in later PRs stream their results; the same rule has to apply.
got="$(printf '%s\n' PASS UNAVAILABLE PASS | pulse_overall_state)"
if [[ "$got" != "WARN" ]]; then
  echo "FAIL: stdin form gave $got, expected WARN" >&2
  exit 1
fi
# The half that was a real defect: with no arguments and a terminal on stdin,
# the first version blocked on a read and the command never returned. Driven
# under a pty, because the condition cannot be reproduced on a redirected stdin
# — which is exactly why it survived the first run of this suite.
python3 - "$ROOT" <<'PY'
import os, pty, subprocess, sys

root = sys.argv[1]
script = f'source "{root}/mqlaunch/lib/pulse/model.sh"; pulse_overall_state; echo'
master, slave = pty.openpty()
proc = subprocess.Popen(["bash", "-c", script], stdin=slave, stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL)
os.close(slave)
try:
    out, _ = proc.communicate(timeout=10)
except subprocess.TimeoutExpired:
    proc.kill()
    raise SystemExit("FAIL: pulse_overall_state blocked on a terminal stdin")
finally:
    os.close(master)
got = out.decode().strip()
if got != "INCOMPLETE":
    raise SystemExit(f"FAIL: on a terminal with no arguments, got {got!r}, expected INCOMPLETE")
print("  ok: same verdict either way, and it returns on a TTY")
PY

echo "[7/9] the contract document states the same exit codes"
# The document is what an operator reads before trusting the exit code in a
# script, so a drift between it and the model is worth failing on.
for row in \
  '| `PASS` | every contributing check passed | `0` |' \
  '| `FAIL` | at least one `FAIL` | `2` |' \
  '| `INCOMPLETE` | nothing contributed — no checks, or every check `SKIPPED` | `3` |'
do
  if ! grep -qF -- "$row" "$CONTRACT"; then
    echo "FAIL: docs/PULSE_CONTRACT.md no longer states: $row" >&2
    exit 1
  fi
done
grep -qF 'at least one `WARN` or `UNAVAILABLE`, no `FAIL` | `1` |' "$CONTRACT"
echo "  ok: the four exit codes are documented as implemented"

echo "[8/9] the word 'pulse' does not resolve to the network diagnostic"
# The rename is the reason v2.1.0 can address `mqlaunch pulse` at all. This step
# survives the cockpit landing: what it forbids is the word pointing back at
# netpulse.sh, not the word existing.
if grep -nE '^\s*pulse\)' "$DISPATCH" | grep -q .; then
  arm="$(grep -nA3 -E '^\s*pulse\)' "$DISPATCH")"
  if printf '%s' "$arm" | grep -q 'netpulse.sh'; then
    echo "FAIL: the 'pulse' dispatch arm runs the network diagnostic again" >&2
    printf '%s\n' "$arm" >&2
    exit 1
  fi
fi
python3 - "$REGISTRY" <<'PY'
import json, sys

registry = json.load(open(sys.argv[1]))
by_name = {c["name"]: c for c in registry["commands"]}

netpulse = by_name.get("netpulse")
if netpulse is None:
    raise SystemExit("FAIL: netpulse is not in the command registry")
if netpulse["namespace"] != "ops" or netpulse["owner"] != "macos-scripts":
    raise SystemExit(f"FAIL: netpulse moved namespace or owner: {netpulse}")

pulse = by_name.get("pulse")
if pulse is not None and pulse.get("summary", "").lower().startswith("network latency"):
    raise SystemExit("FAIL: 'pulse' is the network diagnostic again")

for command in registry["commands"]:
    words = [command["name"], *command.get("aliases", [])]
    words += [a["name"] for a in command.get("deprecated_aliases", [])]
    if "pulse" in words and command["name"] != "pulse":
        raise SystemExit(
            f"FAIL: 'pulse' is an alias of {command['name']} — the word is "
            "reserved for the cockpit"
        )
print("  ok: netpulse owns the diagnostic, 'pulse' is free for the cockpit")
PY

echo "[9/9] every suggested command is one that already exists"
# docs/PULSE_CONTRACT.md: `next_command` must be a command that already exists.
# Nothing checked it until now, which made it the one contract rule held by
# nobody — and a suggestion that does not resolve is worse than none, because an
# operator types it before doubting it.
#
# Only `mqlaunch ...` literals are checked. A collector may also carry a hint its
# delegate published — doctor's "brew install jq" — and that is the owner's
# command, not one this repo invented.
python3 - "$ROOT" <<'PY_INNER'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
registry = json.loads((root / "mqlaunch/lib/command-registry.json").read_text())

words = {}
for command in registry["commands"]:
    for name in [command["name"], *command.get("aliases", [])]:
        words[name] = command

literals = set()
for source in sorted((root / "mqlaunch/lib/pulse").glob("*.sh")):
    literals |= set(re.findall(r'next_command="(mqlaunch [^"$]*)"', source.read_text()))

if not literals:
    sys.exit("FAIL: no suggestions found at all — this check stopped checking")

problems = []
for literal in sorted(literals):
    parts = literal.split()[1:]
    command = words.get(parts[0])
    if command is None:
        problems.append(f"{literal!r}: no registry command named {parts[0]!r}")
        continue
    if len(parts) < 2:
        continue
    subcommands = command.get("subcommands") or []
    known = {s["name"] for s in subcommands}
    known |= {a for s in subcommands for a in s.get("aliases", [])}
    if parts[1] in known:
        continue
    # A command that delegates, or that forwards words it does not declare,
    # owns a surface this registry does not enumerate — `mqlaunch stack cockpit`
    # is mq-agent's subcommand, reached through a declared delegation.
    if command.get("delegates_to") or command.get("unknown_subcommand") == "forward":
        continue
    problems.append(
        f"{literal!r}: {parts[0]!r} declares no {parts[1]!r} and forwards nothing"
    )

if problems:
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)
    sys.exit("FAIL: Pulse suggests commands that do not exist")

print(f"  ok: {len(literals)} suggested commands, every one of them reachable")
PY_INNER

echo "PASS: pulse contract"
