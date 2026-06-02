#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/automation/workflows/validate.sh"
MENU="$ROOT/terminal/menus/mq-workflows-menu.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
CMD="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"
README="$ROOT/README.md"

echo "SMOKE: workflow validation command surface"

echo "[1/8] validator exists and is executable"
test -x "$VALIDATOR"

echo "[2/8] syntax checks"
bash -n "$VALIDATOR"
bash -n "$MENU"
zsh -n "$LAUNCHER"
bash -n "$CMD"

echo "[3/8] menu exposes validation"
grep -q "Validate workflows" "$MENU"
grep -q "run_workflows_validation" "$MENU"

echo "[4/8] menu supports direct validate command"
grep -q "validate|health" "$MENU"

echo "[5/8] launcher dispatches workflow validate"
grep -q "validate|health) run_workflows_validation" "$LAUNCHER"

echo "[6/8] docs mention workflow validation"
grep -q "mqlaunch workflows validate" "$DOC"
grep -q "mqlaunch workflows validate" "$README"

echo "[7/8] validator checks docs and routing"
grep -q "COMMAND SURFACE" "$VALIDATOR"
grep -q "DOCUMENTATION" "$VALIDATOR"

echo "[8/8] validator runs"
MACOS_SCRIPTS_HOME="$ROOT" "$VALIDATOR" >/tmp/mq-workflows-validate.out
grep -q "Status: workflow validation passed" /tmp/mq-workflows-validate.out

echo "OK: workflow validation smoke test passed"
