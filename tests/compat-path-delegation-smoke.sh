#!/usr/bin/env bash
# Proves the four command-surface paths delegate to the single runtime authority
# (bin/mqlaunch -> mqlaunch.sh -> mqlaunch-command-mode.sh) instead of acting as
# independent runtimes. Closes the P1 "Single runtime authority" exit gate:
# compatibility paths are tested as delegation paths, not parallel runtimes.
#
#   1. Direct command path — dispatch_cli_command is the only dispatcher;
#      delegated commands preserve the backend exit status (deep behavioural
#      coverage lives in delegated-exit-code-smoke.sh; asserted structurally).
#   2. Menu path — a live menu routes to the owning repo, not inline business
#      logic (deep routing coverage lives in mq-agent-routing-smoke.sh).
#   3. Palette path — run_command_palette forwards the selection to
#      dispatch_cli_command and guards non-interactive use; no independent
#      runtime.
#   4. Legacy shim path — there is no longer one. The v1 bridges forwarded to
#      mqlaunch-v1 as a subprocess; both are gone, and what is asserted now is
#      that the performance route reaches the current menu with no fallback into
#      the frozen tree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
PERF_BRIDGE="$ROOT/terminal/bridges/performance-bridge.sh"
TOOLS_BRIDGE="$ROOT/terminal/bridges/tools-bridge.sh"

echo "SMOKE: compatibility/command-surface paths delegate to the runtime authority"

echo "[1/8] files exist"
test -f "$LAUNCHER"
test -f "$COMMAND_MODE"
test -f "$PERF_BRIDGE"

# --- Path 1: direct command dispatch --------------------------------------
echo "[2/8] direct: dispatch_cli_command is the only dispatcher on this path"
grep -qE '^dispatch_cli_command\(\) \{' "$COMMAND_MODE"

# mqlaunch had a second dispatcher, `run_arg_command`, which answered the
# palette and knew 93 words the registry never modelled. Rerouting the palette
# left it unreachable (#87) and it was deleted (#88). Its absence is what makes
# the registry the whole command surface rather than most of it, so it is
# asserted here rather than left to be quietly reintroduced. Comments may name
# it — the history is worth keeping — so only a definition or a call counts.
second_dispatcher="$(grep -rn 'run_arg_command' --include="*.sh" \
  "$ROOT/terminal" "$ROOT/mqlaunch" "$ROOT/ui" \
  | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
if [[ -n "$second_dispatcher" ]]; then
  echo "FAIL: the second dispatcher is back:" >&2
  printf '%s\n' "$second_dispatcher" >&2
  echo "Commands belong in command-registry.json and dispatch_cli_command." >&2
  exit 1
fi

echo "[3/8] direct: delegated commands preserve the backend exit status"
# The dispatcher forwards to owning tools and returns their status verbatim.
grep -qE 'return \$\?' "$COMMAND_MODE"

# --- Path 2: menu path ----------------------------------------------------
echo "[4/8] menu: a live menu delegates to the owning repo, not inline logic"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
test -f "$AGENT_MENU"
# The agent menu routes review/orchestration to mq-agent; it must not implement
# review cognition locally (forbidden responsibility, RUNTIME_AUTHORITY.md).
grep -q 'mq-agent' "$AGENT_MENU"

# --- Path 3: palette path -------------------------------------------------
echo "[5/8] palette: run_command_palette forwards the selection to the dispatcher"
palette_body="$(awk '/^run_command_palette\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$LAUNCHER")"
test -n "$palette_body"
# Non-main selections are handed back to the authority dispatcher, not run inline.
# Anchored to the call, not the name: the comment above it explains what the
# palette used to route through, and a gate that matched prose would stay green
# after the call was deleted.
grep -q 'dispatch_cli_command \${=selected_cmd}' <<<"$palette_body"
echo "[6/8] palette: guards non-interactive use instead of spawning a runtime"
grep -q 'MQ_NO_TUI' <<<"$palette_body"

# --- Path 4: the legacy shim path is gone ------------------------------------
echo "[7/8] legacy shim: the v1 tools bridge no longer exists"
# It forwarded `tools` to mqlaunch-v1 as a subprocess and preserved its exit
# status, which this test proved behaviourally with a fake v1 launcher. Neither
# of its two functions had a caller anywhere in the tree, so it was deleted
# rather than kept working. Asserted as an absence, because a shim that comes
# back is a second runtime coming back.
if [[ -e "$TOOLS_BRIDGE" ]]; then
  echo "FAIL: the v1 tools bridge is back: $TOOLS_BRIDGE" >&2
  echo "Commands belong in command-registry.json and dispatch_cli_command." >&2
  exit 1
fi

echo "[8/8] performance: the route reaches the current menu, with no v1 fallback"
# performance-bridge.sh used to fall back to the frozen launcher when the
# current menu file was missing. A missing menu is a broken checkout; answering
# it by running a frozen launcher hid that. It now reports and returns 1.
grep -q 'terminal/menus/mq-performance-menu.sh' "$PERF_BRIDGE" || {
  echo "FAIL: the performance bridge no longer loads the current menu" >&2
  exit 1
}
if grep -q 'mqlaunch-v1' "$PERF_BRIDGE"; then
  echo "FAIL: the performance bridge reaches the frozen tree again" >&2
  grep -n 'mqlaunch-v1' "$PERF_BRIDGE" >&2
  exit 1
fi

# And it must actually fail rather than fall through when the menu is absent.
shim_status=0
(
  # Read by the sourced bridge, not by anything in this subshell.
  # shellcheck disable=SC2034
  BASE_DIR="$(mktemp -d)"
  # shellcheck source=/dev/null
  source "$PERF_BRIDGE"
  open_performance_menu
) >/dev/null 2>&1 || shim_status=$?
if [[ "$shim_status" -eq 0 ]]; then
  echo "FAIL: a missing performance menu was not reported" >&2
  exit 1
fi

echo "PASS: three command-surface paths delegate to the single authority, and the fourth is gone"
