#!/usr/bin/env bash
set -euo pipefail

# Exercises the recovery functions from the gitlaunch implementation that
# mqlaunch option 3 actually starts. The older restore smoke covers the
# separate mq-git-menu implementation and did not catch this path.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITLAUNCH="$ROOT/terminal/launchers/gitlaunch.sh"
GIT_MENUS="$ROOT/mqlaunch/lib/git-menus.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/repo"
git -C "$TMP/repo" config user.email test@example.invalid
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" checkout -q -B main
printf 'initial\n' > "$TMP/repo/file.txt"
git -C "$TMP/repo" add file.txt
git -C "$TMP/repo" commit -q -m initial
git -C "$TMP/repo" push -q -u origin main

prepare_pr_branch() {
  git -C "$TMP/repo" switch -q main
  printf 'change-%s\n' "$1" > "$TMP/repo/file.txt"
  git -C "$TMP/repo" commit -q -am "change $1"
  git -C "$TMP/repo" switch -q -C "mq/test-$1"
}

assert_restored() {
  [[ "$(git -C "$TMP/repo" branch --show-current)" == main ]]
  [[ "$(git -C "$TMP/repo" rev-parse main)" == "$(git -C "$TMP/repo" rev-parse origin/main)" ]]
  [[ -z "$(git -C "$TMP/repo" status --porcelain)" ]]
}

echo "[1/4] gitlaunch can be sourced without entering its menu loop"
GITLAUNCH_SOURCE_ONLY=1 GITLAUNCH="$GITLAUNCH" zsh -c '
  source "$GITLAUNCH"
  whence -w restore_pr_push_checkout >/dev/null
  whence -w arm_pr_push_restore >/dev/null
'

echo "[2/4] normal recovery restores a clean base branch"
prepare_pr_branch normal
GITLAUNCH_SOURCE_ONLY=1 GITLAUNCH="$GITLAUNCH" TEST_REPO="$TMP/repo" zsh -c '
  source "$GITLAUNCH"
  cd "$TEST_REPO"
  arm_pr_push_restore main "$TEST_REPO"
  restore_pr_push_checkout
'
assert_restored

echo "[3/4] EXIT recovery restores after an unexpected process exit"
prepare_pr_branch exit
set +e
GITLAUNCH_SOURCE_ONLY=1 GITLAUNCH="$GITLAUNCH" TEST_REPO="$TMP/repo" zsh -c '
  source "$GITLAUNCH"
  cd "$TEST_REPO"
  arm_pr_push_restore main "$TEST_REPO"
  exit 23
'
exit_status=$?
set -e
[[ "$exit_status" -eq 23 ]]
assert_restored

echo "[4/4] recovery failures are visible and signal-safe exits are restartable"
set +e
failure_output="$(GITLAUNCH_SOURCE_ONLY=1 GITLAUNCH="$GITLAUNCH" TEST_REPO="$TMP/repo" zsh -c '
  source "$GITLAUNCH"
  cd "$TEST_REPO"
  arm_pr_push_restore missing-base "$TEST_REPO"
  restore_pr_push_checkout
' 2>&1)"
failure_status=$?
set -e
[[ "$failure_status" -ne 0 ]]
grep -q "Could not restore checkout" <<< "$failure_output"

GIT_MENUS="$GIT_MENUS" bash -c '
  source "$GIT_MENUS"
  git_menu_exit_is_restartable 0
  git_menu_exit_is_restartable 130
  git_menu_exit_is_restartable 143
  ! git_menu_exit_is_restartable 1
'

echo "gitlaunch PR-push recovery smoke OK"
