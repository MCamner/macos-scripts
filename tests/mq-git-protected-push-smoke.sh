#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_MENU="$ROOT/terminal/launchers/gitlaunch.sh"
GIT_MENU="$ROOT/terminal/menus/mq-git-menu.sh"
DOCS="$ROOT/docs/COMMANDS.md"

zsh -n "$LEGACY_MENU"
bash -n "$GIT_MENU"

grep -Fq "pr_aware_push" "$LEGACY_MENU"
grep -Fq "pr_aware_push" "$GIT_MENU"
grep -Fq "GH013" "$LEGACY_MENU"
grep -Fq "GH013" "$GIT_MENU"
grep -Fq "MQLAUNCH_PROTECTED_BRANCHES" "$LEGACY_MENU"
grep -Fq "MQLAUNCH_PROTECTED_BRANCHES" "$GIT_MENU"
grep -Fq "run_ai_commit" "$LEGACY_MENU"
grep -Fq "pause_git_menu" "$LEGACY_MENU"
grep -Fq "run_ai_commit" "$LEGACY_MENU" && grep -Fq "continue" "$LEGACY_MENU"
grep -Fq "PR branch" "$DOCS"

echo "mq git protected-push smoke OK"
