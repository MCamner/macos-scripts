#!/usr/bin/env bash
set -euo pipefail

# ui/terminal-ui/mq-ui.sh is sourced by the zsh launcher, and zsh reserves
# names bash treats as ordinary. The frame-tint code shipped with two of them:
#
#     local path      — in zsh, `path` is the array tied to PATH. Declaring it
#                       local emptied PATH for the rest of the call, and the
#                       `cksum` and `cut` inside surface_pulse_cache_path went
#                       "command not found" on a machine that had both.
#     status="..."    — `status` is zsh's read-only alias of `$?`; assigning
#                       aborts the function on the spot.
#
# Every existing check ran the library under bash, where both are harmless, so
# both passed CI and failed the first time mqlaunch itself drew a menu. This
# test sources the library under zsh — `set -u`, the way mqlaunch.sh does — and
# calls the surface helpers for real, with a Pulse document in place so the
# code path that reads it is the one that runs. It checks behaviour a caller can
# observe: the verdict comes back, PATH is intact afterwards, the frame takes
# the warning colour, and nothing reaches stderr. A static gate for `status=`
# already exists (tests/zsh-status-assignment-smoke.sh); this one is the
# runtime proof for everything a static list cannot name.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "SMOKE: ui library under zsh"

# Marks a failing check.
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

command -v zsh >/dev/null 2>&1 || fail "zsh is required: it is the shell that sources this library"
[[ -f "$UI" ]] || fail "no ui library at ui/terminal-ui/mq-ui.sh"

PULSE="$WORK/pulse.json"
printf '{"schema": "mq.pulse.v1", "status": "WARN", "sections": {"system": [{"status": "FAIL"}]}}\n' > "$PULSE"

# Runs a snippet under zsh with the library sourced, colour forced on, and the
# Pulse document pointed at the fixture. stdout and stderr come back separately
# so a check can insist on silence.
run_zsh() { # SNIPPET
  local snippet="$1"
  MACOS_SCRIPTS_HOME="$ROOT" BASE_DIR="$ROOT" MQ_PULSE_CACHE="$PULSE" \
  MQ_DASHBOARD_FORCE_COLOR=1 NO_COLOR='' \
    zsh -c "set -u; . '$UI'; $snippet" 2>"$WORK/stderr" || true
}

echo "[1/6] the library sources under zsh without a word on stderr"
run_zsh ':' >/dev/null
[[ ! -s "$WORK/stderr" ]] || fail "sourcing wrote to stderr: $(cat "$WORK/stderr")"
echo "  ok: silent"

echo "[2/6] surface_health_state reads the verdict"
got="$(run_zsh 'surface_health_state')"
[[ "$got" == "WARN" ]] || fail "expected WARN, got '$got' (stderr: $(cat "$WORK/stderr"))"
[[ ! -s "$WORK/stderr" ]] || fail "surface_health_state wrote to stderr: $(cat "$WORK/stderr")"
echo "  ok: WARN"

echo "[3/6] PATH survives the call"
# `local path` inside any helper would have emptied PATH for the rest of that
# call; this asserts both from inside the chain (cksum found where
# surface_pulse_cache_path needs it) and after it (PATH unchanged).
# shellcheck disable=SC2016  # the expansions are zsh's, inside the snippet
got="$(run_zsh 'before=$PATH; surface_health_state >/dev/null; [[ $PATH == $before ]] && printf same; command -v cksum >/dev/null && printf ,cksum')"
[[ "$got" == "same,cksum" ]] || fail "PATH was disturbed by the surface helpers: '$got' (stderr: $(cat "$WORK/stderr"))"
echo "  ok: PATH intact and cksum reachable"

echo "[4/6] the frame takes the warning colour"
got="$(run_zsh 'surface_panel_color | od -An -c | tr -d " \n"')"
case "$got" in
  *'033[0;33m'*) ;;
  *) fail "panel colour is not the warning colour on WARN: '$got'" ;;
esac
echo "  ok: warning colour"

echo "[5/6] without a document the frame keeps the theme colour"
# run_zsh sets MQ_PULSE_CACHE itself, so the override goes inside the snippet.
got="$(run_zsh 'MQ_PULSE_CACHE=/nonexistent/pulse.json surface_panel_color | od -An -c | tr -d " \n"')"
case "$got" in
  *'[38;2;255;255;255m'*) ;;
  *) fail "panel colour without a document is not the default white: '$got'" ;;
esac
echo "  ok: theme colour"

echo "[6/6] no helper in the library declares a zsh-reserved name"
# Static, for the names whose damage is silent. `status` has its own gate; the
# rest are the parameters zsh ties to something — PATH and its siblings, the
# positional array, the option and signal tables.
if grep -nE '^[[:space:]]*(local|typeset|declare)[[:space:]].*\b(path|cdpath|fpath|manpath|argv|options|signals|pipestatus|histchars)\b' "$UI" \
  | grep -vE '^[0-9]+:[[:space:]]*#'; then
  fail "mq-ui.sh declares a name zsh reserves; pick another"
fi
echo "  ok: no reserved names declared"

echo "OK: ui library behaves under zsh"
