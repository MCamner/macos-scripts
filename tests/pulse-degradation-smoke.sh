#!/usr/bin/env bash
# Holds how Pulse behaves when a delegate is slow, and what a run costs.
#
# One rule under all of it, and it is the rule the quality collector broke until
# this file existed:
#
#   timeout  is not  FAIL on the subject
#   timeout  is      UNAVAILABLE on the observation
#
# GitHub taking too long to answer does not mean CI is broken. A gate killed at
# its budget is not a failing gate — and reporting it as one would put "run
# mqlaunch selftest" in front of an operator whose selftest is what timed out.
#
# The concurrency step is here rather than in a benchmark because the property
# that matters is not a number: it is that running the gates at the same time
# did not change the order they are reported in.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULSE="$ROOT/tools/scripts/pulse.sh"
FIXTURE="$ROOT/tests/fixtures/pulse/mq.pulse.v1.json"

echo "SMOKE: pulse degradation and cost"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

stub="$run_dir/stub"
mkdir -p "$stub/tools/scripts" "$stub/scripts" "$stub/tests" "$stub/mqlaunch/lib" "$stub/bin"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$PULSE" "$stub/tools/scripts/pulse.sh"

cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
chmod +x "$stub/tools/scripts/doctor.sh"
cat > "$stub/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({"repos": [{"name": "mq-agent", "git": True, "clean": True,
  "modified": 0, "untracked": 0, "branch": "main", "upstream": "origin/main",
  "ahead": 0, "behind": 0}], "summary": {"total": 1, "dirty": 0}}))
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
  MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$run_dir/absent" NO_COLOR=1 \
    "$@" >"$run_dir/$out.out" 2>"$run_dir/$out.err" </dev/null
  echo $? > "$run_dir/$out.status"
  set -e
}

echo "[1/7] a gate that runs past its budget is UNAVAILABLE, not FAIL"
# The defect this gate exists for. Before the budget was told apart from a
# non-zero exit, a slow machine reported the repo's own quality as failing.
cat > "$stub/scripts/check-skills.sh" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
chmod +x "$stub/scripts/check-skills.sh"
PULSE_COLLECTOR_TIMEOUT=1 pulse_run slowgate bash "$stub/tools/scripts/pulse.sh" quality --json
python3 - "$run_dir/slowgate.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
gates = {i["subject"]: i for i in doc["sections"]["quality"]}
skills = gates["Skills"]
assert skills["status"] == "UNAVAILABLE", \
    f"a gate that timed out reported {skills['status']}"
assert "timed out" in skills["summary"], skills["summary"]
assert "next_command" not in skills, \
    "a timed-out gate must not tell the operator to run the gates again"
assert doc["status"] == "WARN", \
    f"a run whose only problem is a timeout reported {doc['status']}"
assert doc["summary"]["fail"] == 0, doc["summary"]
others = {s for name, i in gates.items() if name != "Skills" for s in [i["status"]]}
assert others == {"PASS"}, f"the other gates reported {others}"
print("  ok: UNAVAILABLE, named as a timeout, and the other four still ran")
PY

echo "[2/7] the timeout is named, so it is not confused with an empty answer"
# "produced no report" and "timed out after 1s" are different facts, and an
# operator chasing a flaky delegate needs to know which one happened.
cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
PULSE_COLLECTOR_TIMEOUT=1 pulse_run slowdoctor bash "$stub/tools/scripts/pulse.sh" system --json
python3 - "$run_dir/slowdoctor.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
item = doc["sections"]["system"][0]
assert item["status"] == "UNAVAILABLE", item["status"]
assert item["summary"] == "timed out after 1s", item["summary"]
print("  ok: the item says which budget was spent")
PY
cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
printf ''
EOF
pulse_run emptydoctor bash "$stub/tools/scripts/pulse.sh" system --json
python3 - "$run_dir/emptydoctor.out" <<'PY'
import json, sys

item = json.load(open(sys.argv[1]))["sections"]["system"][0]
assert item["status"] == "UNAVAILABLE", item["status"]
assert item["summary"] == "doctor produced no report", item["summary"]
print("  ok: an empty answer keeps its own wording")
PY
cat > "$stub/tools/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF

echo "[3/7] a slow GitHub does not become a broken CI"
# The subject is CI and pull requests; the observation is gh. A budget spent on
# the observation says nothing about the subject.
cat > "$stub/bin/gh" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
chmod +x "$stub/bin/gh"
set +e
PATH="$stub/bin:$PATH" PULSE_GH_TIMEOUT=1 \
  MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$run_dir/absent" NO_COLOR=1 \
  bash "$stub/tools/scripts/pulse.sh" git --json \
  >"$run_dir/slowgh.out" 2>/dev/null </dev/null
echo $? > "$run_dir/slowgh.status"
set -e
python3 - "$run_dir/slowgh.out" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
items = {i["subject"]: i for i in doc["sections"]["git"]}
for subject in ("Pull requests", "CI"):
    item = items[subject]
    assert item["status"] == "UNAVAILABLE", f"{subject} reported {item['status']}"
    assert "timed out" in item["summary"], f"{subject}: {item['summary']}"
# The local half of the same collector still answered. One slow dependency must
# not take the readings that never needed it.
assert items["Worktree"]["status"] in {"PASS", "WARN"}, items["Worktree"]
assert doc["summary"]["fail"] == 0, doc["summary"]
print("  ok: gh timed out, the worktree reading survived, nothing failed")
PY
rm -f "$stub/bin/gh"

