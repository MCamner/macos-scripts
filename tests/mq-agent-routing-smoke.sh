#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

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
grep -q "run_agent_command stack" "$COMMAND_MODE"
grep -q "run_agent_command mcp-status" "$COMMAND_MODE"

# This step used to also assert two strings in ROADMAP.md: 'Boundary test' and a
# verbatim '| Done | ... |' table row. The roadmap was rewritten from tables to
# prose sections with 'Status: Done', so neither could ever match again — and
# neither proved anything about the boundary in the first place. A roadmap is a
# plan, and rewriting it is its job. The contract lives in docs/COMMANDS.md and
# in the routes asserted above.
echo "[7/7] docs describe delegation boundary"
grep -q "review current diff via mq-agent -> mq-mcp" "$DOC"
grep -q "mqlaunch stack status" "$DOC"
grep -q 'mq-agent stack status' "$DOC"
grep -q '`mqlaunch` only delegates' "$DOC"

echo "OK: mq-agent review routing boundary smoke test passed"
