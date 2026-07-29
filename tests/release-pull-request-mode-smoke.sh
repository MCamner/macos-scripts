#!/usr/bin/env bash
set -euo pipefail

# release.sh must obey `release_mode` in .mq/repo-contract.json. This repo's
# contract says `pull_request`, but the script pushed main directly anyway —
# and main carries no server-side branch protection, so nothing else would have
# stopped it. v2.0.0 was in fact released through PR #106 plus a hand-made tag;
# the script was the one part of the flow that disagreed with the contract.
#
# The proof is origin's ref state, not a log of commands that happened to run:
# a stub can be fooled by a push nobody logged, a bare repo cannot. Each case
# gets its own repo + bare origin so the assertions never share state.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="$ROOT/release.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Keep the operator's real git identity, hooks, and signing config out of the
# temp repos; they would otherwise fail the commits on some machines.
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
: > "$GIT_CONFIG_GLOBAL"

echo "SMOKE: release.sh pull_request mode"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Builds an isolated repo + bare origin whose contract declares the given mode.
make_case() {
  local name="$1" mode="$2"
  local repo="$WORK/$name/repo" origin="$WORK/$name/origin.git"

  mkdir -p "$repo/.mq"
  git init --quiet --bare "$origin"
  git init --quiet "$repo"
  git -C "$repo" symbolic-ref HEAD refs/heads/main
  git -C "$repo" config user.email "smoke@example.invalid"
  git -C "$repo" config user.name "Release Smoke"
  git -C "$repo" config commit.gpgsign false

  cp "$RELEASE" "$repo/release.sh"
  printf '1.0.0\n' > "$repo/VERSION"
  printf '# Smoke\n\n![version](https://img.shields.io/badge/version-1.0.0-blue)\n' \
    > "$repo/README.md"
  printf '# Changelog\n\n## [9.9.9] - 2026-01-01\n\n### Added\n\n- smoke\n\n## [1.0.0] - 2025-01-01\n\n### Added\n\n- init\n' \
    > "$repo/CHANGELOG.md"
  python3 - "$repo/.mq/repo-contract.json" "$mode" <<'PY'
import json
import sys

path, mode = sys.argv[1], sys.argv[2]
doc = {
    "schema": "mq-stack-repo-contract.pointer.v1",
    "repo": "smoke",
    "version": "1.0.0",
    "release_mode": mode,
}
with open(path, "w") as handle:
    json.dump(doc, handle, indent=2)
    handle.write("\n")
PY

  git -C "$repo" add -A
  git -C "$repo" commit --quiet -m "init"
  git -C "$repo" remote add origin "$origin"
  git -C "$repo" push --quiet -u origin main
}

# A gh that records its arguments instead of reaching GitHub.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
exit 0
STUB
chmod +x "$WORK/bin/gh"

run_release() {
  local repo="$1"
  shift
  (
    cd "$repo"
    PATH="$WORK/bin:$PATH" GH_LOG="$GH_LOG" bash release.sh "$@"
  )
}

echo "[1/5] the direct-push line exists only inside push_release()"
# `direct` stays a supported mode, so the string is allowed to exist — but only
# in the one function the direct path calls. A copy of it anywhere else is the
# regression this catches.
occurrences="$(grep -c 'push origin main' "$RELEASE" || true)"
[[ "$occurrences" -le 1 ]] \
  || fail "'push origin main' appears $occurrences times in release.sh; expected at most 1"
in_function="$(awk '/^push_release\(\) \{/{f=1} f&&/push origin main/{c++} f&&/^\}/{f=0} END{print c+0}' "$RELEASE")"
[[ "$in_function" -eq "$occurrences" ]] \
  || fail "'push origin main' occurs outside push_release() in release.sh"
grep -Fq 'release_mode' "$RELEASE" \
  || fail "release.sh never reads release_mode from the contract"

echo "[2/5] pull_request mode pushes a release branch and never touches main"
make_case pr pull_request
GH_LOG="$WORK/pr/gh.log"
: > "$GH_LOG"
PR_REPO="$WORK/pr/repo"
PR_ORIGIN="$WORK/pr/origin.git"
main_before="$(git -C "$PR_ORIGIN" rev-parse refs/heads/main)"

run_release "$PR_REPO" 9.9.9 > "$WORK/pr/out.log" 2>&1 || {
  cat "$WORK/pr/out.log" >&2
  fail "release.sh 9.9.9 exited non-zero in pull_request mode"
}

main_after="$(git -C "$PR_ORIGIN" rev-parse refs/heads/main)"
[[ "$main_before" == "$main_after" ]] \
  || fail "origin main moved in pull_request mode ($main_before -> $main_after)"
git -C "$PR_ORIGIN" rev-parse --verify -q refs/heads/release/v9.9.9 >/dev/null \
  || fail "origin is missing refs/heads/release/v9.9.9"
[[ -z "$(git -C "$PR_ORIGIN" tag --list 'v9.9.9')" ]] \
  || fail "pull_request mode pushed tag v9.9.9 to origin"
[[ -z "$(git -C "$PR_REPO" tag --list 'v9.9.9')" ]] \
  || fail "pull_request mode created a local tag v9.9.9"
[[ "$(git -C "$PR_REPO" branch --show-current)" == "main" ]] \
  || fail "checkout was left off main: $(git -C "$PR_REPO" branch --show-current)"
[[ -z "$(git -C "$PR_REPO" status --porcelain)" ]] \
  || fail "pull_request mode left the working tree dirty"