echo "[4/7] the gates run concurrently and report in list order"
# Five gates that each sleep a second. Serially that is five seconds; the
# assertion is loose enough to survive a loaded machine and tight enough that
# a serial implementation cannot pass.
for gate in "scripts/check-runtime-authority.sh" "scripts/check-skills.sh" \
            "tests/registry-consumer-parity-smoke.sh" "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nsleep 1\nexit 0\n' > "$stub/$gate"
  chmod +x "$stub/$gate"
done
printf 'import time\ntime.sleep(1)\nraise SystemExit(0)\n' \
  > "$stub/tools/scripts/validate-command-registry.py"
started="$(python3 -c 'import time; print(int(time.time() * 1000))')"
pulse_run concurrent bash "$stub/tools/scripts/pulse.sh" quality --plain
ended="$(python3 -c 'import time; print(int(time.time() * 1000))')"
elapsed=$(( ended - started ))
if [[ $elapsed -ge 3000 ]]; then
  echo "FAIL: five one-second gates took ${elapsed}ms — they ran one after another" >&2
  exit 1
fi
order="$(grep -v '^#' "$run_dir/concurrent.out" | cut -f3 | tr '\n' '|')"
expected="Command registry|Runtime authority|Skills|Docs parity|Test inventory|"
if [[ "$order" != "$expected" ]]; then
  echo "FAIL: gates reported as '$order', expected '$expected'" >&2
  exit 1
fi
echo "  ok: ${elapsed}ms for five one-second gates, still in list order"

echo "[5/7] the order does not depend on which gate finishes first"
# Finishing order reversed against listing order. A collector that appended
# results as they arrived would pass step 4 and fail here.
printf '#!/usr/bin/env bash\nsleep 2\nexit 0\n' > "$stub/scripts/check-runtime-authority.sh"
printf 'raise SystemExit(0)\n' > "$stub/tools/scripts/validate-command-registry.py"
for gate in "scripts/check-skills.sh" "tests/registry-consumer-parity-smoke.sh" \
            "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/$gate"
done
pulse_run reordered bash "$stub/tools/scripts/pulse.sh" quality --plain
order="$(grep -v '^#' "$run_dir/reordered.out" | cut -f3 | tr '\n' '|')"
if [[ "$order" != "$expected" ]]; then
  echo "FAIL: with the slowest gate second, the order became '$order'" >&2
  exit 1
fi
echo "  ok: the list decides the order, not the finish line"

echo "[6/7] the document matches the fixture once the timings are normalized"
# The schema is what is pinned. `duration_ms` and this machine's repo list are
# not part of the contract, so they are normalized away rather than recorded —
# a fixture that failed when a gate got faster would be testing the machine.
test -f "$FIXTURE" || { echo "FAIL: the fixture is missing: $FIXTURE" >&2; exit 1; }
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/scripts/check-runtime-authority.sh"
pulse_run fixture bash "$stub/tools/scripts/pulse.sh" --json --no-network --no-stack
python3 - "$run_dir/fixture.out" "$FIXTURE" <<'PY'
import json, sys


def normalize(doc):
    # A wall-clock stamp cannot be pinned, for the same reason duration_ms
    # cannot. `conditions` is deliberately not stripped: it describes the
    # invocation rather than the machine, and this run declares both flags.
    doc.pop("collected_at", None)
    for section in doc.get("sections", {}).values():
        for item in section:
            item.pop("duration_ms", None)
    for item in doc.get("attention", []):
        item.pop("duration_ms", None)
    return doc


observed = normalize(json.load(open(sys.argv[1])))
expected = normalize(json.load(open(sys.argv[2])))

if observed != expected:
    for key in sorted(set(observed) | set(expected)):
        if observed.get(key) != expected.get(key):
            print(f"  {key}:", file=sys.stderr)
            print(f"    expected {json.dumps(expected.get(key))[:400]}", file=sys.stderr)
            print(f"    observed {json.dumps(observed.get(key))[:400]}", file=sys.stderr)
    sys.exit("FAIL: the document drifted from tests/fixtures/pulse/mq.pulse.v1.json")
print("  ok: schema, states and sections match the recorded document")
PY

echo "[7/7] no output mode leaks colour, on a terminal or off one"
# The panel is allowed colour on a TTY and must drop it under NO_COLOR. The
# machine modes are never coloured, and a TTY is where that would break: colour
# is TTY-gated, so a redirected run would pass while a piped-to-a-pty run — an
# operator running it in a terminal — would emit ANSI into the document.
python3 - "$stub" <<'PY'
import os, pty, subprocess, sys

stub = sys.argv[1]
ESC = b"\x1b"


def on_tty(args, no_color=False):
    env = dict(os.environ, MACOS_SCRIPTS_HOME=stub, MQ_AGENT_BIN=f"{stub}/absent")
    env.pop("NO_COLOR", None)
    if no_color:
        env["NO_COLOR"] = "1"
    master, slave = pty.openpty()
    proc = subprocess.Popen(args, stdout=slave, stderr=subprocess.DEVNULL,
                            stdin=subprocess.DEVNULL, env=env)
    os.close(slave)
    out = b""
    while True:
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
    proc.wait()
    os.close(master)
    return out


base = ["bash", f"{stub}/tools/scripts/pulse.sh", "system", "--no-network"]

panel = on_tty(base)
assert ESC in panel, "the panel lost its colour on a terminal"

plain_panel = on_tty(base, no_color=True)
assert ESC not in plain_panel, "NO_COLOR=1 still emitted ANSI"

for mode in ("--json", "--plain"):
    out = on_tty(base + [mode])
    assert ESC not in out, f"{mode} emitted ANSI on a terminal"

import json
json.loads(on_tty(base + ["--json"]))
print("  ok: colour on the panel only, and the document parses from a terminal")
PY

echo "PASS: pulse degradation and cost"
