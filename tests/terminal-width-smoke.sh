#!/usr/bin/env bash
set -euo pipefail

# Terminal width had two implementations: surface_terminal_width in
# ui/terminal-ui/mq-ui.sh (bash, used by 23 files) and gitlaunch_terminal_width
# in terminal/launchers/gitlaunch.sh (zsh, used only by gitlaunch itself). They
# were byte-for-byte identical in behaviour — same tput source, same 60/112
# clamp, same 92 fallback — so the duplication carried no decision, only the
# risk of the two drifting apart.
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

# Marks a failing check.
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$WIDTH_LIB" ]] || fail "no shared width helper at ui/terminal-ui/terminal-width.sh"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/tput" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = cols ]; then
  [ -n "${FAKE_COLS+x}" ] || exit 1
  printf '%s\n' "$FAKE_COLS"
  exit 0
fi
exit 0
STUB
chmod +x "$WORK/bin/tput"

# Runs the helper under a given shell with a stubbed tput.
width_under() {
  local shell="$1" fake="$2"
  if [ "$fake" = "__unset__" ]; then
    PATH="$WORK/bin:$PATH" "$shell" -c \
      ". '$WIDTH_LIB'; surface_terminal_width"
  else
    PATH="$WORK/bin:$PATH" FAKE_COLS="$fake" "$shell" -c \
      ". '$WIDTH_LIB'; surface_terminal_width"
  fi
}

echo "[1/4] the clamp is observable, not just written down"
# 60 and 112 are the existing contract, carried over deliberately.
for case in "40 60" "59 60" "60 60" "80 80" "100 100" "112 112" "113 112" "200 112"; do
  set -- $case
  got="$(width_under bash "$1")"
  [[ "$got" == "$2" ]] || fail "tput cols=$1 gave width $got, expected $2"
done

echo "[2/4] a missing or unusable tput falls back deterministically"
[[ "$(width_under bash "__unset__")" == "92" ]] \
  || fail "tput failure did not fall back to 92: $(width_under bash "__unset__")"
[[ "$(width_under bash "")" == "92" ]] \
  || fail "empty tput output did not fall back to 92"
[[ "$(width_under bash "abc")" == "92" ]] \
  || fail "non-numeric tput output did not fall back to 92"
[[ "$(width_under bash "-5")" == "92" ]] \
  || fail "negative tput output did not fall back to 92"

# The fallback must not depend on BOX_INNER, and so must not depend on whether
# mq-ui.sh has been sourced. It used to: mq-ui.sh's copy read
# "${BOX_INNER:-92}" while defaulting BOX_INNER to 88, so the menus fell back
# to 88 and gitlaunch to 92 — the mismatch the shared helper exists to remove.
box_inner_fallback="$(PATH="$WORK/bin:$PATH" BOX_INNER=40 bash -c \
  ". '$WIDTH_LIB'; surface_terminal_width")"
[[ "$box_inner_fallback" == "92" ]] \
  || fail "BOX_INNER still steers the fallback: got $box_inner_fallback, expected 92"

echo "[3/4] both shells agree, because gitlaunch is zsh and the menus are bash"
command -v zsh >/dev/null 2>&1 || fail "zsh is required to prove the helper is shell-neutral"
for fake in 40 80 200 abc; do
  b="$(width_under bash "$fake")"
  z="$(width_under zsh "$fake")"
  [[ "$b" == "$z" ]] \
    || fail "bash and zsh disagree for tput cols=$fake: bash=$b zsh=$z"
done

echo "[4/4] one definition, and both callers reach it"
# backups/ holds dated archive copies of the tree and is excluded everywhere
# else too — CI's syntax sweep skips it, and so does the wiki generator.
definitions="$(grep -rl '^surface_terminal_width()' --include='*.sh' "$ROOT" \
  | grep -v '/tests/' | grep -v '/backups/' | wc -l | tr -d ' ')"
[[ "$definitions" -eq 1 ]] \
  || fail "expected exactly 1 definition of surface_terminal_width, found $definitions"

grep -Fq 'terminal-width.sh' "$UI_LIB" \
  || fail "mq-ui.sh does not source the shared width helper"
grep -Fq 'terminal-width.sh' "$GITLAUNCH" \
  || fail "gitlaunch.sh does not source the shared width helper"
grep -q 'gitlaunch_terminal_width' "$GITLAUNCH" \
  && fail "gitlaunch.sh still defines its own width helper"

bash -n "$0"
echo "OK: one width helper, same clamp in bash and zsh"
