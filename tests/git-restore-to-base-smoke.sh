#!/usr/bin/env bash
# Proves the git automation cannot leave a repo off-main: after the PR-branch
# push flow, git-restore-to-base.sh returns the checkout to a clean, in-sync
# base branch (no off-main, no unpushed commit).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/tools/scripts/git-restore-to-base.sh"
GIT_MENU="$ROOT/terminal/menus/mq-git-menu.sh"

[ -x "$HELPER" ] || { echo "FAIL: $HELPER missing or not executable" >&2; exit 1; }
[ -r "$GIT_MENU" ] || { echo "FAIL: $GIT_MENU missing or not readable" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

_git() { git -C "$1" "${@:2}"; }

assert_restored() {
  local repo="$1"

  [ "$(_git "$repo" branch --show-current)" = "main" ] \
    || { echo "FAIL: checkout not restored to main" >&2; exit 1; }
  [ "$(_git "$repo" rev-parse main)" = "$(_git "$repo" rev-parse origin/main)" ] \
    || { echo "FAIL: main not in sync with origin/main" >&2; exit 1; }
  [ -z "$(_git "$repo" status --porcelain)" ] \
    || { echo "FAIL: working tree not clean after restore" >&2; exit 1; }
}

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

# Create the automation commit on main.
echo change > "$REPO/f.txt"
_git "$REPO" commit -q -am "update project files"

# Pre-condition: main has the unpushed automation commit.
[ "$(_git "$REPO" rev-list --count origin/main..main)" -eq 1 ] \
  || { echo "FAIL: setup did not leave main ahead of origin" >&2; exit 1; }

# Act through the real menu function. mq-git-menu.sh assigns CURRENT_REPO while
# being sourced, so MQ_GIT_REPO must point at the disposable test repo first.
export MACOS_SCRIPTS_HOME="$ROOT"
export MQ_GIT_REPO="$REPO"
# shellcheck disable=SC1090
source "$GIT_MENU"
create_pr_branch_for_push main "update project files interrupt test" <<< "y"

PR_BRANCH="$(_git "$REPO" for-each-ref --format='%(refname:short)' \
  'refs/remotes/origin/mq/update-project-files-interrupt-test-*' | head -1)"
[ -n "$PR_BRANCH" ] \
  || { echo "FAIL: menu flow did not push the PR branch" >&2; exit 1; }

assert_restored "$REPO"
# Assert: the automation commit is preserved on the pushed PR branch (nothing lost).
_git "$REPO" rev-parse --verify -q "$PR_BRANCH" >/dev/null \
  || { echo "FAIL: PR-branch commit not preserved on origin" >&2; exit 1; }

# Idempotence: running restore again from a clean base branch is a no-op success.
"$HELPER" main "$REPO"
[ "$(_git "$REPO" branch --show-current)" = "main" ] \
  || { echo "FAIL: restore not idempotent" >&2; exit 1; }

# Regression: a failed push must also restore the start branch.
echo failed-change > "$REPO/f.txt"
_git "$REPO" commit -q -am "update project files failed"
origin_url="$(_git "$REPO" remote get-url origin)"
_git "$REPO" remote set-url origin "$TMP/missing/origin.git"
set +e
MACOS_SCRIPTS_HOME="$ROOT" MQ_GIT_REPO="$REPO" GIT_MENU="$GIT_MENU" bash -c '
  # MQ_GIT_REPO explicitly contains the disposable repo before line 19 runs.
  source "$GIT_MENU"
  create_pr_branch_for_push main "update project files failed" <<< "y"
'
failure_status=$?
set -e
[ "$failure_status" -ne 0 ] \
  || { echo "FAIL: push-failure menu flow unexpectedly succeeded" >&2; exit 1; }
assert_restored "$REPO"
_git "$REPO" remote set-url origin "$origin_url"

# Regression: terminate the real menu push path after it switches branches.
# The TERM trap must restore the checkout even though normal control flow never
# reaches the end of create_pr_branch_for_push.
echo interrupted-change > "$REPO/f.txt"
_git "$REPO" commit -q -am "update project files interrupted"
REAL_GIT="$(command -v git)"
mkdir -p "$TMP/bin"
cat > "$TMP/bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" push "* ]]; then
  kill -TERM "$FLOW_PID"
  exit 143
fi
exec "$REAL_GIT" "$@"
EOF
chmod +x "$TMP/bin/git"

set +e
MACOS_SCRIPTS_HOME="$ROOT" MQ_GIT_REPO="$REPO" REAL_GIT="$REAL_GIT" \
  PATH="$TMP/bin:$PATH" GIT_MENU="$GIT_MENU" bash -c '
    export FLOW_PID=$$
    # MQ_GIT_REPO explicitly contains the disposable repo before line 19 runs.
    source "$GIT_MENU"
    create_pr_branch_for_push main "update project files interrupted" <<< "y"
  '
interrupt_status=$?
set -e
[ "$interrupt_status" -ne 0 ] \
  || { echo "FAIL: interrupted menu flow unexpectedly succeeded" >&2; exit 1; }
assert_restored "$REPO"

echo "git-restore-to-base smoke OK"
