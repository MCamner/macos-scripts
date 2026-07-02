#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Remote PR-merge companion to gitmerge-safe.sh.
#
# gitmerge-safe.sh does LOCAL merges (source branch -> current branch) and never
# pushes. This script closes a REMOTE pull request via `gh pr merge`, with the
# same guardrails: show the plan, refuse without a TTY, confirm before acting.

# Coordinates red behavior.
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
# Coordinates green behavior.
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
# Coordinates yellow behavior.
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
# Coordinates blue behavior.
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

# Coordinates die behavior.
die() {
  red "Error: $*"
  exit 1
}

# Verifies the required cmd helper is available before continuing.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

require_cmd git
require_cmd gh

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a Git repository."

# Class C interactive action: refuse before any network operation if there is no
# TTY to confirm against.
[[ -t 0 ]] || die "This script needs an interactive terminal (stdin is not a TTY)."

gh auth status >/dev/null 2>&1 || die "GitHub CLI is not authenticated. Run: gh auth login"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$current_branch" != "HEAD" ]] || die "Detached HEAD is not supported. Checkout a branch first."

blue "Repo: $(basename "$repo_root")"
blue "Current branch: $current_branch"
echo

# ------------------------
# RESOLVE TARGET PR
# ------------------------
# Priority: explicit argument -> PR for the current branch -> pick from open list.
pr_number="${1:-}"

if [[ -z "$pr_number" ]]; then
  # Try the PR whose head is the current branch.
  pr_number="$(gh pr view --json number --jq '.number' 2>/dev/null || true)"
fi

if [[ -z "$pr_number" ]]; then
  yellow "No PR argument and no PR for the current branch. Open pull requests:"
  echo
  gh pr list --state open --limit 30 \
    --json number,title,headRefName,baseRefName \
    --template '{{range .}}{{printf "  %v) #%v  %s  (%s -> %s)\n" .number .number .title .headRefName .baseRefName}}{{end}}' \
    || die "Could not list pull requests."
  echo
  read -r -p "PR number to merge (or q to quit): " pr_number
  [[ "${pr_number:-}" =~ ^[Qq]$ ]] && exit 0
fi

[[ "${pr_number:-}" =~ ^[0-9]+$ ]] || die "Invalid PR number: ${pr_number:-<empty>}"

# ------------------------
# SHOW MERGE PLAN
# ------------------------
gh pr view "$pr_number" --json number >/dev/null 2>&1 || die "Could not read PR #$pr_number."

# Read one field at a time via gh's built-in --jq, so we do not depend on a
# standalone jq binary being installed.
pr_field() {
  gh pr view "$pr_number" --json "$1" --jq ".$1" 2>/dev/null || true
}

title="$(pr_field title)"
state="$(pr_field state)"
is_draft="$(pr_field isDraft)"
base_ref="$(pr_field baseRefName)"
head_ref="$(pr_field headRefName)"
mergeable="$(pr_field mergeable)"
merge_state="$(pr_field mergeStateStatus)"
review_decision="$(pr_field reviewDecision)"
pr_url="$(pr_field url)"

echo
blue "Merge plan"
echo "  PR:       #$pr_number  $title"
echo "  Flow:     $head_ref -> $base_ref"
echo "  State:    ${state:-unknown}${is_draft:+ (draft: $is_draft)}"
echo "  Mergeable:${mergeable:+ $mergeable}${merge_state:+ / $merge_state}"
echo "  Review:   ${review_decision:-none}"
echo "  URL:      ${pr_url:-n/a}"
echo

if [[ "$state" != "OPEN" ]]; then
  die "PR #$pr_number is not open (state: ${state:-unknown})."
fi

if [[ "$is_draft" == "true" ]]; then
  die "PR #$pr_number is a draft. Mark it ready for review first."
fi

# CI / check summary.
yellow "Checks:"
gh pr checks "$pr_number" 2>/dev/null || yellow "  (no checks reported)"
echo

# ------------------------
# SOFT-BLOCK ON RISK
# ------------------------
risky=0
if [[ "$mergeable" == "CONFLICTING" ]]; then
  red "PR is CONFLICTING. Resolve conflicts before merging."
  risky=1
fi
if [[ "$merge_state" == "BLOCKED" || "$merge_state" == "BEHIND" || "$merge_state" == "DIRTY" ]]; then
  yellow "Merge state is $merge_state (branch protection or out-of-date branch)."
  risky=1
fi
if [[ "$review_decision" == "CHANGES_REQUESTED" ]]; then
  yellow "Review decision is CHANGES_REQUESTED."
  risky=1
fi
if ! gh pr checks "$pr_number" >/dev/null 2>&1; then
  yellow "One or more checks are failing or pending."
  risky=1
fi

if [[ "$risky" -eq 1 ]]; then
  echo
  read -r -p "This PR is not cleanly mergeable. Proceed anyway? [y/N]: " force
  [[ "${force:-}" =~ ^[Yy]$ ]] || { yellow "Merge cancelled."; exit 0; }
fi

# ------------------------
# MERGE METHOD
# ------------------------
method="${2:-}"
if [[ -z "$method" ]]; then
  echo
  echo "Merge method:"
  echo "  1) squash (default)"
  echo "  2) merge commit"
  echo "  3) rebase"
  read -r -p "Choice [1-3, Enter=1]: " m
  case "${m:-1}" in
    1|"") method="squash" ;;
    2)    method="merge" ;;
    3)    method="rebase" ;;
    *)    die "Invalid method choice." ;;
  esac
fi

case "$method" in
  squash) method_flag="--squash" ;;
  merge)  method_flag="--merge" ;;
  rebase) method_flag="--rebase" ;;
  *)      die "Unknown merge method: $method" ;;
esac

# ------------------------
# CONFIRM + MERGE
# ------------------------
echo
blue "About to run:"
echo "  gh pr merge $pr_number $method_flag --delete-branch"
echo
read -r -p "Proceed with remote PR merge? [y/N]: " confirm
[[ "${confirm:-}" =~ ^[Yy]$ ]] || { yellow "Merge cancelled."; exit 0; }

echo
if gh pr merge "$pr_number" "$method_flag" --delete-branch; then
  green "PR #$pr_number merged ($method) and remote branch deleted."
else
  die "gh pr merge failed for PR #$pr_number."
fi

# ------------------------
# SYNC LOCAL BASE
# ------------------------
echo
if [[ -n "$base_ref" ]]; then
  yellow "Syncing local $base_ref..."
  if git switch "$base_ref" 2>/dev/null || git checkout "$base_ref" 2>/dev/null; then
    git pull --ff-only origin "$base_ref" || yellow "Could not fast-forward $base_ref (resolve manually)."
  else
    yellow "Could not switch to $base_ref locally (skipping sync)."
  fi

  # Clean up the now-merged local head branch if it still exists and is safe.
  if [[ "$head_ref" != "$base_ref" ]] && git show-ref --verify --quiet "refs/heads/$head_ref"; then
    if git branch -d "$head_ref" 2>/dev/null; then
      green "Deleted local branch $head_ref."
    else
      yellow "Local branch $head_ref not deleted (not fully merged locally); remove manually if desired."
    fi
  fi
fi

echo
green "Done."
git --no-pager log --oneline --decorate -n 6
