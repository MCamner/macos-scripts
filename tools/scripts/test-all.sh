#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
ROOT="$PROJECT_ROOT/tools/scripts"

: "${PYTHONPYCACHEPREFIX:=${TMPDIR:-/tmp}/macos-scripts-pycache}"
export PYTHONPYCACHEPREFIX
mkdir -p "$PYTHONPYCACHEPREFIX"

echo "== Running mqlaunch legacy/bridge checks =="
"$ROOT/test-mqlaunch.sh"

echo
echo "== Running mqlaunch headless checks =="
"$PROJECT_ROOT/tests/headless-smoke.sh"
"$PROJECT_ROOT/tests/git-status-contract-smoke.sh"
"$PROJECT_ROOT/tests/runtime-authority-freeze-smoke.sh"
"$PROJECT_ROOT/tests/mq-stack-contract-smoke.sh"
"$PROJECT_ROOT/tests/gitmerge-safe-smoke.sh"
"$PROJECT_ROOT/tests/dashboard-header-cache-smoke.sh"
"$PROJECT_ROOT/tests/command-docs-smoke.sh"

echo
echo "== Running HAL menu checks =="
"$PROJECT_ROOT/tests/hal-menu-smoke.sh"
"$PROJECT_ROOT/tests/hal-menu-layout-smoke.sh"
"$PROJECT_ROOT/tests/hal-command-surface-smoke.sh"
"$PROJECT_ROOT/tests/hal-format-smoke.sh"
"$PROJECT_ROOT/tests/hal-gallery-smoke.sh"
"$PROJECT_ROOT/tests/hal-pages-smoke.sh"
"$PROJECT_ROOT/tests/hal-screenshot-smoke.sh"
"$PROJECT_ROOT/tests/pages-index-smoke.sh"
"$PROJECT_ROOT/tests/workflows-validation-smoke.sh"
"$PROJECT_ROOT/tests/document-functions-quality-smoke.sh"

echo
echo "== Running mqlaunch v1 checks =="
bash "$ROOT/test-mqlaunch-v1.sh"

echo
echo "== Running shell lint checks =="
bash "$ROOT/lint.sh"

echo
echo "[PASS] All selftest checks passed."
