#!/usr/bin/env bash
set -euo pipefail

# The registry must tell the truth about which commands emit JSON.
#
# #71 gave the registry a `json` flag and #78 showed what it is worth without a
# behavioural check: `release-check` declared `"json": false` while offering
# JSON, and the validator could not see it. The static validator only checks the
# flag against `output_modes` — two fields that are wrong together as easily as
# they are right together. Nothing ran the command.
#
# This gate runs it. It exercises a named subset of the surface and holds the
# declaration to what actually comes out, in both directions:
#
#   declared json:true   → --json must exit 0 and print one clean JSON document
#   declared otherwise   → --json must not print JSON
#
# The reverse direction is the one that caught `system doctor`: a subcommand
# emitting real JSON that the registry never advertised. A consumer generating
# help or docs from the registry would have hidden it.
#
# The subset is explicit and every entry is measured cheap and side-effect free.
# It is not the whole surface, and pretending otherwise would be the same class
# of lie this gate exists to catch. What keeps it honest is step 2: anything
# declaring json:true must be exercised here or point at a test that does, so a
# claim cannot be smuggled in by leaving the command off the list.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: output-mode parity"

test -f "$REGISTRY"
test -x "$LAUNCH" || test -f "$LAUNCH"

# Commands this gate executes, one invocation per line, as the words a user
# would type. `--json` is appended by the runner.
#
# Deliberately absent, each for a reason that is not "it would have failed":
#   selftest, self-check, system self-check
#                    run the launcher self-check; `selftest` runs this very
#                    suite, so exercising it here recurses.
#   help about       ~13s for the dashboard renderer, which `about` already
#                    covers through the same producer.
#   ask, atlas, brain, chat, ui
#                    reach a model or a terminal.
#   docfunc          hangs under --json and exits 124 (tracked separately).
#   repos *, srm *, workspace save/restore, and everything local-write,
#   destructive, or interactive
#                    a delegate's argument surface, or a side effect this suite
#                    must not cause.
EXERCISED=(
  "doctor"
  "about"
  "version"
  "notes"
  "index"
  "net"
  "check"
  "system doctor"
  "system time"
  "system net"
  "system check"
  "help index"
  "help version"
  "help notes"
  "release notes"
  "release version"
  "release status"
  "workspace list"
)

# A json:true claim this gate cannot execute, and the test that covers it
# instead. `mqlaunch release-check --json` runs release-check.sh, which runs the
# whole smoke suite — including this file. Running it here would not be slow, it
# would not terminate.
#
#
# `mqlaunch pulse --json` is exempt for two reasons, neither of them "it would
# fail": a full run shells into mq-agent and asks GitHub about this branch, and
# its QUALITY collector runs the repo's own gates — including this file. The
# scoped form that would avoid all that (`pulse system --json`) cannot be listed
# here either, because Pulse's scopes are forwarded words rather than declared
# subcommands, and step 1 would reject the invocation. The named test drives the
# document against stub delegates instead.
#
# An exemption is the obvious place to park an unproven claim, so it is checked:
# the named file must exist and must exercise the command. Verified separately
# that the real producer emits repo_release_check.v1 on stdout.
#
# `mqlaunch next --json` inherits Pulse's exemption for the same reason rather
# than a new one: with no arguments it collects fresh Pulse state itself, so
# running it here would run the full cockpit and, through the QUALITY collector,
# this file. `--input FILE` would avoid that, but a fixture path listed here
# would make this gate the owner of a document shape it does not define. The
# named test drives `--json` against a stub pulse.sh instead.
COVERED_ELSEWHERE=(
  "release-check	tests/release-check-contract-smoke.sh"
  "route	tests/mq-route-entrypoint-smoke.sh"
  "pulse	tests/pulse-machine-surface-smoke.sh"
  "next	tests/next-command-smoke.sh"
)

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/4] every exercised invocation resolves to a registry declaration"
printf '%s\n' "${EXERCISED[@]}" > "$run_dir/exercised.txt"
python3 - "$REGISTRY" "$run_dir/exercised.txt" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1]))
words = {}
for cmd in doc["commands"]:
    for name in [cmd["name"], *cmd.get("aliases", [])]:
        words[name] = cmd

problems = []
for line in [l for l in open(sys.argv[2]).read().splitlines() if l.strip()]:
    parts = line.split()
    cmd = words.get(parts[0])
    if cmd is None:
        problems.append(f"{line!r}: no registry command named {parts[0]!r}")
        continue
    if len(parts) == 1:
        continue
    subs = cmd.get("subcommands") or []
    match = next(
        (s for s in subs if parts[1] in [s["name"], *s.get("aliases", [])]), None
    )
    if match is None:
        problems.append(f"{line!r}: {parts[0]!r} declares no subcommand {parts[1]!r}")

