#!/usr/bin/env bash
# Holds the release gate's secrets scan to actually scanning something.
#
# The defect this file exists for: the scan read `gitleaks git --pre-commit
# --staged`, which inspects the staged set. A release check runs on a clean tree,
# so nothing was staged, the scan measured `0 commits scanned, scanned ~0 bytes`,
# and the gate printed a tick. It was not a wrong answer — it was no answer,
# reported as a pass. `command succeeded + empty output != clean`.
#
# Three properties, and the third is the one that decides the shape:
#
#   1. a secret in the published history is found
#   2. a repository without one is reported clean, and the scan says how much it
#      looked at — a pass that scanned nothing is the defect, not the fix
#   3. a secret in an ignored, untracked file does NOT fail the gate
#
# 3 is why this scans history rather than the working directory. `gitleaks dir`
# reads files git is told to ignore, so it fails on the untracked `.env` that
# most developer machines carry. A gate that cries wolf about a file which is
# correctly excluded is a gate people learn to skip.
#
# The secrets used below are generated locally, are random, and are never valid.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/terminal/release/mq-release-check.sh"

echo "SMOKE: release secret scan"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "SKIP: gitleaks is not installed"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# A synthetic token in a shape gitleaks recognises. Random, never valid, and
# built here rather than written into the file so the literal never sits in the
# repository this very gate scans.
fake_token() {
  printf 'ghp_%s' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"
}

new_repo() { # PATH
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name Test
  printf 'print("hello")\n' > "$1/app.py"
  git -C "$1" add app.py
  git -C "$1" commit -qm init
}

echo "[1/4] the gate scans history, not the staged set"
# Asserted against the script because the wrong invocation passes every
# behavioural test: it exits 0 on a clean repo and on a compromised one alike.
grep -q 'gitleaks git "\$BASE_DIR"' "$CHECK" \
  || fail "the secrets scan no longer scans the repository history"
# Comments are dropped first. The script explains the invocation it replaced,
# and prose about not doing something reads exactly like doing it to a grep —
# the same trap tests/pulse-menu-smoke.sh records for `tools/scripts/pulse.sh`.
if grep -nE -- '--pre-commit' "$CHECK" | grep -qv '^[0-9]*:#'; then
  fail "the staged-only scan is back — it measures nothing on a clean tree"
fi
echo "  ok: gitleaks git \$BASE_DIR, and no --pre-commit"

echo "[2/4] a secret in the published history is found"
dirty="$TMP/dirty"
new_repo "$dirty"
printf 'TOKEN = "%s"\n' "$(fake_token)" > "$dirty/config.py"
git -C "$dirty" add config.py
git -C "$dirty" commit -qm "add config"
if gitleaks git "$dirty" >/dev/null 2>&1; then
  fail "a committed secret was not detected — the gate cannot fail"
fi
echo "  ok: a committed secret fails the scan"

echo "[3/4] a clean repository passes, and the scan actually looked"
clean="$TMP/clean"
new_repo "$clean"
gitleaks git "$clean" >/dev/null 2>"$TMP/clean.err" \
  || fail "a clean repository was reported as leaking"
# The heart of the original defect. Passing is not enough: the run has to say it
# read something. `0 commits scanned` with a tick is exactly what was shipped.
scanned="$(sed -e 's/\x1b\[[0-9;]*m//g' "$TMP/clean.err" \
  | sed -n 's/.*INF \([0-9][0-9]*\) commits scanned.*/\1/p' | tail -1)"
[[ -n "$scanned" ]] || fail "the scan did not report how many commits it read"
[[ "$scanned" -gt 0 ]] \
  || fail "the scan passed after reading $scanned commits — that is the defect"
echo "  ok: clean, and it reported reading $scanned commit(s)"

echo "[4/4] a secret in an ignored, untracked file does not fail the gate"
# The false positive that would train an operator to ignore this gate. `.env` is
# local, gitignored, and never published; a release gate that fails on it is
# reporting about a file the release does not contain.
ignored="$TMP/ignored"
new_repo "$ignored"
printf '.env\n' > "$ignored/.gitignore"
git -C "$ignored" add .gitignore
git -C "$ignored" commit -qm "ignore env"
printf 'OPENAI_API_KEY=%s\n' "$(fake_token)" > "$ignored/.env"
gitleaks git "$ignored" >/dev/null 2>&1 \
  || fail "an ignored, untracked .env failed the release gate"
# And prove the file really does hold something a scanner would flag, so this
# step cannot pass because the fixture was empty.
gitleaks dir "$ignored" >/dev/null 2>&1 \
  && fail "the fixture secret is not detectable — step 4 proves nothing"
echo "  ok: history is clean while the ignored file is not, and the gate passes"

echo "OK: release secret scan smoke test passed"
