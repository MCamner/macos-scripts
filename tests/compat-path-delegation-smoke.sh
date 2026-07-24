#!/usr/bin/env bash
# Proves the four command-surface paths delegate to the single runtime authority
# (bin/mqlaunch -> mqlaunch.sh -> mqlaunch-command-mode.sh) instead of acting as
# independent runtimes. Closes the P1 "Single runtime authority" exit gate:
# compatibility paths are tested as delegation paths, not parallel runtimes.
#
#   1. Direct command path — run_arg_command dispatches; delegated commands
#      preserve the backend exit status (deep behavioural coverage lives in
#      delegated-exit-code-smoke.sh; asserted structurally here).
#   2. Menu path — a live menu routes to the owning repo, not inline business
#      logic (deep routing coverage lives in mq-agent-routing-smoke.sh).
#   3. Palette path — run_command_palette forwards the selection to
#      run_arg_command and guards non-interactive use; no independent runtime.
#   4. Legacy shim path — the v1 bridges forward to mqlaunch-v1 as a subprocess
#      and preserve its exit status, adding no new command behaviour.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
TOOLS_BRIDGE="$ROOT/terminal/bridges/tools-bridge.sh"
PERF_BRIDGE="$ROOT/terminal/bridges/performance-bridge.sh"

echo "SMOKE: compatibility/command-surface paths delegate to the runtime authority"

echo "[1/8] files exist"
test -f "$LAUNCHER"
test -f "$COMMAND_MODE"
test -f "$TOOLS_BRIDGE"
test -f "$PERF_BRIDGE"

# --- Path 1: direct command dispatch --------------------------------------
echo "[2/8] direct: the single arg dispatcher run_arg_command is defined"
grep -qE '^run_arg_command\(\) \{' "$LAUNCHER"

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
grep -q 'run_arg_command' <<<"$palette_body"
echo "[6/8] palette: guards non-interactive use instead of spawning a runtime"
grep -q 'MQ_NO_TUI' <<<"$palette_body"

# --- Path 4: legacy shim path (behavioural) -------------------------------
echo "[7/8] legacy shim: v1 bridge forwards to mqlaunch-v1 and preserves exit status"
SHIM_TMP="$(mktemp -d)"
trap 'rm -rf "$SHIM_TMP"' EXIT
mkdir -p "$SHIM_TMP/terminal/mqlaunch-v1"
cat >"$SHIM_TMP/terminal/mqlaunch-v1/mqlaunch.sh" <<'FAKE'
#!/usr/bin/env bash
# Fake v1 launcher: echoes the forwarded subcommand, exits with a marker code.
printf 'v1 got: %s\n' "$1"
exit 42
FAKE
chmod +x "$SHIM_TMP/terminal/mqlaunch-v1/mqlaunch.sh"

# shellcheck source=/dev/null
source "$TOOLS_BRIDGE"
# BASE_DIR is read by the sourced bridge functions, not directly here.
# shellcheck disable=SC2034
BASE_DIR="$SHIM_TMP"
rc=0
out="$(run_v1_tools_command tools 2>&1)" || rc=$?
test "$rc" -eq 42 || { echo "FAIL: shim did not preserve exit status (got $rc)"; exit 1; }
grep -q 'v1 got: tools' <<<"$out" || { echo "FAIL: shim did not forward the subcommand"; exit 1; }

echo "[8/8] legacy shim: bridges only forward a subcommand, add no new command logic"
# Each bridge's live path is exactly a forward of "$subcmd" to the v1 launcher.
# The pattern is a literal (single-quoted on purpose); it must not expand here.
for bridge in "$TOOLS_BRIDGE" "$PERF_BRIDGE"; do
  # shellcheck disable=SC2016
  grep -q '"\$v1_launcher" "\$subcmd"' "$bridge"
done

echo "PASS: all four command-surface paths delegate to the single authority"
