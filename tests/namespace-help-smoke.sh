#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

run_help() {
  local namespace="$1"
  local flag="$2"
  local stdout_file="$TMPDIR_TEST/$namespace.${flag#-}.stdout"
  local stderr_file="$TMPDIR_TEST/$namespace.${flag#-}.stderr"
  local status

  set +e
  HOME="$TMPDIR_TEST" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    MACOS_SCRIPTS_HOME="$ROOT" \
    MQ_NO_TUI=1 \
    MQLAUNCH_HEADLESS=1 \
    MQ_AGENT_BIN="$TMPDIR_TEST/missing-mq-agent" \
    MQ_HAL_BIN="$TMPDIR_TEST/missing-mq-hal" \
    "$LAUNCHER" "$namespace" "$flag" >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  [[ $status -eq 0 ]] || {
    echo "$namespace $flag: expected exit 0, got $status" >&2
    return 1
  }
  grep -q "mqlaunch $namespace" "$stdout_file"
  [[ ! -s "$stderr_file" ]] || {
    echo "$namespace $flag: help wrote diagnostics to stderr" >&2
    return 1
  }
}

echo "SMOKE: namespace help contract"
for namespace in agent hal obsidian repos skills srm stack; do
  run_help "$namespace" --help
  run_help "$namespace" -h
done

set +e
HOME="$TMPDIR_TEST" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
  "$LAUNCHER" obsidian --help extra >"$TMPDIR_TEST/invalid.stdout" \
  2>"$TMPDIR_TEST/invalid.stderr"
invalid_status=$?
set -e
[[ $invalid_status -eq 2 ]] || {
  echo "namespace help with extra args: expected exit 2, got $invalid_status" >&2
  exit 1
}
[[ ! -s "$TMPDIR_TEST/invalid.stdout" ]]
grep -q 'ERROR:' "$TMPDIR_TEST/invalid.stderr"

bash -n "$0"
echo "OK: namespace help is local, non-interactive and dependency-light"
