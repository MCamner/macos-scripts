#!/usr/bin/env bash
# Decide whether a branch still carries work that trunk does not have.
#
# The question looks like it should be a diff, and it is not. `git diff
# base...branch` compares against the MERGE BASE, so it lists everything the
# branch did since it forked — whether or not trunk has since acquired the
# same content by another route. A branch whose work already landed produces
# exactly the same shape of output as one holding something unique.
#
# What separates them is a per-file comparison against trunk as it is NOW
# (two-dot). This walks every file the branch touched and classifies it.
#
# Read-only. Never checks out, merges, or deletes.
set -uo pipefail

BASE="main"
REPO="."
BRANCH=""
VERBOSE=0
NO_PR=0

usage() {
  cat <<'USAGE'
usage: supersede-report.sh <branch> [--repo PATH] [--base REF] [--verbose]

  <branch>        branch, tag or SHA to judge
  --repo PATH     repository to run in (default: current directory)
  --base REF      trunk to compare against (default: main)
  --verbose       also print, per differing file, which side has more
  --no-pr         skip the merged-PR lookup (no network, no gh)

Exit status: 0 superseded, 1 has unique content, 2 usage or lookup error.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="${2:-}"; shift 2 ;;
    --base)    BASE="${2:-}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    --no-pr)   NO_PR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)        echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)         BRANCH="$1"; shift ;;
  esac
done

[[ -n "$BRANCH" ]] || { usage >&2; exit 2; }

git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "not a git repository: $REPO" >&2; exit 2; }

git() { command git -C "$REPO" "$@"; }

for ref in "$BASE" "$BRANCH"; do
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null \
    || { echo "no such ref: $ref" >&2; exit 2; }
done

branch_sha="$(git rev-parse --short "$BRANCH")"
base_sha="$(git rev-parse --short "$BASE")"
merge_base="$(git merge-base "$BASE" "$BRANCH" 2>/dev/null || true)"

# Without a merge base there is nothing to compare, and every comparison below
# fails to empty. Empty output would then be counted as zero unique files and
# printed as "superseded" — a delete recommendation for a branch that shares no
# history with trunk at all. A comparison that could not run is an error, not a
# verdict.
if [[ -z "$merge_base" ]]; then
  echo "no merge base between $BASE and $BRANCH — unrelated histories" >&2
  exit 2
fi

echo "=== $BRANCH ($branch_sha) vs $BASE ($base_sha) ==="

# Ancestry and PR evidence are cheap and answer the question outright when they
# apply. A branch already in trunk needs no file comparison.
if git merge-base --is-ancestor "$BRANCH" "$BASE" 2>/dev/null; then
  echo "  ANCESTOR OF $BASE — every commit is already in trunk."
  echo
  echo "VERDICT: superseded (by ancestry)"
  exit 0
fi

ahead="$(git rev-list --count "$BASE..$BRANCH" 2>/dev/null || echo '?')"
behind="$(git rev-list --count "$BRANCH..$BASE" 2>/dev/null || echo '?')"
echo "  commits: $ahead not in $BASE, $behind in $BASE not here"
[[ -n "$merge_base" ]] && echo "  forked at: $(git rev-parse --short "$merge_base") ($(git log -1 --format=%ar "$merge_base"))"
echo "  last commit: $(git log -1 --format='%ar (%ai)' "$BRANCH")"
echo

# The misleading view, printed on purpose so the two can be compared. Taken
# once and kept: running it twice invites the count and the loop to disagree,
# and a failure here has to stop the run rather than empty it.
#
# stderr goes to its own file instead of being folded into the list. git writes
# "multiple merge bases" here as a WARNING on a run that SUCCEEDS, and a warning
# captured as if it were output becomes a filename: counted in the total, walked
# by the loop, and printed as a phantom row. It was labelled GONE-FROM-BOTH once,
# because no such path exists on either side.
git_stderr="$(mktemp)"
trap 'rm -f "$git_stderr"' EXIT
if ! changed="$(git diff --name-only "$BASE...$BRANCH" 2>"$git_stderr")"; then
  echo "cannot compare $BASE...$BRANCH: $(cat "$git_stderr")" >&2
  exit 2
fi

three_dot=0
[[ -n "$changed" ]] && three_dot="$(printf '%s\n' "$changed" | wc -l | tr -d ' ')"
echo "  three-dot diff ($BASE...$BRANCH) touches $three_dot file(s)"
# Kept, not swallowed. "multiple merge bases" says the fork point was picked
# arbitrarily from several, which makes the three-dot view below even less
# trustworthy than the general case this whole script exists to warn about.
[[ -s "$git_stderr" ]] && sed 's/^/  note: /' "$git_stderr"
echo "  — that is measured against the fork point, so it looks the same"
echo "    whether or not trunk already has the content. Per-file, vs $BASE now:"
echo

identical=0; base_ahead=0; branch_ahead=0; diverged=0; only_branch=0; gone_both=0

