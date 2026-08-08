#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
README="$ROOT/README.md"
COMMANDS="$ROOT/docs/COMMANDS.md"
RELEASE_CHECK="$ROOT/terminal/release/mq-release-check.sh"

echo "SMOKE: mqlaunch obsidian direct command routes"

echo "[1/5] files exist"
test -f "$COMMAND_MODE"
test -f "$AGENT_MENU"
test -f "$README"
test -f "$COMMANDS"
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
grep -q 'Commands: status, inbox, views, regenerate-views, promote, learn-writeback' "$COMMAND_MODE"

echo "[3b/5] learn-writeback routes to mq-agent, never to mqobsidian directly"
grep -q 'learn-writeback|writeback)' "$COMMAND_MODE"
grep -q 'run_agent_command obsidian-learn-writeback' "$COMMAND_MODE"
grep -q 'obsidian-learn-writeback)' "$AGENT_MENU"
grep -q '_run_agent memory learn-writeback' "$AGENT_MENU"
# The whole point of the route: mqlaunch owns no memory logic, so nothing here
# may reach mqobsidian's memory_cli.py.
! grep -q 'memory_cli' "$COMMAND_MODE"
! grep -q 'memory_cli' "$AGENT_MENU"

echo "[4/5] docs expose direct routes and boundary"
grep -q 'mqlaunch obsidian status' "$README"
grep -q 'mqlaunch obsidian inbox' "$COMMANDS"
grep -q 'mqlaunch obsidian views' "$COMMANDS"
grep -q 'mqlaunch obsidian regenerate-views' "$COMMANDS"
grep -q 'mqlaunch obsidian promote --dry-run' "$COMMANDS"
grep -q 'mqlaunch obsidian learn-writeback' "$COMMANDS"
grep -q 'do not score, promote, reject, or' "$COMMANDS"
grep -q 'mq-agent obsidian promote' "$COMMANDS"

# This step used to assert two verbatim '| Done | ... |' rows in ROADMAP.md — one
# for the status alias, one for release-time schema drift. ROADMAP.md was
# rewritten from tables to prose ('Status: Done'), so neither can match again. A
# roadmap row is a claim that something shipped; the gate is the thing that
# shipped. Assert the gate. The status alias itself is already covered by step 3
# ('status|doctor)') and step 4 ('mqlaunch obsidian status' in the README).
echo "[5/5] release gate enforces the mqobsidian manifest contract"
grep -q 'check_mqobsidian_manifest_contract()' "$RELEASE_CHECK"
# Defined is not enough — an uncalled check is not a gate.
grep -qE '^check_mqobsidian_manifest_contract \|\| exit 1$' "$RELEASE_CHECK"

echo "OK: mqlaunch obsidian command route smoke test passed"
