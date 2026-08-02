#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
V1_ROOT="$PROJECT_ROOT/terminal/mqlaunch-v1"
V1="$V1_ROOT/mqlaunch.sh"
UI="$V1_ROOT/lib/ui.sh"
ROUTER="$V1_ROOT/lib/router.sh"
# The performance data layer moved out of this tree on 2026-08-02, so that
# nothing live had to reach into a frozen tree for working code. v1 sources it
# from its new home; the assertions below still apply, to the file itself.
PERF="$PROJECT_ROOT/mqlaunch/lib/performance.sh"
DEV="$V1_ROOT/commands/dev.sh"
TOOLS="$V1_ROOT/commands/tools.sh"

# Marks a passing check.
pass() {
  echo "[PASS] $1"
}

# Marks a failing check.
fail() {
  echo "[FAIL] $1"
  exit 1
}

# Coordinates assert file behavior.
assert_file() {
  local path="$1"
  local label="$2"
  [[ -f "$path" ]] || fail "$label missing: $path"
  pass "$label exists"
}

# Coordinates assert grep behavior.
assert_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -qE "$pattern" "$file" || fail "$label"
  pass "$label"
}

# Coordinates assert cmd ok behavior.
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
assert_grep 'print_warning_block|surface_row "WARNINGS"' "$PERF" "Performance renders warning block"
assert_grep 'print_kv ' "$DEV" "Dev uses shared print_kv"
assert_grep 'print_kv ' "$TOOLS" "Tools uses shared print_kv"

assert_grep 'performance\|perf' "$ROUTER" "Router contains performance route"
assert_grep 'dev\|git\|dev-v1' "$ROUTER" "Router contains dev route"
assert_grep 'tools\|tools-v1\|menu-tools-v1' "$ROUTER" "Router contains tools route"
assert_grep 'help\|-h\|--help' "$ROUTER" "Router contains help route"

echo
echo "All v1 checks passed."
