#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

export MACOS_SCRIPTS_HOME="$ROOT"
# shellcheck source=/dev/null
source "$COMMAND_MODE"

pause_enter() {
  printf 'pause-called\n' >> "$TMPDIR_TEST/pause.log"
  return 0
}

assert_status() {
  local expected="$1"
  shift
  local actual

  set +e
  "$@" >"$TMPDIR_TEST/stdout" 2>"$TMPDIR_TEST/stderr"
  actual=$?
  set -e
  [[ $actual -eq $expected ]] || {
    echo "expected exit $expected, got $actual for: $*" >&2
    return 1
  }
}

echo "SMOKE: delegated exit-code contract"

echo "[1/7] missing backend is non-zero"
unset -f run_agent_command 2>/dev/null || true
assert_status 1 dispatch_cli_command review
grep -q 'bridge not loaded' "$TMPDIR_TEST/stderr"

echo "[2/7] usage and runtime failures propagate"
run_agent_command() { return "${MQ_TEST_BACKEND_STATUS:-0}"; }
MQ_TEST_BACKEND_STATUS=2 assert_status 2 dispatch_cli_command review
MQ_TEST_BACKEND_STATUS=42 assert_status 42 dispatch_cli_command stack status

echo "[3/7] HAL pause does not overwrite backend status"
mq_hal_run() { return "${MQ_TEST_BACKEND_STATUS:-0}"; }
rm -f "$TMPDIR_TEST/pause.log"
MQ_TEST_BACKEND_STATUS=42 assert_status 42 dispatch_cli_command hal brief
[[ -s "$TMPDIR_TEST/pause.log" ]]

echo "[4/7] JSON stdout stays clean"
mq_hal_run() {
  printf '{"schema":"hal.test.v1"}\n'
  return 42
}
rm -f "$TMPDIR_TEST/pause.log"
assert_status 42 dispatch_cli_command hal brief --json
[[ "$(cat "$TMPDIR_TEST/stdout")" == '{"schema":"hal.test.v1"}' ]]
[[ ! -e "$TMPDIR_TEST/pause.log" ]]
[[ ! -s "$TMPDIR_TEST/stderr" ]]

echo "[5/7] full launcher returns backend status without double dispatch"
mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/agent"
cat > "$TMPDIR_TEST/bin/uv" <<EOF
#!/usr/bin/env bash
printf 'called\n' >> '$TMPDIR_TEST/backend.log'
exit 42
EOF
chmod +x "$TMPDIR_TEST/bin/uv"
set +e
HOME="$TMPDIR_TEST" \
  PATH="$TMPDIR_TEST/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  MACOS_SCRIPTS_HOME="$ROOT" \
  MQ_AGENT_BIN="$TMPDIR_TEST/agent" \
  MQ_NO_TUI=1 \
  MQLAUNCH_HEADLESS=1 \
  "$ROOT/terminal/launchers/mqlaunch.sh" review \
  >"$TMPDIR_TEST/launcher.stdout" 2>"$TMPDIR_TEST/launcher.stderr"
launcher_status=$?
set -e
[[ $launcher_status -eq 42 ]] || {
  echo "full launcher: expected exit 42, got $launcher_status" >&2
  exit 1
}
[[ "$(wc -l < "$TMPDIR_TEST/backend.log" | tr -d ' ')" -eq 1 ]] || {
  echo "full launcher delegated more than once" >&2
  exit 1
}

echo "[6/7] external script delegates propagate their status"
# Steps 1-5 stub shell functions, which only reaches the agent and HAL families.
# Most of the surface delegates to scripts under $BASE_DIR instead, and those
# were never covered. Both cases below are real argparse failures.
run_launcher() {
  set +e
  MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 MQLAUNCH_HEADLESS=1 \
    timeout 60 "$ROOT/terminal/launchers/mqlaunch.sh" "$@" \
    </dev/null >"$TMPDIR_TEST/stdout" 2>"$TMPDIR_TEST/stderr"
  local status=$?
  set -e
  return "$status"
}

for bad_case in "repos LIST" "skills no-such-subcommand"; do
  # shellcheck disable=SC2086
  set -- $bad_case
  if run_launcher "$@"; then
    echo "delegated failure reported success: mqlaunch $bad_case" >&2
    exit 1
  fi
  grep -q 'usage:' "$TMPDIR_TEST/stderr" || {
    echo "expected a delegate usage error on stderr for: mqlaunch $bad_case" >&2
    exit 1
  }
done

# The success path must stay 0, so the fix cannot be "always return non-zero".
run_launcher repos list || {
  echo "successful delegation no longer exits 0" >&2
  exit 1
}

echo "[7/7] no delegating branch ends in an unconditional return 0"
# The behavioural cases above pin two branches. This keeps the other nineteen
# from drifting back, and stops new ones from being written that way.
python3 - "$COMMAND_MODE" <<'PY'
import re
import sys

lines = open(sys.argv[1]).read().splitlines()
start = next(i for i, l in enumerate(lines) if l.strip() == 'case "$area" in')

branch = re.compile(
    r'((?:"[^"]*"|[A-Za-z0-9_*/.\-])+(?:\|(?:"[^"]*"|[A-Za-z0-9_*/.\-])+)*)\)'
)
depth = 0
current = None
bodies = {}
for i in range(start, len(lines)):
    s = lines[i].strip()
    if s.startswith("case ") and re.match(r'case\s+"?\$', s):
        depth += 1
    elif s.startswith("esac"):
        depth -= 1
        if depth == 0:
            break
    elif branch.match(s):
        if depth == 1:
            current = (branch.match(s).group(1), i + 1)
            bodies[current] = []
        elif current is not None:
            bodies[current].append(s)
    elif current is not None:
        bodies[current].append(s)

offenders = []
for (name, line), body in bodies.items():
    text = "\n".join(body)
    if not re.search(r"\$BASE_DIR/(tools|terminal|bin|automation)", text):
        continue
    if re.search(r"^return 0$", text, re.M):
        offenders.append(f"  line {line}: {name}")

if offenders:
    print(
        "these branches delegate and then discard the delegate's status:",
        file=sys.stderr,
    )
    print("\n".join(offenders), file=sys.stderr)
    sys.exit(1)
PY

bash -n "$0"
echo "OK: delegated failures preserve their exit status"
