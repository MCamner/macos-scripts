#!/usr/bin/env bash
set -euo pipefail

# Terminal width had two implementations: surface_terminal_width in
# ui/terminal-ui/mq-ui.sh (bash, used by 23 files) and gitlaunch_terminal_width
# in terminal/launchers/gitlaunch.sh (zsh, used only by gitlaunch itself).
# Their tput source and 60/112 clamp matched, but their runtime fallback did
# not: mq-ui.sh defaults BOX_INNER to 88 while gitlaunch hardcoded 92. The
# shared helper owns only the common algorithm; each caller still owns its
# fallback policy.
#
# The old gate asserted the strings "width > 112" and "width < 60" appeared in
# gitlaunch.sh. That pins the implementation, not the behaviour: it passes for
# code that never runs and fails for a correct refactor. This asserts what a
# caller can observe instead.
#
# The helper reads `tput cols`, not $COLUMNS — tput consults terminfo and the
# tty, and setting COLUMNS does not move it. The fixtures stub tput.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDTH_LIB="$ROOT/ui/terminal-ui/terminal-width.sh"
UI_LIB="$ROOT/ui/terminal-ui/mq-ui.sh"
GITLAUNCH="$ROOT/terminal/launchers/gitlaunch.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "SMOKE: terminal width"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$WIDTH_LIB" ]] || fail "no shared width helper at ui/terminal-ui/terminal-width.sh"

mkdir -p "$WORK/bin" "$WORK/empty-bin"
cat > "$WORK/bin/tput" <<'STUB'
#!/bin/bash
if [ "$1" = cols ]; then
  [ -n "${FAKE_COLS+x}" ] || exit 1
  printf '%s\n' "$FAKE_COLS"
  exit 0
fi
exit 0
STUB
chmod +x "$WORK/bin/tput"

# Runs the shared algorithm under a given shell with a stubbed tput.
width_under() {
  local shell="$1" fake="$2" fallback="${3:-92}"
  if [ "$fake" = "__unset__" ]; then
    PATH="$WORK/bin:$PATH" "$shell" -c \
      ". '$WIDTH_LIB'; mq_terminal_width '$fallback'"
  else
    PATH="$WORK/bin:$PATH" FAKE_COLS="$fake" "$shell" -c \
      ". '$WIDTH_LIB'; mq_terminal_width '$fallback'"
  fi
}

echo "[1/5] the clamp is observable, not just written down"
# 60 and 112 are the existing contract, carried over deliberately.
for case in "40 60" "59 60" "60 60" "80 80" "100 100" "112 112" "113 112" "200 112"; do
  set -- $case
  got="$(width_under bash "$1")"
  [[ "$got" == "$2" ]] || fail "tput cols=$1 gave width $got, expected $2"
done

echo "[2/5] callers keep their existing fallback policies"
[[ "$(width_under bash "__unset__")" == "92" ]] \
  || fail "gitlaunch fallback did not remain 92"
surface_fallback="$(PATH="$WORK/bin:$PATH" BOX_INNER=88 MQ_THEME_FILE=/dev/null \
  bash -c ". '$UI_LIB'; surface_terminal_width")"
[[ "$surface_fallback" == "88" ]] \
  || fail "surface fallback did not remain BOX_INNER=88: got $surface_fallback"
[[ "$(width_under bash "")" == "92" ]] \
  || fail "empty tput output did not fall back to 92"
[[ "$(width_under bash "abc")" == "92" ]] \
  || fail "non-numeric tput output did not fall back to 92"
[[ "$(width_under bash "-5")" == "92" ]] \
  || fail "negative tput output did not fall back to 92"

echo "[3/5] a genuinely missing tput uses the supplied fallback"
[[ "$(PATH="$WORK/empty-bin" /bin/bash -c \
  ". '$WIDTH_LIB'; mq_terminal_width 92")" == "92" ]] \
  || fail "missing tput did not use fallback 92"
[[ "$(PATH="$WORK/empty-bin" /bin/zsh -c \
  ". '$WIDTH_LIB'; mq_terminal_width 88")" == "88" ]] \
  || fail "missing tput did not use fallback 88 under zsh"

echo "[4/5] both shells agree when source and fallback agree"
command -v zsh >/dev/null 2>&1 || fail "zsh is required to prove the helper is shell-neutral"
for fake in 40 80 200 abc; do
  b="$(width_under bash "$fake")"
  z="$(width_under zsh "$fake")"
  [[ "$b" == "$z" ]] \
    || fail "bash and zsh disagree for tput cols=$fake: bash=$b zsh=$z"
done

echo "[5/5] one algorithm, with explicit policy at both callers"
# backups/ holds dated archive copies of the tree and is excluded everywhere
# else too — CI's syntax sweep skips it, and so does the wiki generator.
definitions="$(grep -rl '^mq_terminal_width()' --include='*.sh' "$ROOT" \
  | grep -v '/tests/' | grep -v '/backups/' | wc -l | tr -d ' ')"
[[ "$definitions" -eq 1 ]] \
  || fail "expected exactly 1 definition of mq_terminal_width, found $definitions"

grep -Fq 'terminal-width.sh' "$UI_LIB" \
  || fail "mq-ui.sh does not source the shared width helper"
grep -Fq 'terminal-width.sh' "$GITLAUNCH" \
  || fail "gitlaunch.sh does not source the shared width helper"
grep -Fq 'mq_terminal_width 92' "$GITLAUNCH" \
  || fail "gitlaunch does not declare fallback 92"
grep -Fq 'mq_terminal_width "${BOX_INNER:-92}"' "$UI_LIB" \
  || fail "surface does not declare its BOX_INNER fallback"

bash -n "$0"
echo "OK: one width helper, same clamp in bash and zsh"
