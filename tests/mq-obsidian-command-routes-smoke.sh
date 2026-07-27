#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
README="$ROOT/README.md"
COMMANDS="$ROOT/docs/COMMANDS.md"
ROADMAP="$ROOT/ROADMAP.md"
RELEASE_CHECK="$ROOT/terminal/release/mq-release-check.sh"

echo "SMOKE: mqlaunch obsidian direct command routes"

echo "[1/5] files exist"
test -f "$COMMAND_MODE"
test -f "$AGENT_MENU"
test -f "$README"
test -f "$COMMANDS"
test -f "$ROADMAP"
test -f "$RELEASE_CHECK"

echo "[2/5] shell syntax"
bash -n "$COMMAND_MODE"
bash -n "$AGENT_MENU"
bash -n "$RELEASE_CHECK"

echo "[3/5] command mode exposes read-only obsidian subcommands"
grep -q 'status|doctor)' "$COMMAND_MODE"
grep -q 'mqobsidian-doctor.sh' "$COMMAND_MODE"
grep -q 'mq_obsidian_show_inbox' "$COMMAND_MODE"
grep -q 'mq_obsidian_open_view_picker' "$COMMAND_MODE"
grep -q 'regenerate-views|regen-views|rebuild-views)' "$COMMAND_MODE"
grep -q 'mq_obsidian_regenerate_views' "$COMMAND_MODE"
grep -q 'run_agent_command obsidian-promote' "$COMMAND_MODE"
grep -q 'obsidian-promote)' "$AGENT_MENU"
grep -q '_run_agent obsidian promote' "$AGENT_MENU"
grep -q 'Commands: status, inbox, views, regenerate-views, promote' "$COMMAND_MODE"

echo "[4/5] docs expose direct routes and boundary"
grep -q 'mqlaunch obsidian status' "$README"
grep -q 'mqlaunch obsidian inbox' "$COMMANDS"
grep -q 'mqlaunch obsidian views' "$COMMANDS"
grep -q 'mqlaunch obsidian regenerate-views' "$COMMANDS"
grep -q 'mqlaunch obsidian promote --dry-run' "$COMMANDS"
grep -q 'do not score, promote, reject, or' "$COMMANDS"
grep -q 'mq-agent obsidian promote' "$COMMANDS"

echo "[5/5] roadmap marks the status alias step done"
grep -q '| Done | Add `mqlaunch obsidian status` or documented alias for current menu/status |' "$ROADMAP"
grep -q '| Done | Release gate detects schema drift before release |' "$ROADMAP"
grep -q 'check_mqobsidian_manifest_contract' "$RELEASE_CHECK"

echo "OK: mqlaunch obsidian command route smoke test passed"
