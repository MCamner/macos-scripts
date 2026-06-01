#!/usr/bin/env bash
# Smoke test for mqlaunch installation.
# Verifies that a working setup is in place.
# Exit 0 = all checks pass, exit 1 = one or more failed.

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
PASS=0
FAIL=0

# Marks a passing check.
pass() { printf "[PASS] %s\n" "$1"; PASS=$((PASS+1)); }
# Marks a failing check.
fail() { printf "[FAIL] %s\n" "$1"; FAIL=$((FAIL+1)); }

printf "install smoke test — %s\n\n" "$BASE_DIR"

# Base dir
[[ -d "$BASE_DIR" ]] \
  && pass "base dir exists" \
  || fail "base dir missing: $BASE_DIR"

# VERSION
if [[ -f "$BASE_DIR/VERSION" ]]; then
  pass "VERSION: $(cat "$BASE_DIR/VERSION")"
else
  fail "VERSION file missing"
fi

# Core launcher
[[ -f "$BASE_DIR/terminal/launchers/mqlaunch.sh" ]] \
  && pass "mqlaunch.sh exists" \
  || fail "mqlaunch.sh missing"

# mqlaunch in PATH
command -v mqlaunch >/dev/null 2>&1 \
  && pass "mqlaunch in PATH ($(command -v mqlaunch))" \
  || fail "mqlaunch not in PATH"

# Core scripts executable
for script in \
  tools/scripts/doctor.sh \
  tools/scripts/system-check.sh \
  tools/scripts/mission-control.sh \
  tools/scripts/install-smoke.sh
do
  [[ -x "$BASE_DIR/$script" ]] \
    && pass "$script executable" \
    || fail "$script not executable"
done

# Core menus present
for menu in \
  terminal/menus/mq-main-menu.sh \
  terminal/menus/mq-dev-menu.sh \
  terminal/menus/mq-tools-menu.sh \
  terminal/menus/mq-help-menu.sh
do
  [[ -f "$BASE_DIR/$menu" ]] \
    && pass "$menu present" \
    || fail "$menu missing"
done

# UI library
[[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] \
  && pass "mq-ui.sh present" \
  || fail "mq-ui.sh missing"

# Git repo
git -C "$BASE_DIR" rev-parse --git-dir >/dev/null 2>&1 \
  && pass "git repo OK" \
  || fail "not a git repo: $BASE_DIR"

printf "\n%d passed, %d failed\n" "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
