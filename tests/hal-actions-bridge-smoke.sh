#!/usr/bin/env bash
# `mqlaunch hal actions` must reach `mq-hal actions` with its flags as separate
# argv. The bridge fallback joins args into one free-text prompt, which would
# send `actions --json` to the Ollama router instead.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Marks a failing check.
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

cat >"$WORK/mq-hal" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@"
STUB
chmod +x "$WORK/mq-hal"

out="$(MQ_HAL_BIN="$WORK/mq-hal" BASE_DIR="$ROOT" \
  bash "$ROOT/terminal/bridges/hal-bridge.sh" actions --last 5 --json)"
expected="$(printf '%s\n' actions --last 5 --json)"
[[ "$out" == "$expected" ]] || fail "bridge passed: $(tr '\n' ' ' <<<"$out")"

MQ_HAL_BIN="$WORK/mq-hal" BASE_DIR="$ROOT" \
  bash "$ROOT/terminal/bridges/hal-bridge.sh" --help | grep -q "mqlaunch hal actions" \
  || fail "usage does not list mqlaunch hal actions"

grep -q "mqlaunch hal actions" "$ROOT/docs/hal-command-surface.md" \
  || fail "docs/hal-command-surface.md does not document mqlaunch hal actions"

printf '[PASS] mqlaunch hal actions passes argv to mq-hal actions\n'
