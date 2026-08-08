#!/usr/bin/env bash
set -euo pipefail

# When a delegated repo is not installed, mqlaunch has to say so in a way the
# operator can act on. mq-hal already does — hal-bridge.sh has mq_hal_missing(),
# which names the binary, prints two commands to run, and returns 127.
#
# mq-agent did not. `MQ_AGENT_BIN=/nonexistent mqlaunch review` printed
#
#     _run_agent:cd:1: no such file or directory: /nonexistent
#
# which is zsh reporting a failed cd, complete with an internal function name.
# It says nothing about mq-agent being a separate repo that has to be installed,
# and nothing about what to do next. ROADMAP P2 lists this under "Improve
# failure messages for missing delegated tools".
#
# This holds both bridges to the same contract, so the good one cannot regress
# to the bad one's behaviour either.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
HAL_BRIDGE="$ROOT/terminal/bridges/hal-bridge.sh"

echo "SMOKE: missing delegate messages"

echo "[1/5] syntax"
bash -n "$AGENT_MENU"
bash -n "$HAL_BRIDGE"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Drive the real function with the delegate pointed at a path that does not
# exist. Sourcing rather than invoking mqlaunch keeps this off the network and
# away from a real mq-agent, so the test measures the guard and nothing else.
run_agent_missing() {
  bash -c '
    set -uo pipefail
    BASE_DIR="'"$ROOT"'"
    MQ_AGENT_BIN="/nonexistent-delegate-for-this-test"
    # Stubs for the UI helpers the menu expects from mq-ui.sh.
    ui_err() { echo "$*" >&2; }
# Pauses until Enter is pressed.
    pause_enter() { :; }
    source "'"$AGENT_MENU"'" >/dev/null 2>&1 || true
    _run_agent doctor
    echo "EXIT=$?"
  ' 2>&1
}

out="$(run_agent_missing)"
status="$(printf '%s\n' "$out" | sed -n 's/^EXIT=//p' | tail -1)"

echo "[2/5] the message is written for an operator, not by the shell"
# The first draft of this step accepted any line containing "mq-agent", which
# the raw failure passes by accident — zsh says `_run_agent:cd:1: ...` and bash
# says `mq-agent-menu.sh: line 36: cd: ...`. Both name the script. Neither is a
# message. So the shape is what is checked: a deliberate error line, and no
# shell diagnostic anywhere in the output.
printf '%s\n' "$out" | grep -qE '(^|[^a-z])(cd|line [0-9]+):' && {
  echo "  still leaking the shell's own error:" >&2
  printf '%s\n' "$out" | head -3 >&2
  exit 1
}
printf '%s\n' "$out" | grep -qiE '^(ERROR|mqlaunch:).*mq-agent' || {
  echo "  no deliberate error line naming mq-agent" >&2
  printf '%s\n' "$out" | head -3 >&2
  exit 1
}

echo "[3/5] it names the path it looked at"
printf '%s\n' "$out" | grep -q '/nonexistent-delegate-for-this-test' || {
  echo "  the message does not say where it looked" >&2
  exit 1
}

echo "[4/5] it says what to do next"
# A message that only states the problem leaves the operator where it found
# them. mq_hal_missing prints two runnable lines; this asks for at least one.
printf '%s\n' "$out" | grep -qE 'https?://|git clone|ls -l|install' || {
  echo "  the message offers no next step" >&2
  printf '%s\n' "$out" | head -6 >&2
  exit 1
}

echo "[5/5] a missing delegate is 127, matching mq-hal"
[[ "$status" == "127" ]] || {
  echo "  expected exit 127, got ${status:-<none>}" >&2
  exit 1
}
grep -q 'return 127' "$HAL_BRIDGE" || {
  echo "  hal-bridge.sh no longer returns 127; the two have diverged" >&2
  exit 1
}

echo "PASS: missing delegate messages"
