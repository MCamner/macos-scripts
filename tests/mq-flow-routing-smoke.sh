#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mqlaunch flow -> mq-agent workflow routing boundary (Phase 7)"

echo "[1/7] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"
test -f "$DOC"

echo "[2/7] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/7] command mode exposes a top-level flow route"
grep -q "flow|/flow)" "$COMMAND_MODE"
grep -q "run_agent_command flow" "$COMMAND_MODE"

echo "[4/7] agent menu has the flow delegate and routes it"
grep -q "_run_agent_flow()" "$AGENT_MENU"
grep -Eq "^\s*flow\)" "$AGENT_MENU"

echo "[5/7] flow forwards to mq-agent workflow (no local orchestration)"
grep -q "_run_agent workflow list" "$AGENT_MENU"
grep -q '_run_agent workflow "\$sub" "\$template"' "$AGENT_MENU"
# Boundary guard: the delegate must not embed planning/execution/policy logic.
! grep -qiE "instantiate|policyprovider|normalize_result|tool-polic" "$AGENT_MENU"

echo "[6/7] flow does not collide with the local workflows menu"
# 'workflows|workflow' must still route to the local automation menu, not flow.
grep -q "workflows|workflow)" "$COMMAND_MODE"
grep -q "run_mqworkflows" "$COMMAND_MODE"

echo "[7/7] docs describe the flow delegation boundary"
grep -q "mqlaunch flow" "$DOC"
grep -q '`mqlaunch flow` only delegates to `mq-agent workflow`' "$DOC"

echo "OK: mqlaunch flow routing boundary smoke test passed"
