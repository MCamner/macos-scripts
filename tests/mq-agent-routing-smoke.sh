#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"
ROADMAP="$ROOT/ROADMAP.md"

echo "SMOKE: mq-agent review routing boundary"

echo "[1/7] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"

echo "[2/7] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/7] review delegates to mq-agent review command group"
grep -q "_run_agent review diff" "$AGENT_MENU"
grep -q "_run_agent review file" "$AGENT_MENU"
grep -q "_run_agent review repo" "$AGENT_MENU"

echo "[4/7] risk review uses mq-agent risk flag"
grep -q "_run_agent review diff --risk" "$AGENT_MENU"

echo "[5/7] repo health targets macos-scripts by default"
grep -q 'repo_path=\$repo_path' "$AGENT_MENU"
grep -q 'MQ_REPO_HEALTH_PATH:-\$BASE_DIR' "$AGENT_MENU"

echo "[6/7] mqlaunch command mode exposes top-level routes"
grep -q "run_agent_command review" "$COMMAND_MODE"
grep -q "run_agent_command architecture" "$COMMAND_MODE"
grep -q "run_agent_command risk-review" "$COMMAND_MODE"
grep -q "run_agent_command repo-health" "$COMMAND_MODE"
grep -q "run_agent_command mcp-status" "$COMMAND_MODE"

echo "[7/7] docs and roadmap describe delegation boundary"
grep -q "review current diff via mq-agent -> mq-mcp" "$DOC"
grep -q '`mqlaunch` only delegates' "$DOC"
grep -q "Boundary test" "$ROADMAP"

echo "OK: mq-agent review routing boundary smoke test passed"
