# Safe merge

`gitmerge-safe.sh` is a Class C local mutating action.

It may change the current local Git branch by running `git merge --ff-only` or
`git merge --no-ff`, but it must not push, force-push, delete remote branches,
or write to GitHub.

## Contract

* requires a Git worktree
* refuses detached HEAD
* refuses dirty working trees
* fetches refs before presenting choices when `origin` exists
* previews incoming commits before merging
* requires an interactive terminal
* requires explicit confirmation before merge
* performs no push

Use this helper only for local branch integration. Remote merge, PR merge, and
branch protection behavior stay in GitHub and `gh`, not inside `mqlaunch`.
