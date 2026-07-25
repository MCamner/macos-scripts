#!/usr/bin/env bash
set -euo pipefail

# Command words are case-insensitive. dispatch_cli_command lowercases them into
# `sub` before routing, but two branches shifted and re-read the raw "${1:-}"
# instead, so `mqlaunch system TIME` worked while `mqlaunch repos LIST` did not.
#
# Only the command word is normalised. Arguments after it keep their case, and
# free-text that a delegate parses itself is never touched.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo "SMOKE: command word normalization"

run_launcher() {
  set +e
  MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 MQLAUNCH_HEADLESS=1 \
    timeout 60 "$LAUNCHER" "$@" \
    </dev/null >"$TMPDIR_TEST/stdout" 2>"$TMPDIR_TEST/stderr"
  local status=$?
  set -e
  return "$status"
}

echo "[1/4] an uppercase subcommand routes like its lowercase form"
run_launcher repos list || {
  echo "baseline failed: mqlaunch repos list should exit 0" >&2
  exit 1
}
cp "$TMPDIR_TEST/stdout" "$TMPDIR_TEST/lower.stdout"

run_launcher repos LIST || {
  echo "mqlaunch repos LIST did not route like 'repos list'" >&2
  cat "$TMPDIR_TEST/stderr" >&2
  exit 1
}
diff -q "$TMPDIR_TEST/lower.stdout" "$TMPDIR_TEST/stdout" >/dev/null || {
  echo "mqlaunch repos LIST produced different output than 'repos list'" >&2
  exit 1
}

echo "[2/4] mixed case routes too, and an unknown subcommand still fails"
run_launcher repos List || {
  echo "mqlaunch repos List did not route like 'repos list'" >&2
  exit 1
}
if run_launcher repos NoSuchSubcommand; then
  echo "an unknown subcommand must not be accepted after normalization" >&2
  exit 1
fi

echo "[3/4] srm routes its agent verbs case-insensitively"
# srm's agent verbs are routed by mqlaunch; the rest of the line is a question
# owned by srm.sh. Stub the bridge so nothing reaches mq-agent.
(
  export MACOS_SCRIPTS_HOME="$ROOT"
  # shellcheck source=/dev/null
  source "$COMMAND_MODE"
  pause_enter() { return 0; }
  run_agent_command() {
    printf '%s\n' "$1" > "$TMPDIR_TEST/verb"
    return 0
  }
  dispatch_cli_command srm COCHANGE >/dev/null 2>&1
)
[[ "$(cat "$TMPDIR_TEST/verb" 2>/dev/null)" == "memory-cochange" ]] || {
  echo "mqlaunch srm COCHANGE did not reach the memory-cochange verb" >&2
  exit 1
}

echo "[4/4] normalization does not reach past the command word"
# `srm` with no recognised verb hands the whole line to srm.sh as a question.
# Lowercasing that would corrupt it, so the raw words must survive.
(
  export MACOS_SCRIPTS_HOME="$ROOT"
  # shellcheck source=/dev/null
  source "$COMMAND_MODE"
  pause_enter() { return 0; }
  BASE_DIR="$TMPDIR_TEST"
  mkdir -p "$TMPDIR_TEST/tools/scripts"
  cat > "$TMPDIR_TEST/tools/scripts/srm.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$TMPDIR_STUB/args"
STUB
  chmod +x "$TMPDIR_TEST/tools/scripts/srm.sh"
  TMPDIR_STUB="$TMPDIR_TEST" dispatch_cli_command srm "What does HAL do" >/dev/null 2>&1
)
[[ "$(cat "$TMPDIR_TEST/args" 2>/dev/null)" == "What does HAL do" ]] || {
  echo "the question was altered on its way to srm.sh: $(cat "$TMPDIR_TEST/args" 2>/dev/null)" >&2
  exit 1
}

bash -n "$0"
echo "OK: command words are case-insensitive, arguments are not"
