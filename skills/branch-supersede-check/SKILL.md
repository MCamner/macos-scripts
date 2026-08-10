---
name: branch-supersede-check
description: Decide whether an unmerged branch still holds work that trunk does not have, before deleting or reviving it. Compares every touched file against main as it is now, instead of trusting the three-dot diff — which looks identical for a branch carrying real work and one whose work already landed by another route. Use when a branch looks unmerged but might be superseded, when triaging stale branches, or when `git diff main...branch` shows changes and you need to know whether they still matter.
---

# Branch Supersede Check

`git diff main...branch` is the wrong instrument for the question "does this
branch still matter", and it fails silently.

The three-dot form compares against the **merge base** — the point where the
branch forked. It lists everything the branch did since then, whether or not
trunk has since acquired the same content by a different route: a squash merge,
a cherry-pick, a rewrite, someone doing the same work in another PR. A branch
whose work landed months ago produces exactly the same shape of output as one
holding something unique. Same file count, same additions, same confident green
`+325 insertions`.

What separates them is a per-file comparison against trunk **as it is now**.

This skill does that comparison. It does not decide for you.

---

## Evals

### Should trigger

* "is this branch safe to delete?"
* "does this branch still have anything we need?"
* "the diff shows changes but I think this already landed"
* "triage these stale branches"
* "why does git refuse to delete this branch with -d?"

### Should not trigger

* "which branches exist and which are merged?" → run the `mq-checkbranch`
  skill (personal, not in this repo)
* "merge this pull request" → `terminal/launchers/gitpr-merge-safe.sh`
* "what changed in this PR?" → a plain `git diff` is the right tool there

---

## Run it

The script lives with this skill. Both agent tools reach the same copy:
`~/.agents/skills/branch-supersede-check` and `~/.claude/skills/branch-supersede-check`
are symlinks to it.

```bash
S=~/macos-scripts/skills/branch-supersede-check/scripts/supersede-report.sh

"$S" <branch>                      # judge a branch in the current repo
"$S" <branch> --repo ~/some-repo   # judge one elsewhere
"$S" <branch> --base develop       # trunk is not called main
"$S" <branch> --verbose            # print the diffs too
"$S" <branch> --no-pr              # skip the merged-PR lookup, no network
```

Read-only. It never checks out, merges, resets, or deletes. The one network
call is the merged-PR lookup, skipped with `--no-pr` or when `gh` is absent.

Accepts a branch name, tag, or SHA. Exit status: `0` superseded, `1` needs
review, `2` bad usage or unknown ref.

---

## Reading the output

Every file the branch touched gets one of five labels:

* `IDENTICAL` — byte-for-byte the same as trunk. The work landed.
* `BASE-AHEAD` — trunk has lines this branch does not, and the branch adds
  nothing. The branch is simply behind.
* `BRANCH-AHEAD` — the branch has lines trunk does not, and removes nothing.
* `DIVERGED` — both sides have lines the other lacks.
* `ONLY-ON-BRANCH` — the file does not exist in trunk at all.

The summary line is the signal. A high `identical` count is the strongest
evidence a branch is superseded, because identical files do not happen by
accident — they mean this exact content is already in trunk.

---

## What it cannot tell you

`BRANCH-AHEAD`, `DIVERGED` and `ONLY-ON-BRANCH` mean the text differs. They do
**not** mean the difference is worth keeping. This is where the tool stops and
you read.

Three real cases where "has unique content" was true and the branch was still
right to delete:

* A branch adding a name to an inventory list. Trunk had already added the same
  name independently, in a different position. Textually unique; applying it
  would have duplicated the entry.
* A branch adding a skill directory that trunk does not contain — because the
  skill had been deliberately moved to another repo.
* A branch with a CI workflow and docs that `DIVERGED`. Trunk's version was a
  superset: it had two extra check steps the branch would have removed, and a
  deliberate comment explaining why a `paths:` filter had been taken out. The
  branch was not different. It was older, and reviving it would have regressed
  CI.

So: **a `DIVERGED` file usually means the branch is behind, not ahead.** Check
the direction before assuming there is something to rescue.

---

## The corroborating checks

The file comparison is one input. Two others settle most cases:

**A merged PR whose head was this branch.** Squash merging leaves no ancestry
and no identical files, so a squash-merged branch can look entirely unique. The
script looks this up automatically when the branch ref still exists locally.
If you are checking a SHA whose branch is already deleted, the lookup is
skipped — pass the name instead, or check by hand:

```bash
gh pr list --state merged --limit 200 --json number,headRefName,mergedAt \
  --jq '.[] | select(.headRefName == "<branch>")'
```

**Commits after the merge.** A PR can be merged and the branch keep moving.
Compare the branch tip date against the PR's `mergedAt`; anything later is not
in trunk. `mq-checkbranch` flags this as
`[#N merged, but commits came after — verify]`.

---

## Deleting

Never on the tool's word alone, and never unattended.

A superseded branch needs `git branch -D`, not `-d`. Git refuses `-d` because
the commits are formally not in trunk even when every byte of their content is.
That refusal is not a warning worth heeding here — it is measuring ancestry,
which is exactly the thing squash merging destroys.

Record the SHA before deleting. It stays in the reflog for a while, and a
one-line note costs nothing:

```bash
printf '%s\t%s\n' "$branch" "$(git rev-parse "$branch")" >> deleted-branches.tsv
```

---

## Related

* `mq-checkbranch` — inventories every branch in a repo and buckets them as
  merged / stale / active. Use it first to find candidates; use this one to
  judge a specific candidate it could not classify.

---

## Why this exists

Four branches in one day looked like unmerged work and were not. The pattern is
not rare and it is not obvious, because the misleading signal is a green one:
a diff that renders, with plausible content, in a format everyone trusts.

The general form is worth carrying beyond git. A check that passes is a claim
about what it measured, not about what you wanted to know. When something looks
settled, ask what the output would look like if it were wrong — and if the
answer is "exactly like this", find a different measurement.
