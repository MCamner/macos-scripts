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
# the clamp instead. What matters here is only that gitlaunch still resizes.
grep -Fq "update_ui_width" "$LEGACY_MENU"
grep -Fq "surface_terminal_width" "$LEGACY_MENU"
grep -Fq "refresh_git_counters" "$LEGACY_MENU"
# Which number the row carries is not this file's business, and pinning it is
# the same mistake as the width literals above: the menu regrouped, Recent log
# moved from 9 to 6, and an assertion about the panel's layout failed for a
# change that kept every capability. What matters here is that the row exists
# and reaches the handler.
grep -Eq '"[0-9]+\. Recent log"' "$LEGACY_MENU"
grep -Fq "show_recent_log" "$LEGACY_MENU"
grep -Fq "Staged:" "$LEGACY_MENU"
grep -Fq "if [[ -t 0 && -t 1 ]]" "$LEGACY_MENU"
grep -Fq "PR branch" "$DOCS"

# gitlaunch runs under zsh, where `status` is a read-only special parameter.
# Exercise the successful, non-protected push path: assigning a local named
# `status` terminates the submenu after a commit and returns to the main menu.
{
  sed -n '/^function pr_aware_push()/,/^}/p' "$LEGACY_MENU"
  cat <<'ZSH_TEST'
function is_protected_branch() { return 1; }
function git() {
  case "$1" in
    branch) print -r -- "test/menu-loop" ;;
    push) print -r -- "local push ok" ;;
    *) return 1 ;;
  esac
}

pr_aware_push "menu loop regression"
ZSH_TEST
} | zsh >/dev/null

echo "mq git protected-push smoke OK"