if problems:
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit("exercised invocations do not match the registry")
print(f"  ok: {len(open(sys.argv[2]).read().splitlines())} invocations declared")
PY

echo "[2/4] every command declaring json:true is exercised, here or by a named test"
# Without this, a false claim survives by staying off the list above.
printf '%s\n' "${COVERED_ELSEWHERE[@]}" > "$run_dir/exempt.txt"
python3 - "$REGISTRY" "$run_dir/exercised.txt" "$run_dir/exempt.txt" "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

doc = json.load(open(sys.argv[1]))
exercised = {l.strip() for l in open(sys.argv[2]).read().splitlines() if l.strip()}
root = Path(sys.argv[4])

exempt = {}
for line in open(sys.argv[3]).read().splitlines():
    if line.strip():
        command, test = line.split("\t")
        exempt[command.strip()] = test.strip()

claims = []
for cmd in doc["commands"]:
    if cmd.get("json"):
        claims.append(cmd["name"])
    for sub in cmd.get("subcommands") or []:
        if sub.get("json"):
            claims.append(f"{cmd['name']} {sub['name']}")

problems = []
for claim in sorted(set(claims) - exercised):
    test = exempt.get(claim)
    if test is None:
        problems.append(f"{claim!r} declares json:true but this gate never runs it")
        continue
    # An exemption that names a test which does not exist, or does not touch the
    # command, is an exemption in name only.
    path = root / test
    if not path.is_file():
        problems.append(f"{claim!r} is exempted to {test!r}, which does not exist")
    elif claim not in path.read_text():
        problems.append(f"{claim!r} is exempted to {test!r}, which never mentions it")

# An exemption for something this gate does run is stale and hides nothing;
# it should go, so that the list stays short enough to read.
for stale in sorted(set(exempt) - (set(claims) - exercised)):
    problems.append(f"{stale!r} is exempted but does not need to be")

if problems:
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit("json:true claims are not all covered")
print(
    f"  ok: {len(set(claims))} json:true claims — "
    f"{len(set(claims) & exercised)} exercised, {len(exempt)} covered elsewhere"
)
PY

echo "[3/4] declared output modes match what the commands actually print"
: > "$run_dir/observed.txt"
for invocation in "${EXERCISED[@]}"; do
  set +e
  # shellcheck disable=SC2086  # the invocation is a deliberate word list
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 NO_COLOR=1 \
    timeout 60 bash "$LAUNCH" $invocation --json \
    >"$run_dir/out.bin" 2>/dev/null </dev/null
  status=$?
  set -e
  printf '%s\t%s\t%s\n' "$invocation" "$status" \
    "$(python3 -c '
import sys
raw = open(sys.argv[1], "rb").read()
print(raw.hex())
' "$run_dir/out.bin")" >> "$run_dir/observed.txt"
done

# The comparison is a separate file so that step 4 can replay the same observed
# output against a deliberately wrong registry. Re-running the commands to prove
# the gate fires would double the cost of the suite for no extra proof: what is
# under test there is the comparison, and the observations are already in hand.
cat > "$run_dir/compare.py" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1]))
words = {}
for cmd in doc["commands"]:
    for name in [cmd["name"], *cmd.get("aliases", [])]:
        words[name] = cmd


def declaration(invocation):
    """The entry that owns this invocation's output modes.

    A subcommand's own declaration wins when it has one. Output mode does not
    inherit: `system` is human-only and `system doctor` is not, which is the
    whole reason the field exists per subcommand.
    """
    parts = invocation.split()
    cmd = words[parts[0]]
    if len(parts) > 1:
        for sub in cmd.get("subcommands") or []:
            if parts[1] in [sub["name"], *sub.get("aliases", [])]:
                return sub
    return cmd


failures = []
for line in open(sys.argv[2]).read().splitlines():
    if not line.strip():
        continue
    invocation, status, payload = line.split("\t")
    status = int(status)
    raw = bytes.fromhex(payload)
    entry = declaration(invocation)
    declared = bool(entry.get("json"))

    try:
        json.loads(raw)
        is_json = bool(raw.strip())
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
        is_json = False

    if declared and not is_json:
        failures.append(
            f"{invocation!r} declares json:true but --json printed no JSON "
            f"(exit {status}): {raw[:120]!r}"
        )
    elif declared:
        # Parsing is not enough for a machine contract: a banner or an escape
        # sequence around the document breaks every caller that pipes it.
        if status != 0:
            # A non-zero exit is not automatically a parity problem. A health
            # command reports its verdict that way — `doctor` exits 1 when a
            # check warns, which is the whole point of running it. What must
            # not happen is the exit code and the document disagreeing about
            # the same run, so that is what is checked instead of the status
            # alone.
            document = json.loads(raw)
            reported = document.get("status") if isinstance(document, dict) else None
            if reported in (None, "ok"):
                failures.append(
                    f"{invocation!r} declares json:true but exited {status} "
                    f"while its document reports status {reported!r}")
        if b"\x1b" in raw:
            failures.append(f"{invocation!r}: ANSI escape leaked into --json stdout")
        if raw.lstrip()[:1] not in (b"{", b"["):
            failures.append(f"{invocation!r}: --json stdout does not start with JSON")
    elif is_json:
        failures.append(
            f"{invocation!r} prints JSON under --json but the registry does not "
            f"declare it (json is {entry.get('json')!r})"
        )

