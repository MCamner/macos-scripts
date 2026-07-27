#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-obsidian-menu.sh"
DOC="$ROOT/mqlaunch/docs/mqobsidian-consumer.md"
ROADMAP="$ROOT/ROADMAP.md"

echo "SMOKE: MQ Obsidian menu has no memory promotion path"

echo "[1/6] files exist"
test -f "$MENU"
test -f "$DOC"
test -f "$ROADMAP"

echo "[2/6] shell syntax"
bash -n "$MENU"

echo "[3/6] menu describes presentation/routing ownership"
grep -q "this menu owns presentation and routing only" "$MENU"
grep -q "mqobsidian and mq-agent own memory, context-pack, and learn logic" "$MENU"

echo "[4/6] triage is read-only and explicitly review-gated"
grep -q "mq_obsidian_triage_learning_inbox()" "$MENU"
grep -q "review gated" "$MENU"
grep -q "Read-only inbox inspection. No promote/reject action runs here." "$MENU"
grep -q "mq-agent must own" "$MENU"

echo "[5/6] menu contains no promotion or rejection command routes"
if grep -Eq '(^|[[:space:];|&])(mq-agent|mqlaunch|python3|bash|zsh)[[:space:]].*(promote|promotion|reject|learn[[:space:]]+promote|promote-from-review|resolve-supersede)' "$MENU"; then
  echo "MQ Obsidian menu appears to route promotion/rejection work" >&2
  exit 1
fi
if grep -Eq '(_run_agent[[:space:]].*(promote|reject)|learn[[:space:]]+promote|promote-from-review|resolve-supersede)' "$MENU"; then
  echo "MQ Obsidian menu appears to delegate promotion/rejection work" >&2
  exit 1
fi

echo "[6/6] docs and roadmap keep promotion outside mqlaunch"
grep -q "No writes to the vault. No scoring, promotion/downgrade, inbox or feedback-loop" "$DOC"
grep -q "Do not implement memory promotion in shell." "$ROADMAP"

echo "OK: MQ Obsidian menu no-promotion smoke test passed"
