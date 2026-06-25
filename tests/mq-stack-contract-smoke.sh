#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

README="$ROOT/README.md"
ROADMAP="$ROOT/ROADMAP.md"
AGENTS="$ROOT/AGENTS.md"
CONTRACT="$ROOT/.mq/context/repo-contract.json"
BOUNDARY="$ROOT/docs/architecture/MQ_BOUNDARY.md"
COMMAND_SURFACE="$ROOT/docs/architecture/COMMAND_SURFACE.md"
READ_ONLY_PATTERN="$ROOT/docs/patterns/read-only-consumer-pattern.md"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
REC_RESOLVE="$ROOT/mqlaunch/lib/recommendations/resolve.sh"
REC_MENU="$ROOT/terminal/menus/recommendations-menu.sh"
REC_COMMANDS=("$ROOT"/mqlaunch/commands/recommendations/*.sh)

echo "SMOKE: MQ stack contract"

echo "[1/9] required public contract files exist"
test -f "$CONTRACT"
test -f "$BOUNDARY"
test -f "$COMMAND_SURFACE"
test -f "$READ_ONLY_PATTERN"

echo "[2/9] contract declares thin terminal-entrypoint role"
grep -q '"schema": "mq-stack-repo-contract.v1"' "$CONTRACT"
grep -q '"role": "human-terminal-entrypoint"' "$CONTRACT"
grep -q '"mq-agent"' "$CONTRACT"
grep -q '"mq-mcp"' "$CONTRACT"
grep -q '"mqobsidian"' "$CONTRACT"
grep -q '"implement review cognition"' "$CONTRACT"
grep -q '"embed private machine paths in public docs"' "$CONTRACT"

echo "[3/9] README and ROADMAP state the MQ delegation boundary"
grep -q 'mqlaunch shows menu.*mq-agent orchestrates.*mq-mcp executes' "$README"
grep -q 'mqlaunch shows menu.*mq-agent orchestrates.*mq-mcp executes' "$ROADMAP"
grep -q 'do not own cognition, review logic, or' "$ROADMAP"

echo "[4/9] AGENTS uses public-safe mqobsidian indirection"
grep -q '\$MQ_OBSIDIAN_DIR' "$AGENTS"
if grep -q '/Users/' "$AGENTS"; then
  echo "AGENTS.md contains a machine-specific /Users path" >&2
  exit 1
fi

echo "[5/9] public docs avoid private machine-specific paths"
if grep -RInE '/Users/[[:alnum:]_.-]+' "$ROOT/README.md" "$ROOT/ROADMAP.md" "$ROOT/docs" "$ROOT/.mq/context" \
  --exclude='mac-terminal-guide.html' \
  --exclude='mac-terminal-guide-SE.html' \
  --exclude='python-guide-SE-v2.2.html' \
  --exclude='powershell-guide-SE.html' \
  --exclude='github-cli-guide-SE-v2.3.html'; then
  echo "Public docs contain a private /Users/<name> path" >&2
  exit 1
fi

echo "[6/9] mqlaunch stack commands delegate through mq-agent bridge"
grep -q 'run_agent_command review' "$COMMAND_MODE"
grep -q 'run_agent_command risk-review' "$COMMAND_MODE"
grep -q 'run_agent_command repo-health' "$COMMAND_MODE"
grep -q 'run_agent_command mcp-status' "$COMMAND_MODE"

echo "[7/9] mqlaunch command mode does not embed direct mq-mcp cognition"
if grep -qE 'review_file|review_diff|list_architecture_decisions|detect_architecture_drift|validate_orchestration_contract' "$COMMAND_MODE"; then
  echo "mqlaunch command mode embeds mq-mcp cognition/tool names directly" >&2
  exit 1
fi

echo "[8/9] recommendations consumer is read-only"
grep -q 'PRODUCED by mqobsidian' "$REC_RESOLVE"
grep -q 'CONSUMED here' "$REC_RESOLVE"
grep -q 'copy' "$REC_MENU"
if grep -qE '(^|[;&|[:space:]])(eval|bash[[:space:]]+-c|zsh[[:space:]]+-c|exec[[:space:]])' "$REC_MENU" "${REC_COMMANDS[@]}"; then
  echo "recommendations consumer appears to execute templates" >&2
  exit 1
fi

echo "[9/9] shell syntax"
bash -n "$0"

echo "OK: MQ stack contract smoke test passed"
