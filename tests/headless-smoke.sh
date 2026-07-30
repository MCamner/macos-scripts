#!/usr/bin/env bash
set -euo pipefail

ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"

echo "SMOKE: mqlaunch headless mode"

echo "[1/4] launcher exists"
test -x "$LAUNCHER"

# doctor exits 1 when a check warns, and a runner without `eza` or `gitleaks`
# always warns. These steps are about pausing and output shape, not about the
# health of the machine running them, so either verdict is acceptable — but a
# timeout is not, and `timeout` reports that as 124. Checking for 0 or 1 keeps
# the hang detectable where a bare `|| true` would swallow it.
run_doctor() {
  # run_doctor <output-file> [args...]
  local out="$1"; shift
  local status=0
  timeout 15 "$LAUNCHER" doctor "$@" </dev/null >"$out" 2>&1 || status=$?
  case "$status" in
    0|1) ;;
    *)
      echo "FAIL: doctor exited $status (124 means it hung)" >&2
      exit 1
      ;;
  esac
}

echo "[2/4] doctor does not pause without TTY"
run_doctor /tmp/mqlaunch-doctor-headless.out
! grep -q "Press Enter" /tmp/mqlaunch-doctor-headless.out
grep -q "MQ DOCTOR" /tmp/mqlaunch-doctor-headless.out

echo "[3/4] explicit headless flag does not pause"
MQLAUNCH_HEADLESS=1 run_doctor /tmp/mqlaunch-doctor-env-headless.out
! grep -q "Press Enter" /tmp/mqlaunch-doctor-env-headless.out

echo "[4/4] doctor json stays machine-readable"
run_doctor /tmp/mqlaunch-doctor-headless.json --json
grep -q '^{"project":"macos-scripts"' /tmp/mqlaunch-doctor-headless.json
! grep -q "Press Enter" /tmp/mqlaunch-doctor-headless.json

echo "OK: mqlaunch headless smoke test passed"
