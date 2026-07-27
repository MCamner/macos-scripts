#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Resolved before the runs, which deliberately restrict PATH: `timeout` lives in
# /usr/bin on Linux but comes from coreutils on macOS.
TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
[[ -n "$TIMEOUT_BIN" ]] || {
  echo "timeout (or gtimeout) is required to prove help does not hang" >&2
  exit 1
}

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
    "$TIMEOUT_BIN" 20 "$LAUNCHER" "$namespace" "$flag" \
    </dev/null >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  # 124 is timeout's own status. Help that opens an interactive menu loops on
  # EOF instead of returning, so this is the check that catches a hang rather
  # than waiting for one.
  [[ $status -ne 124 ]] || {
    echo "$namespace $flag: did not terminate without a terminal" >&2
    return 1
  }

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
# One help route for every namespace mqlaunch routes itself. `system`, `release`
# and `dev` used to reach their own `*` fallback and exit 2; `git` interpreted
# `help` as a repo path and opened the menu, which never returned.
for namespace in agent dev git hal obsidian release repos skills srm stack system; do
  run_help "$namespace" --help
  run_help "$namespace" -h
  run_help "$namespace" help
done

HOME="$TMPDIR_TEST" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 MQLAUNCH_HEADLESS=1 \
  "$LAUNCHER" obsidian --help >"$TMPDIR_TEST/obsidian-help.stdout"
grep -q 'regenerate-views' "$TMPDIR_TEST/obsidian-help.stdout"

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

echo "SMOKE: unknown subcommand contract"
# Where mqlaunch owns the subcommand set, an unknown word is a usage error:
# a diagnostic on stderr, help on stdout, exit 2, and no menu. obsidian used to
# print a hand-written usage string and exit 1; system, release, dev and help
# exited 2 but said nothing on stderr.
#
# Namespaces are absent from this list on purpose. `git` takes an optional repo
# path, `srm` treats an unrecognised word as the question, and `repos` and
# `workspace` let their delegate own the command set — none of them has a closed
# set for mqlaunch to police, and duplicating one here is the drift the registry
# exists to prevent.
for namespace in obsidian system release dev help; do
  set +e
  HOME="$TMPDIR_TEST" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 MQLAUNCH_HEADLESS=1 \
    "$TIMEOUT_BIN" 20 "$LAUNCHER" "$namespace" no-such-subcommand \
    </dev/null >"$TMPDIR_TEST/unknown.stdout" 2>"$TMPDIR_TEST/unknown.stderr"
  unknown_status=$?
  set -e
  [[ $unknown_status -eq 2 ]] || {
    echo "$namespace unknown subcommand: expected exit 2, got $unknown_status" >&2
    exit 1
  }
  grep -q "ERROR: unknown mqlaunch $namespace command" "$TMPDIR_TEST/unknown.stderr" || {
    echo "$namespace unknown subcommand: no diagnostic on stderr" >&2
    exit 1
  }
  grep -q "mqlaunch $namespace" "$TMPDIR_TEST/unknown.stdout" || {
    echo "$namespace unknown subcommand: no usage on stdout" >&2
    exit 1
  }
done

bash -n "$0"
echo "OK: namespace help is local, non-interactive and dependency-light"
