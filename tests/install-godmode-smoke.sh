#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/tools/scripts/install-godmode.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mq-godmode-test.XXXXXX")"
CODEX_DIR="$TEST_ROOT/codex"
CLAUDE_DIR="$TEST_ROOT/claude"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

bash "$INSTALLER" --help | grep -q '^Usage:' || fail "help is missing usage"

status=0
bash "$INSTALLER" --unknown >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || fail "unknown option must exit 2"

bash "$INSTALLER" \
  --codex-dir "$CODEX_DIR" \
  --claude-dir "$CLAUDE_DIR" \
  --dry-run >/dev/null
[ ! -e "$CODEX_DIR" ] || fail "dry-run created Codex directory"
[ ! -e "$CLAUDE_DIR" ] || fail "dry-run created Claude directory"

bash "$INSTALLER" \
  --codex-dir "$CODEX_DIR" \
  --claude-dir "$CLAUDE_DIR" >/dev/null

CODEX_PROMPT="$CODEX_DIR/prompts/godmode.md"
CLAUDE_PROMPT="$CLAUDE_DIR/commands/godmode.md"
[ -f "$CODEX_PROMPT" ] || fail "Codex prompt was not installed"
[ -f "$CLAUDE_PROMPT" ] || fail "Claude prompt was not installed"
cmp -s "$CODEX_PROMPT" "$CLAUDE_PROMPT" || fail "agent prompts differ"
grep -q 'memory/learn/agent/<repo>.md' "$CODEX_PROMPT" || fail "mqobsidian read order is missing"
grep -q 'codegraph_explore' "$CODEX_PROMPT" || fail "CodeGraph-first rule is missing"
grep -q 'Do not initialize, rebuild, install, or sync CodeGraph' "$CODEX_PROMPT" || fail "CodeGraph mutation guard is missing"

bash "$INSTALLER" \
  --codex-dir "$CODEX_DIR" \
  --claude-dir "$CLAUDE_DIR" >/dev/null

backup_count="$(find "$TEST_ROOT" -type f -name '*.bak' | wc -l | tr -d ' ')"
[ "$backup_count" -eq 0 ] || fail "idempotent reinstall created backups"

echo "install-godmode smoke passed"
