#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE="$ROOT/terminal/bridges/brain-bridge.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
MQLAUNCH="$ROOT/terminal/launchers/mqlaunch.sh"

echo "SMOKE: brain-bridge subcommands and routing"

echo "[1/6] bridge exists and has valid shell syntax"
test -f "$BRIDGE"
bash -n "$BRIDGE"

echo "[2/6] core subcommands present in bridge"
grep -q '""|dashboard)' "$BRIDGE"
grep -q 'sessions|session)' "$BRIDGE"
grep -q 'decisions|decision)' "$BRIDGE"
grep -q 'reviews|review)' "$BRIDGE"
grep -q 'learn|patterns)' "$BRIDGE"

echo "[3/6] new subcommands present (P4 — verified and systems)"
grep -q 'verified)' "$BRIDGE"
grep -q 'systems|system)' "$BRIDGE"

echo "[4/6] memory subcommand removed (P4 — memory/ avvecklad)"
# memory should NOT appear as a case arm (only in usage comments is OK)
# check no case arm for memory exists
! grep -qE '^\s+memory\)' "$BRIDGE"

echo "[5/6] mqlaunch-command-mode routes verified and systems via brain"
grep -q "verified|systems" "$COMMAND_MODE"

echo "[6/6] mqlaunch.sh routes verified and systems via brain"
grep -q "verified|systems" "$MQLAUNCH"

echo "OK: brain-bridge smoke test passed"