# The bump has to actually be on the pushed branch, or the PR is empty.
pushed_version="$(git -C "$PR_ORIGIN" show refs/heads/release/v9.9.9:VERSION)"
[[ "$pushed_version" == "9.9.9" ]] \
  || fail "pushed branch carries VERSION '$pushed_version', expected 9.9.9"
pushed_contract="$(git -C "$PR_ORIGIN" show refs/heads/release/v9.9.9:.mq/repo-contract.json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
[[ "$pushed_contract" == "9.9.9" ]] \
  || fail "pushed branch carries contract version '$pushed_contract', expected 9.9.9"
grep -q 'pr create' "$GH_LOG" \
  || fail "gh pr create was never invoked"

echo "[3/5] dry-run leaves no branch, no commit, and a clean tree"
make_case dry pull_request
GH_LOG="$WORK/dry/gh.log"
: > "$GH_LOG"
DRY_REPO="$WORK/dry/repo"
DRY_ORIGIN="$WORK/dry/origin.git"
dry_main_before="$(git -C "$DRY_ORIGIN" rev-parse refs/heads/main)"
dry_head_before="$(git -C "$DRY_REPO" rev-parse HEAD)"

run_release "$DRY_REPO" --dry-run 9.9.9 > "$WORK/dry/out.log" 2>&1 || {
  cat "$WORK/dry/out.log" >&2
  fail "release.sh --dry-run exited non-zero in pull_request mode"
}

[[ "$(git -C "$DRY_REPO" rev-parse HEAD)" == "$dry_head_before" ]] \
  || fail "dry-run created a commit"
[[ "$(git -C "$DRY_ORIGIN" rev-parse refs/heads/main)" == "$dry_main_before" ]] \
  || fail "dry-run moved origin main"
[[ "$(git -C "$DRY_REPO" for-each-ref --format='%(refname:short)' refs/heads/)" == "main" ]] \
  || fail "dry-run left extra local branches: $(git -C "$DRY_REPO" for-each-ref --format='%(refname:short)' refs/heads/ | tr '\n' ' ')"
[[ -z "$(git -C "$DRY_ORIGIN" for-each-ref refs/heads/release/)" ]] \
  || fail "dry-run pushed a release branch"
[[ -z "$(git -C "$DRY_REPO" status --porcelain)" ]] \
  || fail "dry-run left the working tree dirty"
[[ -z "$(cat "$GH_LOG")" ]] \
  || fail "dry-run invoked gh: $(cat "$GH_LOG")"

echo "[4/5] direct mode still releases the old way when the contract asks for it"
make_case direct direct
GH_LOG="$WORK/direct/gh.log"
: > "$GH_LOG"
DIRECT_REPO="$WORK/direct/repo"
DIRECT_ORIGIN="$WORK/direct/origin.git"
direct_main_before="$(git -C "$DIRECT_ORIGIN" rev-parse refs/heads/main)"

run_release "$DIRECT_REPO" 9.9.9 > "$WORK/direct/out.log" 2>&1 || {
  cat "$WORK/direct/out.log" >&2
  fail "release.sh 9.9.9 exited non-zero in direct mode"
}

[[ "$(git -C "$DIRECT_ORIGIN" rev-parse refs/heads/main)" != "$direct_main_before" ]] \
  || fail "direct mode did not advance origin main"
git -C "$DIRECT_ORIGIN" rev-parse --verify -q refs/tags/v9.9.9 >/dev/null \
  || fail "direct mode did not push tag v9.9.9"
[[ -z "$(git -C "$DIRECT_ORIGIN" for-each-ref refs/heads/release/)" ]] \
  || fail "direct mode pushed a release branch"

echo "[5/5] a failed gate rewinds the branch, the bump, and the checkout"
# The gates `exit` rather than failing a command, and bash does not run an ERR
# trap for that — so the rollback the usage text promises never fired, and the
# checkout would now be stranded on the release branch as well. 8.8.8 has no
# CHANGELOG section, which is the gate that trips after the branch was cut.
make_case gate pull_request
GH_LOG="$WORK/gate/gh.log"
: > "$GH_LOG"
GATE_REPO="$WORK/gate/repo"
GATE_ORIGIN="$WORK/gate/origin.git"
gate_main_before="$(git -C "$GATE_ORIGIN" rev-parse refs/heads/main)"

set +e
run_release "$GATE_REPO" 8.8.8 > "$WORK/gate/out.log" 2>&1
gate_status=$?
set -e

[[ "$gate_status" -ne 0 ]] \
  || fail "release.sh accepted version 8.8.8, which has no CHANGELOG section"
[[ -z "$(git -C "$GATE_REPO" status --porcelain)" ]] \
  || fail "failed gate left the bumped files behind: $(git -C "$GATE_REPO" status --porcelain | tr '\n' ' ')"
[[ "$(git -C "$GATE_REPO" branch --show-current)" == "main" ]] \
  || fail "failed gate stranded the checkout on $(git -C "$GATE_REPO" branch --show-current)"
[[ "$(git -C "$GATE_REPO" for-each-ref --format='%(refname:short)' refs/heads/)" == "main" ]] \
  || fail "failed gate left a release branch behind"
[[ "$(git -C "$GATE_ORIGIN" rev-parse refs/heads/main)" == "$gate_main_before" ]] \
  || fail "failed gate moved origin main"

bash -n "$0"
echo "OK: pull_request mode never pushes main; direct mode still works"
