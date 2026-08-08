#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGE_SCRIPT="$ROOT/terminal/launchers/gitmerge-safe.sh"
GITLAUNCH="$ROOT/terminal/launchers/gitlaunch.sh"
COMMANDS="$ROOT/docs/COMMANDS.md"
SAFETY_DOC="$ROOT/docs/safety/gitmerge-safe.md"
COMMAND_SURFACE="$ROOT/docs/architecture/COMMAND_SURFACE.md"

echo "SMOKE: gitmerge-safe safety contract"

echo "[1/10] files exist"
test -x "$MERGE_SCRIPT"
test -f "$GITLAUNCH"
test -f "$SAFETY_DOC"

echo "[2/10] shell syntax"
bash -n "$MERGE_SCRIPT"

echo "[3/10] clean tree gate exists"
grep -q 'git status --porcelain' "$MERGE_SCRIPT"
grep -q 'Working tree is not clean' "$MERGE_SCRIPT"

echo "[4/10] detached HEAD gate exists"
grep -q 'Detached HEAD is not supported' "$MERGE_SCRIPT"

echo "[5/10] commit preview and explicit confirmation exist"
grep -q 'Commits that would come in' "$MERGE_SCRIPT"
grep -q 'Proceed with merge? \[y/N\]' "$MERGE_SCRIPT"

echo "[6/10] merge is local only"
grep -q 'git merge --ff-only' "$MERGE_SCRIPT"
grep -q 'git merge --no-ff' "$MERGE_SCRIPT"
grep -q 'No push was performed' "$MERGE_SCRIPT"
if grep -qE 'git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+merge|gh[[:space:]]+api|curl[[:space:]]' "$MERGE_SCRIPT"; then
  echo "gitmerge-safe contains remote write behavior" >&2
  exit 1
fi

echo "[7/10] gitlaunch routes to safe-merge helper"
grep -q 'function safe_merge' "$GITLAUNCH"
grep -q 'gitmerge-safe.sh' "$GITLAUNCH"
grep -q 'Safe merge' "$GITLAUNCH"

echo "[8/10] docs classify safe merge as Class C"
grep -q 'Class C' "$COMMANDS"
grep -q 'explicit confirmation' "$COMMANDS"
grep -q 'no push' "$COMMANDS"
grep -q 'Class C local mutating action' "$SAFETY_DOC"
grep -q 'gitmerge-safe.md' "$COMMAND_SURFACE"

echo "[9/10] non-interactive execution is refused"
tmpdir="$(mktemp -d)"
(
  cd "$tmpdir"
  git init -q
  git config user.email smoke@example.invalid
  git config user.name Smoke
  printf 'base\n' > file.txt
  git add file.txt
  git commit -qm base
  # stdin must be redirected explicitly, not inherited. The gate is [[ -t 0 ]],
  # so this step only proved anything when the suite happened to run without a
  # TTY. Run from mqlaunch's SELF-CHECK in a real terminal the gate correctly
  # passed, the script walked on to "No candidate branches found to merge", and
  # the assertion below failed against a script that was behaving properly.
  out="$(mktemp)"
  "$MERGE_SCRIPT" </dev/null >"$out" 2>&1 && exit 1
  grep -q 'interactive terminal' "$out"
  rm -f "$out"
)

echo "[10/10] TTY gate precedes network fetch"
tty_line="$(grep -n 'interactive terminal' "$MERGE_SCRIPT" | head -1 | cut -d: -f1)"
fetch_line="$(grep -n 'git fetch --prune origin' "$MERGE_SCRIPT" | head -1 | cut -d: -f1)"
if [ -z "$tty_line" ] || [ -z "$fetch_line" ]; then
  echo "could not locate TTY gate and/or fetch in $MERGE_SCRIPT" >&2
  exit 1
fi
if (( tty_line > fetch_line )); then
  echo "TTY gate (line $tty_line) must precede git fetch (line $fetch_line)" >&2
  exit 1
fi

echo "OK: gitmerge-safe safety contract passed"
