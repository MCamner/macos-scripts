#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mqlaunch memory cochange -> mq-agent memory inbox-cochange routing boundary"

echo "[1/7] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"
test -f "$DOC"

echo "[2/7] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/7] command mode intercepts 'memory cochange' and routes to the agent bridge"
# Driven, not grepped. This step used to assert the literal string
# 'run_agent_command memory-cochange' in the source. The dispatcher now resolves
# the verb through a variable — `cochange) _mem_verb="memory-cochange"` followed
# by `run_agent_command "$_mem_verb"` — so no string match can prove the routing,
# and the old grep failed while the routing worked fine.
#
# Same harness as tests/delegated-exit-code-smoke.sh: source command mode, stub
# the bridge, call the dispatcher. Run in a subshell so the sourced definitions
# do not leak into the assertions below.
(
  DELEGATE_DIR="$(mktemp -d)"
  trap 'rm -rf "$DELEGATE_DIR"' EXIT

  export MACOS_SCRIPTS_HOME="$ROOT"
  # shellcheck source=/dev/null
  source "$COMMAND_MODE"

  pause_enter() { return 0; }
  run_agent_command() { printf '%s\n' "$*" >"$DELEGATE_DIR/call"; return 0; }

  dispatch_cli_command memory cochange >/dev/null 2>&1
  grep -qx 'memory-cochange' "$DELEGATE_DIR/call" || {
    echo "expected 'memory cochange' to delegate memory-cochange, got: $(cat "$DELEGATE_DIR/call")" >&2
    exit 1
  }

  # Trailing arguments belong to mq-agent and must arrive untouched: mqlaunch owns
  # no memory logic and so has nothing to interpret them with.
  dispatch_cli_command memory cochange --dry-run --repo mq-agent >/dev/null 2>&1
  grep -qx 'memory-cochange --dry-run --repo mq-agent' "$DELEGATE_DIR/call" || {
    echo "expected arguments forwarded verbatim, got: $(cat "$DELEGATE_DIR/call")" >&2
    exit 1
  }
)

echo "[4/7] agent menu has the cochange delegate and routes it"
grep -q "_run_agent_memory_cochange()" "$AGENT_MENU"
grep -Eq "^\s*memory-cochange\)" "$AGENT_MENU"

echo "[5/7] cochange forwards to mq-agent (no local memory/orchestration logic)"
grep -q "_run_agent memory inbox-cochange" "$AGENT_MENU"
# Boundary guard: the delegate must not embed scoring/writeback/emission logic.
! grep -qiE "memory-score|promotion-event|learn-writeback|emit_observation|derive_observation|build_observation" "$AGENT_MENU"

echo "[5b] interactive menu row exposes co-change intake and routes via the delegate"
# The row used to be option 20 in a flat twenty-one-row menu and is option 1 of
# the Co-change and Memory submenu now. Pinning the number tested the layout;
# what matters is that a menu option reaches the delegate, which is what the
# routing boundary is about.
grep -q "Co-change intake" "$AGENT_MENU"
grep -Eq "^\s*[0-9]+\) _agent_menu_cochange;" "$AGENT_MENU" || {
  echo "FAIL: no agent menu option routes to _agent_menu_cochange" >&2
  exit 1
}

echo "[6/7] the local SRM surface is preserved for non-cochange memory commands"
grep -q "srm|memory|repo-memory)" "$COMMAND_MODE"
grep -q 'tools/scripts/srm.sh' "$COMMAND_MODE"

echo "[7/7] docs describe the cochange delegation boundary"
grep -q "mqlaunch memory cochange" "$DOC"
grep -q '`mqlaunch memory cochange` only delegates to `mq-agent memory inbox-cochange`' "$DOC"

echo "OK: mqlaunch memory cochange routing boundary smoke test passed"
