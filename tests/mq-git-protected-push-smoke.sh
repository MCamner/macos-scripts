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
# The second half of this line used to be `grep -Fq "continue"`. The word does
# not appear in gitlaunch.sh and does not appear in any commit reachable from
# HEAD, so the assertion could only ever fail — which nobody noticed, because
# this file was never listed in tools/scripts/test-all.sh. It is now, so a
# dead assertion has to go rather than be carried forward.
grep -Fq "mark_gitlaunch_back" "$LEGACY_MENU"
grep -Fq "BACK_MARKER" "$LEGACY_MENU"
grep -Fq "MQ_GITLAUNCH_BACK_MARKER" "$LEGACY_MENU"
# Width detection moved to ui/terminal-ui/terminal-width.sh, shared with the
# bash menus. The four assertions that used to stand here named the function
# and grepped the literals "width > 112" and "width < 60" — pinning the
# implementation rather than the behaviour, which passes for code that never
# runs and fails for a correct refactor. tests/terminal-width-smoke.sh drives
# the clamp and caller policy instead. What matters here is only that
# gitlaunch still refreshes its dimensions.
grep -Fq "update_ui_width" "$LEGACY_MENU"
grep -Fq "refresh_git_counters" "$LEGACY_MENU"
grep -Fq "9. Recent log" "$LEGACY_MENU"
grep -Fq "show_recent_log" "$LEGACY_MENU"
grep -Fq "Staged:" "$LEGACY_MENU"
grep -Fq "if [[ -t 0 && -t 1 ]]" "$LEGACY_MENU"
grep -Fq "PR branch" "$DOCS"

echo "mq git protected-push smoke OK"
