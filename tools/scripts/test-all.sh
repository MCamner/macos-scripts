#!/usr/bin/env zsh
set -euo pipefail

ROOT="$HOME/macos-scripts/tools/scripts"

echo "== Running mqlaunch legacy/bridge checks =="
"$ROOT/test-mqlaunch.sh"

echo
echo "== Running mqlaunch v1 checks =="
bash "$ROOT/test-mqlaunch-v1.sh"

echo
echo "[PASS] All smoke checks passed."
