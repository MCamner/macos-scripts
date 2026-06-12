#!/usr/bin/env bash
set -euo pipefail

ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"

echo "SMOKE: mqlaunch headless mode"

echo "[1/4] launcher exists"
test -x "$LAUNCHER"

echo "[2/4] doctor does not pause without TTY"
timeout 15 "$LAUNCHER" doctor </dev/null >/tmp/mqlaunch-doctor-headless.out 2>&1
! grep -q "Press Enter" /tmp/mqlaunch-doctor-headless.out
grep -q "MQ DOCTOR" /tmp/mqlaunch-doctor-headless.out

echo "[3/4] explicit headless flag does not pause"
MQLAUNCH_HEADLESS=1 timeout 15 "$LAUNCHER" doctor </dev/null >/tmp/mqlaunch-doctor-env-headless.out 2>&1
! grep -q "Press Enter" /tmp/mqlaunch-doctor-env-headless.out

echo "[4/4] doctor json stays machine-readable"
timeout 15 "$LAUNCHER" doctor --json </dev/null >/tmp/mqlaunch-doctor-headless.json 2>&1
grep -q '^{"project":"macos-scripts"' /tmp/mqlaunch-doctor-headless.json
! grep -q "Press Enter" /tmp/mqlaunch-doctor-headless.json

echo "OK: mqlaunch headless smoke test passed"
