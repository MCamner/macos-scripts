#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
ROOT="$PROJECT_ROOT/tools/scripts"

echo "== Running mqlaunch legacy/bridge checks =="
"$ROOT/test-mqlaunch.sh"

echo
echo "== Running mqlaunch v1 checks =="
bash "$ROOT/test-mqlaunch-v1.sh"

echo
echo "== Running shell lint checks =="
bash "$ROOT/lint.sh"

echo
echo "[PASS] All selftest checks passed."
