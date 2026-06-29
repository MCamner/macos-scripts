#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mqlaunch memory cochange -> mq-agent memory inbox-cochange routing boundary"

echo "[1/7] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"
test -f "$DOC"

echo "[2/7] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/7] command mode intercepts 'memory cochange' and routes to the agent bridge"
grep -q 'cochange' "$COMMAND_MODE"
grep -q "run_agent_command memory-cochange" "$COMMAND_MODE"

echo "[4/7] agent menu has the cochange delegate and routes it"
grep -q "_run_agent_memory_cochange()" "$AGENT_MENU"
grep -Eq "^\s*memory-cochange\)" "$AGENT_MENU"

echo "[5/7] cochange forwards to mq-agent (no local memory/orchestration logic)"
grep -q "_run_agent memory inbox-cochange" "$AGENT_MENU"
# Boundary guard: the delegate must not embed scoring/writeback/emission logic.
! grep -qiE "memory-score|promotion-event|learn-writeback|emit_observation|derive_observation|build_observation" "$AGENT_MENU"

echo "[5b] interactive menu row exposes co-change intake and routes via the delegate"
grep -q "Co-change intake" "$AGENT_MENU"
grep -q "_agent_menu_cochange" "$AGENT_MENU"
grep -Eq "^\s*20\) _agent_menu_cochange" "$AGENT_MENU"

echo "[6/7] the local SRM surface is preserved for non-cochange memory commands"
grep -q "srm|memory|repo-memory)" "$COMMAND_MODE"
grep -q 'tools/scripts/srm.sh' "$COMMAND_MODE"

echo "[7/7] docs describe the cochange delegation boundary"
grep -q "mqlaunch memory cochange" "$DOC"
grep -q '`mqlaunch memory cochange` only delegates to `mq-agent memory inbox-cochange`' "$DOC"

echo "OK: mqlaunch memory cochange routing boundary smoke test passed"
