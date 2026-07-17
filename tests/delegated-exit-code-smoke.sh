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

echo "[1/5] missing backend is non-zero"
unset -f run_agent_command 2>/dev/null || true
assert_status 1 dispatch_cli_command review
grep -q 'bridge not loaded' "$TMPDIR_TEST/stderr"

echo "[2/5] usage and runtime failures propagate"
run_agent_command() { return "${MQ_TEST_BACKEND_STATUS:-0}"; }
MQ_TEST_BACKEND_STATUS=2 assert_status 2 dispatch_cli_command review
MQ_TEST_BACKEND_STATUS=42 assert_status 42 dispatch_cli_command stack status

echo "[3/5] HAL pause does not overwrite backend status"
mq_hal_run() { return "${MQ_TEST_BACKEND_STATUS:-0}"; }
rm -f "$TMPDIR_TEST/pause.log"
MQ_TEST_BACKEND_STATUS=42 assert_status 42 dispatch_cli_command hal brief
[[ -s "$TMPDIR_TEST/pause.log" ]]

echo "[4/5] JSON stdout stays clean"
mq_hal_run() {
  printf '{"schema":"hal.test.v1"}\n'
  return 42
}
rm -f "$TMPDIR_TEST/pause.log"
assert_status 42 dispatch_cli_command hal brief --json
[[ "$(cat "$TMPDIR_TEST/stdout")" == '{"schema":"hal.test.v1"}' ]]
[[ ! -e "$TMPDIR_TEST/pause.log" ]]
[[ ! -s "$TMPDIR_TEST/stderr" ]]

echo "[5/5] full launcher returns backend status without double dispatch"
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

bash -n "$0"
echo "OK: delegated failures preserve their exit status"
