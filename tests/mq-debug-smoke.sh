#!/usr/bin/env bash
# Smoke (P1 Step 11c): mq_debug is silent by default, emits to stderr (never
# stdout) under MQ_DEBUG, and always returns 0 so it is safe as an
# `... || mq_debug "why"` tail on a best-effort command.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Marks a failing check.
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

# shellcheck source=/dev/null
source "$ROOT/ui/terminal-ui/mq-ui.sh"

command -v mq_debug >/dev/null 2>&1 || fail "mq_debug is not defined by mq-ui.sh"

# Silent by default and for disabling values.
for v in "" 0 false no off; do
  out="$(MQ_DEBUG="$v" mq_debug "should-stay-hidden" 2>&1)"
  [[ -z "$out" ]] || fail "mq_debug leaked output for MQ_DEBUG='$v': $out"
done

# Enabled: writes to stderr, not stdout.
err="$(MQ_DEBUG=1 mq_debug "visible-token" 2>&1 1>/dev/null)"
printf '%s' "$err" | grep -q 'visible-token' || fail "mq_debug did not emit on stderr under MQ_DEBUG=1"
std="$(MQ_DEBUG=1 mq_debug "visible-token" 2>/dev/null)"
[[ -z "$std" ]] || fail "mq_debug wrote to stdout (must be stderr-only): $std"

# Returns 0 even when enabled (safe as an `|| mq_debug` tail).
MQ_DEBUG=1 mq_debug "rc-check" 2>/dev/null || fail "mq_debug returned non-zero"

printf '[PASS] mq_debug: silent by default, stderr-only, rc=0 under MQ_DEBUG\n'