while IFS= read -r f; do
  [[ -n "$f" ]] || continue

  if ! git cat-file -e "$BASE:$f" 2>/dev/null; then
    # The file is in the three-dot diff and absent from trunk. That is two
    # different branches: one where the branch added it, and one where the
    # branch DELETED it and trunk has since dropped it too. Only the first is
    # content the branch holds — calling the second unique would count a
    # deletion trunk already made as a reason to keep the branch.
    if ! git cat-file -e "$BRANCH:$f" 2>/dev/null; then
      printf '  GONE-FROM-BOTH  %s\n' "$f"
      gone_both=$((gone_both + 1))
      continue
    fi
    printf '  ONLY-ON-BRANCH  %s\n' "$f"
    only_branch=$((only_branch + 1))
    continue
  fi

  if git diff --quiet "$BASE" "$BRANCH" -- "$f" 2>/dev/null; then
    printf '  IDENTICAL       %s\n' "$f"
    identical=$((identical + 1))
    continue
  fi

  # numstat runs base -> branch: added = lines only the branch has,
  # removed = lines only the base has.
  read -r added removed _ < <(git diff --numstat "$BASE" "$BRANCH" -- "$f" 2>/dev/null)
  added="${added:-0}"; removed="${removed:-0}"
  [[ "$added"   == "-" ]] && added=0      # binary files report as -
  [[ "$removed" == "-" ]] && removed=0

  if [[ "$added" -eq 0 && "$removed" -gt 0 ]]; then
    printf '  BASE-AHEAD      %s  (%s has %s line(s) the branch lacks)\n' "$f" "$BASE" "$removed"
    base_ahead=$((base_ahead + 1))
  elif [[ "$added" -gt 0 && "$removed" -eq 0 ]]; then
    printf '  BRANCH-AHEAD    %s  (+%s)\n' "$f" "$added"
    branch_ahead=$((branch_ahead + 1))
  else
    printf '  DIVERGED        %s  (+%s/-%s)\n' "$f" "$added" "$removed"
    diverged=$((diverged + 1))
  fi

  if [[ "$VERBOSE" -eq 1 ]]; then
    git diff "$BASE" "$BRANCH" -- "$f" | sed 's/^/      /' | head -20
  fi
done <<< "$changed"

total=$((identical + base_ahead + branch_ahead + diverged + only_branch + gone_both))
echo
printf '  identical %s · base-ahead %s · branch-ahead %s · diverged %s · only-on-branch %s · gone-from-both %s  (of %s)\n' \
  "$identical" "$base_ahead" "$branch_ahead" "$diverged" "$only_branch" "$gone_both" "$total"
echo

# A merged PR whose head was this branch is the evidence squash-merging
# destroys: no ancestry, no identical files, and the work is still in trunk.
# Checked last because it is the only step that touches the network.
pr_note=""
pr_lookup_failed=0
if [[ "$NO_PR" -eq 0 ]] && command -v gh >/dev/null 2>&1; then
  name="$BRANCH"
  if ! git show-ref --verify --quiet "refs/heads/$name"; then
    name="$(git for-each-ref --format='%(refname:short)' --points-at "$BRANCH" refs/heads 2>/dev/null | head -1)"
  fi
  if [[ -n "$name" ]]; then
    # Filtered by GitHub, not locally: a page of recent PRs has a cap, and the
    # branch this question is being asked about is usually an old one.
    if gh_out="$(gh pr list --state merged --head "$name" \
        --json number,mergedAt \
        --jq '.[] | "#\(.number) merged \(.mergedAt[0:10])"' 2>/dev/null)"; then
      pr_note="$(printf '%s\n' "$gh_out" | head -1)"
    else
      pr_lookup_failed=1
    fi
  fi
fi

if [[ -n "$pr_note" ]]; then
  echo "  merged PR for this head: $pr_note"
  echo
elif [[ "$pr_lookup_failed" -eq 1 ]]; then
  # The lookup is the evidence a squash merge destroys. Not finding one and not
  # being able to look are different facts, and only one of them is reassuring.
  echo "  could not check for a merged PR — the lookup failed, so its absence"
  echo "  below is not evidence. Re-run with gh working, or check by hand."
  echo
fi

unique=$((branch_ahead + diverged + only_branch))
settled=$((identical + base_ahead + gone_both))

if [[ "$total" -eq 0 || "$unique" -eq 0 ]]; then
  echo "VERDICT: superseded — nothing here is missing from $BASE."
  echo "         Deleting needs -D: the commits are formally not in $BASE even"
  echo "         though the content is."
  exit 0
fi

# Everything below has files trunk does not literally contain. That is where
# the tool stops being able to decide and starts owing you a reason to look.
if [[ -n "$pr_note" ]]; then
  echo "VERDICT: review — $unique file(s) differ, but $pr_note."
  echo "         A squash merge leaves no ancestry and no identical files, so a"
  echo "         differing file here is expected. Check whether the difference is"
  echo "         work added AFTER the merge, or just the pre-squash shape."
elif [[ "$settled" -gt "$unique" ]]; then
  echo "VERDICT: review, leaning superseded — $settled of $total file(s) are"
  echo "         identical to $BASE or behind it, and $unique are not."
  echo "         That ratio usually means the work landed by another route and"
  echo "         trunk moved on. Read the $unique before deciding."
else
  echo "VERDICT: review — $unique of $total file(s) hold something $BASE does not."
fi

echo
echo "         This tool compares text, not worth. A DIVERGED file often means the"
echo "         branch is simply older, and an ONLY-ON-BRANCH file can be something"
echo "         deliberately moved or dropped. Read them:"
echo "           git -C $REPO diff $BASE $BRANCH -- <file>"
exit 1
