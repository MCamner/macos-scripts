#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

die() {
  red "Error: $*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

require_cmd git

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a Git repository."

current_branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$current_branch" != "HEAD" ]] || die "Detached HEAD is not supported. Checkout a branch first."

if [[ -n "$(git status --porcelain)" ]]; then
  die "Working tree is not clean. Commit/stash/discard changes first."
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

blue "Repo: $(basename "$repo_root")"
blue "Current branch (merge target): $current_branch"
echo

if git remote get-url origin >/dev/null 2>&1; then
  yellow "Fetching latest refs from origin..."
  git fetch --prune origin
else
  yellow "No origin remote found. Continuing with local refs only."
fi

[[ -t 0 ]] || die "This script needs an interactive terminal (stdin is not a TTY)."

branches=()
while IFS= read -r branch; do
  branches+=("$branch")
done < <(
  {
    git for-each-ref --format='%(refname:short)' refs/heads
    git for-each-ref --format='%(refname:short)' refs/remotes/origin 2>/dev/null || true
  } \
  | grep -vE '^(HEAD|origin|origin/HEAD)$' \
  | grep -vx "$current_branch" \
  | grep -vx "origin/$current_branch" \
  | sort -u
)

((${#branches[@]} > 0)) || die "No candidate branches found to merge."

echo "Select source branch to merge INTO $current_branch:"
for i in "${!branches[@]}"; do
  printf "  %2d) %s\n" "$((i + 1))" "${branches[$i]}"
done
echo

read -r -p "Choice [1-${#branches[@]}] (or q to quit): " choice || die "No input received."
[[ "${choice:-}" =~ ^[Qq]$ ]] && exit 0
[[ "${choice:-}" =~ ^[0-9]+$ ]] || die "Invalid choice."
(( choice >= 1 && choice <= ${#branches[@]} )) || die "Choice out of range."

source_ref="${branches[$((choice - 1))]}"

echo
blue "Merge plan"
echo "  Source: $source_ref"
echo "  Target: $current_branch"
echo

yellow "Commits that would come in from $source_ref:"
git log --oneline --decorate "${current_branch}..${source_ref}" || true
echo

if git merge-base --is-ancestor "$source_ref" "$current_branch"; then
  green "Nothing to merge: $current_branch already contains $source_ref."
  exit 0
fi

read -r -p "Proceed with merge? [y/N]: " confirm
[[ "${confirm:-}" =~ ^[Yy]$ ]] || {
  yellow "Merge cancelled."
  exit 0
}

echo
if git merge-base --is-ancestor "$current_branch" "$source_ref"; then
  yellow "Fast-forward possible. Running: git merge --ff-only $source_ref"
  if git merge --ff-only "$source_ref"; then
    green "Fast-forward merge completed."
  else
    red "Fast-forward merge failed."
    exit 1
  fi
else
  yellow "Fast-forward not possible. Running: git merge --no-ff $source_ref"
  if git merge --no-ff "$source_ref"; then
    green "Merge completed."
  else
    red "Merge stopped due to conflicts."
    echo
    echo "Resolve conflicts, then run:"
    echo "  git add <resolved-files>"
    echo "  git commit"
    echo
    echo "Or abort with:"
    echo "  git merge --abort"
    exit 1
  fi
fi

echo
yellow "Recent commits:"
git --no-pager log --oneline --decorate -n 8

echo
green "Done. No push was performed."
echo "Review the result, then push separately if you want."
