#!/usr/bin/env bash
# mqlaunch git & release menu launchers.
#
# Extracted from terminal/launchers/mqlaunch.sh as part of Step 11a (monolith
# de-layering, audit P4). Both functions launch an external menu script
# (gitlaunch.sh / mq-release-menu.sh) and invalidate the cached dashboard header
# on return, since a commit/stash/tag makes the cached Git status stale. Sourced
# into the launcher's scope, so it relies on the launcher's ambient UI helpers
# (print_header/row/empty_row/print_footer/pause_enter) and $BASE_DIR, and on
# mq_dashboard_cache_invalidate / release_menu_loop when present (both guarded
# with command -v). No behavior change — the functions are verbatim moves. Pure
# bash, so it carries a bash shebang and is covered by shellcheck.

# Opens git menu.
open_git_menu() {
  local repo_arg="${1:-}"
  local git_script="$BASE_DIR/terminal/launchers/gitlaunch.sh"
  local git_path="" back_marker restart_count

  if [[ -n "$repo_arg" ]]; then
    git_path="$repo_arg"
  else
    git_path="$(pwd)"
  fi

  if [[ ! -x "$git_script" && ! -f "$git_script" ]]; then
    print_header
    row "GIT MENU"
    empty_row
    row "Git menu not found:"
    row " $git_script"
    print_footer
    pause_enter
    return
  fi

  back_marker="/tmp/mq-gitlaunch-back.$$"
  restart_count=0

  while true; do
    rm -f "$back_marker" 2>/dev/null || true

    if [[ -x "$git_script" ]]; then
      MQ_GIT_REPO="$git_path" MQ_GITLAUNCH_BACK_MARKER="$back_marker" "$git_script"
    else
      MQ_GIT_REPO="$git_path" MQ_GITLAUNCH_BACK_MARKER="$back_marker" zsh "$git_script"
    fi

    [[ -f "$back_marker" ]] && break

    # Without a terminal gitlaunch renders once and returns without setting the
    # back marker. That is a clean exit, not the crash the restart counter is
    # for, so restarting it five times only reprints the menu five times.
    if [[ -n "${MQ_NO_TUI:-}" || ! -t 0 || ! -t 1 ]]; then
      break
    fi

    restart_count=$(( restart_count + 1 ))
    if [[ "$restart_count" -ge 5 ]]; then
      printf "Gitlaunch exited unexpectedly %d times; returning to mqlaunch.\n" "$restart_count"
      sleep 1
      break
    fi
  done

  rm -f "$back_marker" 2>/dev/null || true

  # The git menu can commit/stash, so the cached dashboard header is now stale.
  # Drop it so the main loop re-renders fresh Git status instead of waiting out
  # the cache TTL.
  command -v mq_dashboard_cache_invalidate >/dev/null 2>&1 && mq_dashboard_cache_invalidate
}

# Opens release menu.
open_release_menu() {
  local release_menu="$BASE_DIR/terminal/menus/mq-release-menu.sh"

  if command -v release_menu_loop >/dev/null 2>&1; then
    MQ_USE_DASHBOARD_HEADER=1 release_menu_loop
  elif [[ -x "$release_menu" ]]; then
    MQ_USE_DASHBOARD_HEADER=1 "$release_menu" menu
  elif [[ -f "$release_menu" ]]; then
    chmod +x "$release_menu" 2>/dev/null || true
    MQ_USE_DASHBOARD_HEADER=1 bash "$release_menu" menu
  else
    print_header
    row "RELEASE MENU"
    empty_row
    row "Release menu not found:"
    row " $release_menu"
    print_footer
    pause_enter
  fi

  # The release flow can commit/tag, so invalidate the cached dashboard header
  # before returning to the main loop.
  command -v mq_dashboard_cache_invalidate >/dev/null 2>&1 && mq_dashboard_cache_invalidate
}
