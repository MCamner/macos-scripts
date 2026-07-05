#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
README="$ROOT/README.md"
COMMANDS="$ROOT/docs/COMMANDS.md"
ROADMAP="$ROOT/ROADMAP.md"

echo "SMOKE: mqlaunch obsidian direct command routes"

echo "[1/5] files exist"
test -f "$COMMAND_MODE"
test -f "$README"
test -f "$COMMANDS"
test -f "$ROADMAP"

echo "[2/5] shell syntax"
bash -n "$COMMAND_MODE"

echo "[3/5] command mode exposes read-only obsidian subcommands"
grep -q 'status|doctor)' "$COMMAND_MODE"
grep -q 'mqobsidian-doctor.sh' "$COMMAND_MODE"
grep -q 'mq_obsidian_show_inbox' "$COMMAND_MODE"
grep -q 'mq_obsidian_open_view_picker' "$COMMAND_MODE"
grep -q 'usage: mqlaunch obsidian \[status|inbox|views\]' "$COMMAND_MODE"

echo "[4/5] docs expose direct routes and boundary"
grep -q 'mqlaunch obsidian status' "$README"
grep -q 'mqlaunch obsidian inbox' "$COMMANDS"
grep -q 'mqlaunch obsidian views' "$COMMANDS"
grep -q 'do not score, promote, reject, or' "$COMMANDS"

echo "[5/5] roadmap marks the status alias step done"
grep -q '| Done | Add `mqlaunch obsidian status` or documented alias for current menu/status |' "$ROADMAP"

echo "OK: mqlaunch obsidian command route smoke test passed"
