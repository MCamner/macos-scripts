#!/usr/bin/env bash
# `mqlaunch hal changes` must reach `mq-hal changes` with its flags as separate
# argv. The bridge fallback joins args into one free-text prompt, which would
# send `changes --json` to the Ollama router instead.
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
  bash "$ROOT/terminal/bridges/hal-bridge.sh" changes --since last --json)"
expected="$(printf '%s\n' changes --since last --json)"
[[ "$out" == "$expected" ]] || fail "bridge passed: $(tr '\n' ' ' <<<"$out")"

MQ_HAL_BIN="$WORK/mq-hal" BASE_DIR="$ROOT" \
  bash "$ROOT/terminal/bridges/hal-bridge.sh" --help | grep -q "mqlaunch hal changes" \
  || fail "usage does not list mqlaunch hal changes"

grep -q "mqlaunch hal changes" "$ROOT/docs/hal-command-surface.md" \
  || fail "docs/hal-command-surface.md does not document mqlaunch hal changes"

printf '[PASS] mqlaunch hal changes passes argv to mq-hal changes\n'