if failures:
    print(f"FAIL: {len(failures)} output-mode parity problem(s)", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)
print(f"  ok: {len(open(sys.argv[2]).read().splitlines())} invocations match their declaration")
PY

python3 "$run_dir/compare.py" "$REGISTRY" "$run_dir/observed.txt"

echo "[4/4] the parity check itself fires in both directions"
# A gate that cannot fail is not a gate. Both fixtures replay the observations
# above against a registry mutated to state the opposite of what was measured.
mutate_registry() {
  # mutate_registry <output> <python body operating on `doc`>
  python3 - "$REGISTRY" "$1" "$2" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1]))


def command(name):
    entry = next((c for c in doc["commands"] if c["name"] == name), None)
    if entry is None:
        sys.exit(f"registry has no {name!r} command to mutate")
    return entry


def subcommand(parent, name):
    entry = next(
        (s for s in command(parent).get("subcommands", []) if s["name"] == name), None
    )
    if entry is None:
        sys.exit(f"registry has no {parent!r} subcommand {name!r} to mutate")
    return entry


exec(sys.argv[3], {"doc": doc, "command": command, "subcommand": subcommand})
json.dump(doc, open(sys.argv[2], "w"))
PY
}

# Coordinates expect parity failure behavior.
expect_parity_failure() {
  # expect_parity_failure <fixture> <what> <expected stderr substring> [observed]
  local fixture="$1" what="$2" reason="$3" observed="${4:-$run_dir/observed.txt}" out
  if out="$(python3 "$run_dir/compare.py" "$fixture" "$observed" 2>&1)"; then
    echo "parity check accepted $what" >&2
    exit 1
  fi
  # Exit status alone is not proof: a crashed comparison is also non-zero.
  case "$out" in
    *"$reason"*) ;;
    *)
      echo "parity check rejected $what for the wrong reason:" >&2
      echo "$out" >&2
      exit 1
      ;;
  esac
}

# Forward: a claim with nothing behind it. This is the `skills` defect — the
# registry advertised JSON that mq-skills.py has never had a flag for.
mutate_registry "$run_dir/false-claim.json" '''
entry = command("version")
entry["json"] = True
entry["output_modes"] = ["human", "json"]
'''
expect_parity_failure "$run_dir/false-claim.json" "a json:true claim that prints no JSON" \
  "'version' declares json:true but --json printed no JSON"

# Reverse: real JSON the registry stays silent about. This is the `system
# doctor` defect, and the direction a static check can never see.
mutate_registry "$run_dir/silent-json.json" '''
entry = subcommand("system", "doctor")
entry["json"] = False
entry["output_modes"] = ["human"]
'''
expect_parity_failure "$run_dir/silent-json.json" "undeclared JSON output" \
  "'system doctor' prints JSON under --json but the registry does not declare it"

# Third: the exit code and the document disagreeing. A non-zero exit is allowed
# above so that `doctor` can report a warning verdict, and an allowance that
# nothing tests is a hole. This fixture mutates the observation rather than the
# registry — a run that exited 1 while its document claims everything is ok.
python3 - "$run_dir/observed.txt" "$run_dir/disagreeing.txt" <<'PY'
import json
import sys

rows, patched = [], False
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if not line.strip():
        continue
    invocation, status, payload = line.split("\t")
    if invocation == "doctor" and not patched:
        document = json.loads(bytes.fromhex(payload))
        document["status"] = "ok"
        payload = json.dumps(document).encode("utf-8").hex()
        status, patched = "1", True
    rows.append("\t".join((invocation, status, payload)))
if not patched:
    sys.exit("no 'doctor' observation to mutate")
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(rows) + "\n")
PY
expect_parity_failure "$REGISTRY" "an exit code contradicting its own document" \
  "exited 1 while its document reports status 'ok'" "$run_dir/disagreeing.txt"

echo "  ok: a false claim, undeclared JSON, and a contradicted exit code are all rejected"

bash -n "$0"
echo "OK: the registry's output modes match observed behaviour"
