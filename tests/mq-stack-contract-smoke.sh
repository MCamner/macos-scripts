#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

README="$ROOT/README.md"
AGENTS="$ROOT/AGENTS.md"
CONTRACT="$ROOT/.mq/context/repo-contract.json"
POINTER="$ROOT/.mq/repo-contract.json"
BOUNDARY="$ROOT/docs/architecture/MQ_BOUNDARY.md"
COMMAND_SURFACE="$ROOT/docs/architecture/COMMAND_SURFACE.md"
READ_ONLY_PATTERN="$ROOT/docs/patterns/read-only-consumer-pattern.md"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
REC_RESOLVE="$ROOT/mqlaunch/lib/recommendations/resolve.sh"
REC_MENU="$ROOT/terminal/menus/recommendations-menu.sh"
REC_COMMANDS=("$ROOT"/mqlaunch/commands/recommendations/*.sh)

echo "SMOKE: MQ stack contract"

echo "[1/10] required public contract files exist"
test -f "$CONTRACT"
test -f "$BOUNDARY"
test -f "$COMMAND_SURFACE"
test -f "$READ_ONLY_PATTERN"

echo "[2/10] contract declares thin terminal-entrypoint role"
grep -q '"schema": "mq-stack-repo-contract.v1"' "$CONTRACT"
grep -q '"role": "human-terminal-entrypoint"' "$CONTRACT"
grep -q '"mq-agent"' "$CONTRACT"
grep -q '"mq-mcp"' "$CONTRACT"
grep -q '"mqobsidian"' "$CONTRACT"
grep -q '"implement review cognition"' "$CONTRACT"
grep -q '"embed private machine paths in public docs"' "$CONTRACT"

# The pointer file, not the canonical contract, carries the version the rest of
# the stack reads. Left ungated it drifts from VERSION and surfaces late as a
# DRIFT verdict in mq-agent's stack gate — another repo's CI failing for this
# repo's mistake. mq-agent#135 and mq-hal#15 closed the same gap.
echo "[3/10] pointer contract version matches VERSION"
test -f "$POINTER"
POINTER_VER="$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['version'])" "$POINTER")"
REPO_VER="$(tr -d '[:space:]' < "$ROOT/VERSION")"
if [[ "$POINTER_VER" != "$REPO_VER" ]]; then
  echo ".mq/repo-contract.json version '$POINTER_VER' != VERSION '$REPO_VER'" >&2
  exit 1
fi

# Asserted against the contract doc, not ROADMAP.md. The two prohibitions below
# were previously matched as roadmap prose, which is the failure mode that took
# out three other tests when the roadmap was rewritten. MQ_BOUNDARY.md states the
# same two under 'Must not own', and that document exists to be binding.
echo "[4/10] README and the boundary contract state the MQ delegation boundary"
grep -Eq 'mqlaunch shows menu.*mq-agent orchestrates.*mq-mcp executes' "$README"
grep -Eq 'mqlaunch shows menu.*mq-agent orchestrates.*mq-mcp executes' "$BOUNDARY"
grep -q 'review cognition' "$BOUNDARY"
grep -q 'semantic memory engines' "$BOUNDARY"

echo "[5/10] AGENTS uses public-safe mqobsidian indirection"
grep -q '\$MQ_OBSIDIAN_DIR' "$AGENTS"
if grep -q '/Users/' "$AGENTS"; then
  echo "AGENTS.md contains a machine-specific /Users path" >&2
  exit 1
fi

echo "[6/10] public docs avoid private machine-specific paths"
if grep -RInE '/Users/[[:alnum:]_.-]+' "$ROOT/README.md" "$ROOT/ROADMAP.md" "$ROOT/docs" "$ROOT/.mq/context" \
  --exclude='mac-terminal-guide.html' \
  --exclude='mac-terminal-guide-SE.html' \
  --exclude='python-guide-SE-v2.2.html' \
  --exclude='powershell-guide-SE.html' \
  --exclude='github-cli-guide-SE-v2.3.html'; then
  echo "Public docs contain a private /Users/<name> path" >&2
  exit 1
fi

echo "[7/10] mqlaunch stack commands delegate through mq-agent bridge"
grep -q 'run_agent_command review' "$COMMAND_MODE"
grep -q 'run_agent_command risk-review' "$COMMAND_MODE"
grep -q 'run_agent_command repo-health' "$COMMAND_MODE"
grep -q 'run_agent_command stack' "$COMMAND_MODE"
grep -q 'run_agent_command mcp-status' "$COMMAND_MODE"

echo "[8/10] mqlaunch command mode does not embed direct mq-mcp cognition"
if grep -qE 'review_file|review_diff|list_architecture_decisions|detect_architecture_drift|validate_orchestration_contract' "$COMMAND_MODE"; then
  echo "mqlaunch command mode embeds mq-mcp cognition/tool names directly" >&2
  exit 1
fi

echo "[9/10] recommendations consumer is read-only"
grep -q 'PRODUCED by mqobsidian' "$REC_RESOLVE"
grep -q 'CONSUMED here' "$REC_RESOLVE"
grep -q 'copy' "$REC_MENU"
if grep -qE '(^|[;&|[:space:]])(eval|bash[[:space:]]+-c|zsh[[:space:]]+-c|exec[[:space:]])' "$REC_MENU" "${REC_COMMANDS[@]}"; then
  echo "recommendations consumer appears to execute templates" >&2
  exit 1
fi

echo "[10/10] shell syntax"
bash -n "$0"

echo "OK: MQ stack contract smoke test passed"
