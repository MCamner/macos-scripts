#!/usr/bin/env bash
# Proves the git automation cannot leave a repo off-main: after the PR-branch
# push flow, git-restore-to-base.sh returns the checkout to a clean, in-sync
# base branch (no off-main, no unpushed commit).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/tools/scripts/git-restore-to-base.sh"

[ -x "$HELPER" ] || { echo "FAIL: $HELPER missing or not executable" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

_git() { git -C "$1" "${@:2}"; }

# Bare origin + working clone on main.
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/repo"
REPO="$TMP/repo"
_git "$REPO" config user.email t@e.co
_git "$REPO" config user.name Test
_git "$REPO" config commit.gpgSign false
_git "$REPO" checkout -q -B main
echo init > "$REPO/f.txt"
_git "$REPO" add -A
_git "$REPO" commit -q -m init
_git "$REPO" push -q -u origin main

# Simulate the automation: commit on main, then branch a PR branch off it and
# push that (mirrors run_ai_commit -> create_pr_branch_for_push).
echo change > "$REPO/f.txt"
_git "$REPO" commit -q -am "update project files"
PR_BRANCH="mq/update-project-files-$(date +%Y%m%d-%H%M%S)"
_git "$REPO" switch -q -c "$PR_BRANCH"
_git "$REPO" push -q -u origin "$PR_BRANCH"

# Pre-condition: the bug's end state — checkout off-main, main ahead (unpushed).
[ "$(_git "$REPO" branch --show-current)" = "$PR_BRANCH" ] \
  || { echo "FAIL: setup did not leave checkout on the PR branch" >&2; exit 1; }
[ "$(_git "$REPO" rev-list --count origin/main..main)" -eq 1 ] \
  || { echo "FAIL: setup did not leave main ahead of origin" >&2; exit 1; }

# Act: restore.
"$HELPER" main "$REPO"

# Assert: checkout back on main.
[ "$(_git "$REPO" branch --show-current)" = "main" ] \
  || { echo "FAIL: checkout not restored to main" >&2; exit 1; }
# Assert: main is in sync with origin/main (no unpushed commit left behind).
[ "$(_git "$REPO" rev-parse main)" = "$(_git "$REPO" rev-parse origin/main)" ] \
  || { echo "FAIL: main not in sync with origin/main (unpushed commit remained)" >&2; exit 1; }
# Assert: working tree clean.
[ -z "$(_git "$REPO" status --porcelain)" ] \
  || { echo "FAIL: working tree not clean after restore" >&2; exit 1; }
# Assert: the automation commit is preserved on the pushed PR branch (nothing lost).
_git "$REPO" rev-parse --verify -q "origin/$PR_BRANCH" >/dev/null \
  || { echo "FAIL: PR-branch commit not preserved on origin" >&2; exit 1; }

# Idempotence: running restore again from a clean base branch is a no-op success.
"$HELPER" main "$REPO"
[ "$(_git "$REPO" branch --show-current)" = "main" ] \
  || { echo "FAIL: restore not idempotent" >&2; exit 1; }

echo "git-restore-to-base smoke OK"
