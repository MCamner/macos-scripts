#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGE_SCRIPT="$ROOT/terminal/launchers/gitmerge-safe.sh"
GITLAUNCH="$ROOT/terminal/launchers/gitlaunch.sh"
COMMANDS="$ROOT/docs/COMMANDS.md"
SAFETY_DOC="$ROOT/docs/safety/gitmerge-safe.md"
COMMAND_SURFACE="$ROOT/docs/architecture/COMMAND_SURFACE.md"

echo "SMOKE: gitmerge-safe safety contract"

echo "[1/9] files exist"
test -x "$MERGE_SCRIPT"
test -f "$GITLAUNCH"
test -f "$SAFETY_DOC"

echo "[2/9] shell syntax"
bash -n "$MERGE_SCRIPT"

echo "[3/9] clean tree gate exists"
grep -q 'git status --porcelain' "$MERGE_SCRIPT"
grep -q 'Working tree is not clean' "$MERGE_SCRIPT"

echo "[4/9] detached HEAD gate exists"
grep -q 'Detached HEAD is not supported' "$MERGE_SCRIPT"

echo "[5/9] commit preview and explicit confirmation exist"
grep -q 'Commits that would come in' "$MERGE_SCRIPT"
grep -q 'Proceed with merge? \[y/N\]' "$MERGE_SCRIPT"

echo "[6/9] merge is local only"
grep -q 'git merge --ff-only' "$MERGE_SCRIPT"
grep -q 'git merge --no-ff' "$MERGE_SCRIPT"
grep -q 'No push was performed' "$MERGE_SCRIPT"
if grep -qE 'git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+merge|gh[[:space:]]+api|curl[[:space:]]' "$MERGE_SCRIPT"; then
  echo "gitmerge-safe contains remote write behavior" >&2
  exit 1
fi

echo "[7/9] gitlaunch routes to safe-merge helper"
grep -q 'function safe_merge' "$GITLAUNCH"
grep -q 'gitmerge-safe.sh' "$GITLAUNCH"
grep -q 'Safe merge' "$GITLAUNCH"

echo "[8/9] docs classify safe merge as Class C"
grep -q 'Class C' "$COMMANDS"
grep -q 'explicit confirmation' "$COMMANDS"
grep -q 'no push' "$COMMANDS"
grep -q 'Class C local mutating action' "$SAFETY_DOC"
grep -q 'gitmerge-safe.md' "$COMMAND_SURFACE"

echo "[9/9] non-interactive execution is refused"
tmpdir="$(mktemp -d)"
(
  cd "$tmpdir"
  git init -q
  git config user.email smoke@example.invalid
  git config user.name Smoke
  printf 'base\n' > file.txt
  git add file.txt
  git commit -qm base
  "$MERGE_SCRIPT" >/tmp/gitmerge-safe-smoke.out 2>&1 && exit 1
  grep -q 'interactive terminal' /tmp/gitmerge-safe-smoke.out
)

echo "OK: gitmerge-safe safety contract passed"
