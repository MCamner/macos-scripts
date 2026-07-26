#!/usr/bin/env bash
set -euo pipefail

# Menus must terminate when there is no terminal.
#
# `read_menu_choice` (ui/terminal-ui/mq-ui.sh:313) already returns 1 on EOF, on
# a non-TTY, and under MQ_NO_TUI. Three call sites acted on that return; twelve
# discarded it, set `choice=""`, fell through to the `*)` branch, printed
# "Invalid option", and looped. Forever.
#
# The cost was not a slow command, it was a command that never returns:
#
#   mqlaunch workflows </dev/null   → 733780 bytes, exit 124
#   mqlaunch system    </dev/null   → 638105 bytes, exit 124
#   mqlaunch git       </dev/null   →  45430 bytes, exit 124
#
# That is exactly the shape CI and agents invoke, and #73 is the tracking issue.
#
# Two assertions per command, because either alone is too weak. Terminating is
# not enough: a menu that renders itself two hundred times and then exits on a
# counter is still looping. Rendering once is not enough either, if the process
# then blocks. So: it must exit, and it must not have redrawn.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: menus terminate without a terminal"

# Everything that opens an mqlaunch-owned interactive surface, plus the ones
# that already exited cleanly — those are the regression half of the contract.
#
# Three distinct causes produced the same hang, so all three are covered here:
#   menu loops       discarded read_menu_choice's EOF signal
#   gitlaunch        read /dev/tty directly, so a closed stdin never reached it
#   fzf pickers      checked that fzf was installed, never that anyone was there
#
# Deliberately absent:
#   kill-process, kill-port, reap
#                    destructive. The guard makes them safe without a TTY, but a
#                    suite that runs a process killer to prove a guard works is
#                    one regression away from killing something.
#   b2tui            a Python TUI, not a shell menu.
MENUS=(
  "workflows"
  "workspace"
  "repos"
  "system"
  "release"
  "git"
  "docfunc"
  "dev"
  "perf"
  "demo"
  "palette"
  "obsidian"
  "ui"
  "mc"
  "github"
  "git-log"
  "git-branch"
  "snippets"
  "recent"
)

# A single rendered menu is a few kilobytes; `demo` is the widest at ~33 KB.
# A loop reaches hundreds of kilobytes within seconds, so this separates them
# by an order of magnitude rather than by a hair.
MAX_BYTES=60000
TIMEOUT=15

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

failures=0
for command in "${MENUS[@]}"; do
  set +e
  MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 NO_COLOR=1 \
    timeout "$TIMEOUT" bash "$LAUNCH" "$command" \
    >"$run_dir/out.log" 2>&1 </dev/null
  status=$?
  set -e
  bytes="$(wc -c <"$run_dir/out.log" | tr -d ' ')"

  if [[ "$status" -eq 124 ]]; then
    printf '  FAIL %-12s did not terminate (%s bytes in %ss)\n' \
      "$command" "$bytes" "$TIMEOUT" >&2
    failures=$(( failures + 1 ))
    continue
  fi
  if [[ "$bytes" -gt "$MAX_BYTES" ]]; then
    printf '  FAIL %-12s terminated but emitted %s bytes (limit %s) — still redrawing\n' \
      "$command" "$bytes" "$MAX_BYTES" >&2
    failures=$(( failures + 1 ))
    continue
  fi
  printf '  ok   %-12s exit=%-3s %7s bytes\n' "$command" "$status" "$bytes"
done

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL: $failures menu(s) do not terminate without a terminal" >&2
  exit 1
fi

echo "[structural] every read_menu_choice call site acts on its return value"
# The behavioural check above only covers menus reachable from a top-level
# command. A nested menu with the same defect would not be caught until someone
# navigated to it, so the pattern is held at the source too.
# Anchored to the start of the line so this matches calls, not the mentions of
# the name in comments, in the definition, or in this file's own grep.
unguarded="$(grep -rnE '^[[:space:]]*read_menu_choice[[:space:]]' --include="*.sh" "$ROOT" \
  | grep -v '\.bak' \
  | grep -vE '\|\||&&|return|break' \
  || true)"
if [[ -n "$unguarded" ]]; then
  echo "read_menu_choice call sites that discard the EOF signal:" >&2
  echo "$unguarded" >&2
  exit 1
fi
echo "  ok: no call site discards the EOF signal"

bash -n "$0"
echo "OK: menus terminate without a terminal"
