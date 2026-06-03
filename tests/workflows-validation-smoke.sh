#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/automation/workflows/validate.sh"
MENU="$ROOT/terminal/menus/mq-workflows-menu.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
CMD="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"
README="$ROOT/README.md"
RELEASE_CHECK="$ROOT/terminal/release/mq-release-check.sh"

echo "SMOKE: workflow validation command surface"

echo "[1/9] validator exists and is executable"
test -x "$VALIDATOR"

echo "[2/9] syntax checks"
bash -n "$VALIDATOR"
bash -n "$MENU"
zsh -n "$LAUNCHER"
bash -n "$CMD"
bash -n "$RELEASE_CHECK"

echo "[3/9] menu exposes validation"
grep -q "Validate workflows" "$MENU"
grep -q "run_workflows_validation" "$MENU"

echo "[4/9] menu supports direct validate command"
grep -q "validate|health" "$MENU"

echo "[5/9] launcher dispatches workflow validate"
grep -q "validate|health) run_workflows_validation" "$LAUNCHER"

echo "[6/9] docs mention workflow validation"
grep -q "mqlaunch workflows validate" "$DOC"
grep -q "mqlaunch workflows validate" "$README"

echo "[7/9] validator checks docs and routing"
grep -q "COMMAND SURFACE" "$VALIDATOR"
grep -q "DOCUMENTATION" "$VALIDATOR"

echo "[8/9] release-check runs workflow validation"
grep -q "WORKFLOW VALIDATION" "$RELEASE_CHECK"
grep -q "automation/workflows/validate.sh" "$RELEASE_CHECK"

echo "[9/9] validator runs"
MACOS_SCRIPTS_HOME="$ROOT" "$VALIDATOR" >/tmp/mq-workflows-validate.out
grep -q "Status: workflow validation passed" /tmp/mq-workflows-validate.out

echo "OK: workflow validation smoke test passed"
