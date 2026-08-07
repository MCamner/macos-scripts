#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"
HELP_MENU="$ROOT/terminal/menus/mq-help-menu.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mqlaunch route thin entrypoint"

# Coordinates dispatch behavior.
dispatch() {
  (
    export MACOS_SCRIPTS_HOME="$ROOT"
    # shellcheck source=/dev/null
    source "$AGENT_MENU" >/dev/null 2>&1
    # shellcheck source=/dev/null
    source "$COMMAND_MODE" >/dev/null 2>&1
# Coordinates run agent behavior.
    _run_agent() {
      printf 'mq-agent'
      printf ' <%s>' "$@"
      printf '\n'
      return "${STUB_EXIT:-0}"
    }
# Pauses until Enter is pressed.
    pause_enter() { :; }
    dispatch_cli_command "$@"
  )
}

echo "[1/6] arguments reach mq-agent route unchanged"
got="$(dispatch route inspect "task with spaces" --json --reason 'a*b')"
want='mq-agent <route> <inspect> <task with spaces> <--json> <--reason> <a*b>'
[[ "$got" == "$want" ]] || {
  printf 'FAIL: route arguments changed\n  want: %s\n  got : %s\n' "$want" "$got" >&2
  exit 1
}

echo "[2/6] bare route remains a lossless empty-argument delegation"
[[ "$(dispatch route)" == 'mq-agent <route>' ]]

echo "[3/6] exit codes 0, 1, 2 and 127 are preserved"
for code in 0 1 2 127; do
  got=0
  STUB_EXIT="$code" dispatch route status --json >/dev/null || got=$?
  [[ "$got" == "$code" ]] || {
    printf 'FAIL: mq-agent exited %s but mqlaunch returned %s\n' "$code" "$got" >&2
    exit 1
  }
done

echo "[4/6] registry classifies route as a mq-agent thin entrypoint"
python3 - "$REGISTRY" <<'PY'
import json
import sys

commands = json.load(open(sys.argv[1], encoding="utf-8"))["commands"]
route = next((item for item in commands if item["name"] == "route"), None)
if route is None:
    raise SystemExit("route is missing from the command registry")
expected = {
    "owner": "mq-agent",
    "delegates_to": "mq-agent route",
    "safety": "delegating",
}
for key, value in expected.items():
    if route.get(key) != value:
        raise SystemExit(f"route {key}: expected {value!r}, got {route.get(key)!r}")
if "local_role" in route:
    raise SystemExit("route must not claim a local_role owned by macos-scripts")
PY

echo "[5/6] generated help identifies mq-agent as owner"
grep -q '^AGENT  (owner: mq-agent)$' "$HELP_MENU"
grep -q '^  mqlaunch route .*model routing through mq-agent' "$HELP_MENU"

echo "[6/6] docs state delegation and forbid local fallback logic"
grep -q '`mqlaunch route` delegates every argument to `mq-agent route` unchanged' "$DOC"
grep -q 'contains no model call' "$DOC"
grep -q 'fallback, confidence threshold, or routing policy' "$DOC"

echo "OK: mqlaunch route thin entrypoint smoke test passed"
