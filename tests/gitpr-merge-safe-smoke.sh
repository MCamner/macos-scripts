#!/usr/bin/env bash
# gitpr-merge-safe.sh closes a remote PR. Until now it had no coverage at all —
# gitmerge-safe-smoke.sh tests the local-merge sibling, not this one.
#
# Two things are pinned here. The guardrails, because this is the one script in
# the repo that can change a remote branch: no TTY means no merge, and the
# final confirmation must be answerable with "no". And the shape of the plan
# fetch, because the reason for touching this file was a wait: reading nine PR
# fields took nine `gh pr view` calls, 3.44s measured, all of it silent. One
# batched call measured 0.47s. A spinner makes a wait legible; not making the
# wait is better, so the batching is the fix and the spinner covers what is
# left.
#
# The fake gh records every invocation, so "one call, not nine" is asserted
# against behaviour rather than against how the source happens to read.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/terminal/launchers/gitpr-merge-safe.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "SMOKE: gitpr-merge-safe"

echo "[1/6] the script exists and parses"
test -x "$SCRIPT"
bash -n "$SCRIPT"

echo "[2/6] it refuses to merge without a TTY"
out="$(cd "$ROOT" && "$SCRIPT" 999 squash </dev/null 2>&1 || true)"
grep -q "interactive terminal" <<<"$out"

# A throwaway repo and a fake gh, so nothing here can reach GitHub.
REPO="$TMP/repo"
mkdir -p "$REPO" "$TMP/bin"
git -C "$REPO" init -q
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$REPO" branch -M feature-x

export GH_CALLS="$TMP/gh-calls"
: >"$GH_CALLS"

cat >"$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_CALLS"
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr checks")   echo "build  pass  10s"; exit 0 ;;
  "pr view")
    # One batched read: every field the merge plan needs, joined on U+001F.
    # reviewDecision is deliberately empty — that is the ordinary case (nobody
    # reviewed it) and the one a tab-separated read would silently shift.
    printf 'Add a thing\037OPEN\037false\037main\037feature-x\037MERGEABLE\037CLEAN\037\037https://example/pr/42\n'
    exit 0
    ;;
esac
exit 0
STUB
chmod +x "$TMP/bin/gh"

# Answers the one confirmation with "n", so no merge is ever attempted.
run_plan() {
  PATH="$TMP/bin:$PATH" GH_CALLS="$GH_CALLS" python3 - "$SCRIPT" "$REPO" <<'PY'
import os, pty, re, select, sys

# pty.spawn's stdin_read callback fires whenever the master is writable, which
# floods the script with answers. Drive it manually and reply only to an actual
# prompt, so the transcript is the script's output and nothing else.
script, repo = sys.argv[1], sys.argv[2]
os.chdir(repo)
PROMPT = re.compile(rb"\[y/N\]:\s*$", re.IGNORECASE)

pid, fd = pty.fork()
if pid == 0:
    os.execv("/bin/bash", ["bash", script, "42", "squash"])

seen, pending = bytearray(), bytearray()
while True:
    if not select.select([fd], [], [], 30)[0]:
        break
    try:
        chunk = os.read(fd, 1024)
    except OSError:
        break
    if not chunk:
        break
    seen.extend(chunk)
    pending.extend(chunk)
    if PROMPT.search(bytes(pending).rstrip()):
        os.write(fd, b"n\n")
        pending.clear()

os.waitpid(pid, 0)
sys.stdout.write(seen.decode(errors="replace"))
PY
}

echo "[3/6] the merge plan renders and the confirmation can be declined"
: >"$GH_CALLS"
out="$(run_plan 2>&1)"
grep -q "Merge plan" <<<"$out"
grep -q "Add a thing" <<<"$out"
grep -q "feature-x -> main" <<<"$out"
grep -q "Merge cancelled" <<<"$out"
# An empty reviewDecision must not drag the URL into its place.
grep -q "Review:   none" <<<"$out"
grep -q "URL:      https://example/pr/42" <<<"$out"

echo "[4/6] declining means no merge was ever attempted"
! grep -q "pr merge" "$GH_CALLS"

echo "[5/6] the plan costs one gh pr view, not one per field"
# Nine fields used to mean nine round trips. Anything above two here means the
# per-field pattern has come back.
views="$(grep -c "^pr view" "$GH_CALLS" || true)"
test "$views" -le 2 || {
  echo "FAIL: $views 'gh pr view' calls for one merge plan" >&2
  cat "$GH_CALLS" >&2
  exit 1
}

echo "[6/6] it still runs when the UI library is unreachable"
# The script is launched as its own process from the git menu, so it sources
# mq-ui.sh itself. A missing library must degrade to no spinner, not to a
# broken merge tool.
: >"$GH_CALLS"
out="$(MQ_UI_LIB="$TMP/does-not-exist.sh" run_plan 2>&1)"
grep -q "Merge plan" <<<"$out"
grep -q "Merge cancelled" <<<"$out"

echo "OK: gitpr-merge-safe smoke passed"
