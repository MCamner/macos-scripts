#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$HOME/macos-scripts"
V1_ROOT="$PROJECT_ROOT/terminal/mqlaunch-v1"
V1="$V1_ROOT/mqlaunch.sh"
UI="$V1_ROOT/lib/ui.sh"
ROUTER="$V1_ROOT/lib/router.sh"
PERF="$V1_ROOT/commands/performance.sh"
DEV="$V1_ROOT/commands/dev.sh"
TOOLS="$V1_ROOT/commands/tools.sh"

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  exit 1
}

assert_file() {
  local path="$1"
  local label="$2"
  [[ -f "$path" ]] || fail "$label missing: $path"
  pass "$label exists"
}

assert_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -qE "$pattern" "$file" || fail "$label"
  pass "$label"
}

assert_cmd_ok() {
  local label="$1"
  shift
  "$@" >/dev/null 2>&1 || fail "$label"
  pass "$label"
}

assert_file "$V1" "V1 launcher"
assert_file "$UI" "Shared UI helper"
assert_file "$ROUTER" "Router"
assert_file "$PERF" "Performance command file"
assert_file "$DEV" "Dev command file"
assert_file "$TOOLS" "Tools command file"

assert_cmd_ok "V1 help works" bash "$V1" help

assert_grep 'print_kv\(\)' "$UI" "Shared print_kv helper exists"
assert_grep 'print_warning_block\(\)' "$UI" "Shared warning helper exists"

assert_grep 'print_kv ' "$PERF" "Performance uses shared print_kv"
assert_grep 'print_warning_block' "$PERF" "Performance uses shared warning block"
assert_grep 'print_kv ' "$DEV" "Dev uses shared print_kv"
assert_grep 'print_kv ' "$TOOLS" "Tools uses shared print_kv"

assert_grep 'performance\|perf' "$ROUTER" "Router contains performance route"
assert_grep 'dev\|git\|dev-v1' "$ROUTER" "Router contains dev route"
assert_grep 'tools\|tools-v1\|menu-tools-v1' "$ROUTER" "Router contains tools route"
assert_grep 'help\|-h\|--help' "$ROUTER" "Router contains help route"

echo
echo "All v1 checks passed."
