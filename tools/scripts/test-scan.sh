#!/usr/bin/env bash

echo "MQ TEST HARNESS"
echo "════════════════════════════════════"

echo
echo "[1] Normal run"
echo "------------------------------------"
"$HOME/macos-scripts/tools/scripts/scan.sh"

echo
echo "[2] Simulate HIGH MEMORY"
echo "------------------------------------"
MEM_OVERRIDE=95 "$HOME/macos-scripts/tools/scripts/scan.sh"

echo
echo "[3] Simulate HIGH CPU"
echo "------------------------------------"
CPU_OVERRIDE=999 "$HOME/macos-scripts/tools/scripts/scan.sh"

echo
echo "[4] Check alert log"
echo "------------------------------------"
tail -n 5 "$HOME/.mq/alerts.log" 2>/dev/null || echo "No log yet"

echo
echo "DONE"
