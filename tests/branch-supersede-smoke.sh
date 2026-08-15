#!/usr/bin/env bash
set -uo pipefail

# Gates the branch-supersede-check script. The verdict this tool prints is
# acted on by deleting a branch, so the failure that matters is not a wrong
# label on one file — it is answering "superseded" when the comparison never
# ran. A failed comparison produces empty output, and empty output counted as
# zero unique files reads exactly like a branch whose work already landed.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$ROOT/skills/branch-supersede-check/scripts/supersede-report.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

commit() { # REPO MESSAGE
  git -C "$1" -c user.email=test@example.invalid -c user.name=Test \
    commit -q -m "$2"
}

new_repo() { # PATH
  git init -q -b main "$1"
  printf 'shared\n' > "$1/shared.txt"
  git -C "$1" add shared.txt
  commit "$1" "initial"
}

echo "[1/6] unrelated histories are a lookup error, never a verdict"
new_repo "$TMP/unrelated"
git -C "$TMP/unrelated" checkout -q --orphan lonely
git -C "$TMP/unrelated" rm -rqf .
printf 'only here\n' > "$TMP/unrelated/orphan.txt"
git -C "$TMP/unrelated" add orphan.txt
commit "$TMP/unrelated" "orphan work"
git -C "$TMP/unrelated" checkout -q main

out="$("$REPORT" lonely --repo "$TMP/unrelated" --no-pr 2>&1)"
status=$?
[[ "$status" -eq 2 ]] || fail "unrelated histories exited $status, expected 2"
grep -qi 'superseded' <<< "$out" \
  && fail "unrelated histories reported a verdict: $out"
grep -qi 'merge base' <<< "$out" \
  || fail "the error does not name the missing merge base: $out"

echo "[2/6] content that landed by another route is superseded"
new_repo "$TMP/landed"
git -C "$TMP/landed" checkout -q -b feature
printf 'feature\n' > "$TMP/landed/feature.txt"
git -C "$TMP/landed" add feature.txt
commit "$TMP/landed" "add feature"
git -C "$TMP/landed" checkout -q main
# Same content, different commit — the squash-merge shape.
printf 'feature\n' > "$TMP/landed/feature.txt"
git -C "$TMP/landed" add feature.txt
commit "$TMP/landed" "add feature, squashed"

out="$("$REPORT" feature --repo "$TMP/landed" --no-pr 2>&1)"
status=$?
[[ "$status" -eq 0 ]] || fail "landed branch exited $status, expected 0: $out"
grep -q 'VERDICT: superseded' <<< "$out" || fail "no superseded verdict: $out"
grep -q 'IDENTICAL       feature.txt' <<< "$out" || fail "file not identical: $out"

echo "[3/6] a branch holding unique content is never superseded"
new_repo "$TMP/unique"
git -C "$TMP/unique" checkout -q -b keeper
printf 'unique\n' > "$TMP/unique/keeper.txt"
git -C "$TMP/unique" add keeper.txt
commit "$TMP/unique" "work trunk never got"
git -C "$TMP/unique" checkout -q main

out="$("$REPORT" keeper --repo "$TMP/unique" --no-pr 2>&1)"
status=$?
[[ "$status" -eq 1 ]] || fail "unique branch exited $status, expected 1: $out"
grep -q 'ONLY-ON-BRANCH  keeper.txt' <<< "$out" || fail "file not flagged: $out"

echo "[4/6] an unknown ref is a usage error"
out="$("$REPORT" no-such-branch --repo "$TMP/unique" --no-pr 2>&1)"
status=$?
[[ "$status" -eq 2 ]] || fail "unknown ref exited $status, expected 2"

echo "[5/6] the PR lookup asks GitHub for the branch, not for a page of PRs"
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_ARGS_LOG"
printf '#42 merged 2026-01-01\n'
STUB
chmod +x "$TMP/bin/gh"
export GH_ARGS_LOG="$TMP/gh-args.log"
: > "$GH_ARGS_LOG"

out="$(PATH="$TMP/bin:$PATH" "$REPORT" keeper --repo "$TMP/unique" 2>&1)"
args="$(cat "$GH_ARGS_LOG")"
[[ -n "$args" ]] || fail "the PR lookup never ran"
grep -q -- '--head keeper' <<< "$args" \
  || fail "the lookup does not filter server-side by head branch: $args"
grep -q -- '--limit 200' <<< "$args" \
  && fail "the lookup still pages through a capped list: $args"
grep -q 'merged PR for this head' <<< "$out" \
  || fail "a merged PR was found but not reported: $out"

echo "[6/6] a lookup failure is not silently read as 'no merged PR'"
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf 'gh: could not authenticate\n' >&2
exit 1
STUB
out="$(PATH="$TMP/bin:$PATH" "$REPORT" keeper --repo "$TMP/unique" 2>&1)"
status=$?
[[ "$status" -eq 1 ]] || fail "a gh failure changed the verdict, exit $status: $out"
grep -qi 'could not check' <<< "$out" \
  || fail "the failed lookup is not reported at all: $out"

echo "OK  branch-supersede-check"
