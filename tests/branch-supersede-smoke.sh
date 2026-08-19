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

echo "[1/8] unrelated histories are a lookup error, never a verdict"
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

echo "[2/8] content that landed by another route is superseded"
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

echo "[3/8] a branch holding unique content is never superseded"
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

echo "[4/8] a file the branch deleted is not content the branch holds"
new_repo "$TMP/deleted"
printf 'doomed\n' > "$TMP/deleted/doomed.txt"
git -C "$TMP/deleted" add doomed.txt
commit "$TMP/deleted" "add the file both sides later drop"
git -C "$TMP/deleted" checkout -q -b dropper
git -C "$TMP/deleted" rm -q doomed.txt
commit "$TMP/deleted" "drop it on the branch"
git -C "$TMP/deleted" checkout -q main
git -C "$TMP/deleted" rm -q doomed.txt
commit "$TMP/deleted" "drop it on trunk too"

out="$("$REPORT" dropper --repo "$TMP/deleted" --no-pr 2>&1)"
status=$?
grep -q 'ONLY-ON-BRANCH  doomed.txt' <<< "$out" \
  && fail "a deletion is reported as content only the branch has: $out"
[[ "$status" -eq 0 ]] \
  || fail "a branch holding only a deletion trunk already made exited $status, expected 0: $out"

echo "[5/8] an unknown ref is a usage error"
out="$("$REPORT" no-such-branch --repo "$TMP/unique" --no-pr 2>&1)"
status=$?
[[ "$status" -eq 2 ]] || fail "unknown ref exited $status, expected 2"

echo "[6/8] the PR lookup asks GitHub for the branch, not for a page of PRs"
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

echo "[7/8] a lookup failure is not silently read as 'no merged PR'"
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

echo "[8/8] a git warning is not read as a filename"
# Criss-cross merge: main and feat each merge the other's pre-merge tip, which
# leaves TWO merge bases. `git diff main...feat` then warns — on a run that
# succeeds. Capturing stderr into the file list made that warning a path: it was
# counted in the total and printed as a phantom GONE-FROM-BOTH row, because no
# such file exists on either side.
CC="$TMP/crisscross"
new_repo "$CC"
git -C "$CC" checkout -q -b feat
printf 'feat\n' > "$CC/feat.txt"
git -C "$CC" add feat.txt
commit "$CC" "feat work"
git -C "$CC" checkout -q main
printf 'main\n' > "$CC/main.txt"
git -C "$CC" add main.txt
commit "$CC" "main work"
main_tip="$(git -C "$CC" rev-parse main)"
git -C "$CC" -c user.email=test@example.invalid -c user.name=Test \
  merge -q --no-ff -m "main merges feat" feat
git -C "$CC" checkout -q feat
git -C "$CC" -c user.email=test@example.invalid -c user.name=Test \
  merge -q --no-ff -m "feat merges main" "$main_tip"
printf 'extra\n' > "$CC/extra.txt"
git -C "$CC" add extra.txt
commit "$CC" "one real file only the branch has"
git -C "$CC" checkout -q main

bases="$(git -C "$CC" merge-base --all main feat | wc -l | tr -d ' ')"
[[ "$bases" -eq 2 ]] || fail "the fixture does not have two merge bases, got $bases"

out="$("$REPORT" feat --repo "$CC" --no-pr 2>&1)"
grep -q 'warning' <<< "$out" \
  || fail "the fixture did not make git warn, so this proves nothing: $out"
grep -qE '(IDENTICAL|GONE-FROM-BOTH|ONLY-ON-BRANCH|DIVERGED|BASE-AHEAD|BRANCH-AHEAD) +warning' <<< "$out" \
  && fail "a git warning was classified as a file: $out"
grep -q 'note: warning' <<< "$out" \
  || fail "the warning was swallowed instead of reported: $out"
# Two real files, not three: extra.txt and main.txt are in the three-dot diff
# against the chosen base, and the warning is not.
grep -q 'touches 2 file(s)' <<< "$out" \
  || fail "the warning is still inflating the file count: $out"
grep -q 'ONLY-ON-BRANCH  extra.txt' <<< "$out" \
  || fail "the real branch-only file was not classified: $out"
grep -q '(of 2)' <<< "$out" \
  || fail "the total counts something that is not a file: $out"

echo "OK  branch-supersede-check"
