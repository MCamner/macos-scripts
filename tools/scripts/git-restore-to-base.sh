#!/usr/bin/env bash
# Restore the working checkout to the base branch after a PR-branch push, so the
# git automation never leaves a repo off-main.
#
# The "auto commit + push" flow commits on the base branch, then branches a
# `mq/...` PR branch off it and pushes that. Without this step the checkout is
# left on the PR branch (off-main) and the base branch keeps the commit locally
# (an unpushed commit). This restores a clean state:
#   1. Rewind the local base ref to origin/<base> — non-destructive, because the
#      commit is already on the pushed PR branch (origin/<pr-branch>); nothing is
#      lost, no remote is changed, no tag or force-push is involved.
#   2. Switch the working checkout back to the base branch.
#
# Usage: git-restore-to-base.sh <base_branch> [repo_dir]
# Exit 0 when the checkout is back on a clean base branch; non-zero with a clear
# report to stderr (repo, current branch, dirty count, manual fix) otherwise.
set -uo pipefail

base_branch="${1:-}"
repo_dir="${2:-.}"
if [ -z "$base_branch" ]; then
  echo "usage: git-restore-to-base.sh <base_branch> [repo_dir]" >&2
  exit 2
fi

cur="$(git -C "$repo_dir" branch --show-current 2>/dev/null || true)"

# 1. Rewind the local base ref to origin (only when base is not checked out, so
#    the ref move is safe). The PR-branch commit is preserved on the remote.
if [ "$cur" != "$base_branch" ] \
   && git -C "$repo_dir" rev-parse --verify -q "refs/remotes/origin/$base_branch" >/dev/null 2>&1; then
  git -C "$repo_dir" branch -f "$base_branch" "origin/$base_branch" >/dev/null 2>&1 || true
fi

# 2. Restore the working checkout to the base branch.
if git -C "$repo_dir" switch "$base_branch" >/dev/null 2>&1 \
   || git -C "$repo_dir" checkout "$base_branch" >/dev/null 2>&1; then
  exit 0
fi

# Could not restore — report so the operator can fix it by hand.
now="$(git -C "$repo_dir" branch --show-current 2>/dev/null || echo unknown)"
dirty="$(git -C "$repo_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
{
  echo "⚠ Could not restore checkout to '$base_branch'."
  echo "  repo:         $repo_dir"
  echo "  branch now:   $now"
  echo "  uncommitted:  ${dirty} file(s)"
  echo "  fix manually: git -C \"$repo_dir\" switch $base_branch"
} >&2
exit 1
