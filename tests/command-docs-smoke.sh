#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
README="$ROOT/README.md"
COMMANDS="$ROOT/docs/COMMANDS.md"

echo "SMOKE: documented command routes"

echo "[1/3] command docs mention high-visibility direct routes"
grep -q 'mqlaunch palette' "$README"
grep -q 'mqlaunch palette' "$COMMANDS"
grep -q 'mqlaunch ghost' "$COMMANDS"
grep -q 'mqlaunch pulse' "$COMMANDS"
grep -q 'mqlaunch reap' "$COMMANDS"
grep -q 'mqlaunch guard' "$COMMANDS"
grep -q 'mqlaunch mc' "$COMMANDS"
grep -q 'mqlaunch nickname-set' "$COMMANDS"
grep -q 'mqlaunch theme-macos' "$COMMANDS"
grep -q 'mqlaunch theme-reset' "$COMMANDS"
grep -q 'mqlaunch bundle' "$COMMANDS"

echo "[2/3] command mode dispatches documented direct routes before AI fallback"
grep -q 'palette|fzf|search)' "$COMMAND_MODE"
grep -q 'ghost)' "$COMMAND_MODE"
grep -q 'pulse)' "$COMMAND_MODE"
grep -q 'reap)' "$COMMAND_MODE"
grep -q 'guard)' "$COMMAND_MODE"
grep -q 'mc)' "$COMMAND_MODE"
grep -q 'nickname-set|nick-set|nick)' "$COMMAND_MODE"
grep -q 'theme-macos)' "$COMMAND_MODE"
grep -q 'theme-reset)' "$COMMAND_MODE"
grep -q 'debug|bundle|debug-bundle|support)' "$COMMAND_MODE"

echo "[3/3] shell syntax"
bash -n "$0"

echo "OK: documented command routes are covered"
