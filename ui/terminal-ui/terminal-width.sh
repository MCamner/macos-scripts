#!/usr/bin/env bash
# Terminal width for the mqlaunch surface, shared by bash menus and the zsh
# gitlaunch launcher.
#
# This lived in two places — surface_terminal_width in mq-ui.sh and
# gitlaunch_terminal_width in gitlaunch.sh — with identical logic. Nested
# gitlaunch panels have to line up with the surface around them, so the two
# were never free to differ; keeping them apart only risked them drifting.
#
# Written for both shells: gitlaunch.sh is zsh, everything else is bash. That
# rules out `print -r --` (zsh-only) and any bashism; `printf`, `local`,
# `[[ =~ ]]` and `(( ))` behave the same in both.
#
# Sourced, not executed.

# Reports the usable terminal width, clamped to the surface's range.
#
# 112 keeps long lines readable on a wide terminal; 60 keeps the box from
# collapsing on a narrow one. tput is the source, not $COLUMNS: COLUMNS is not
# exported by every shell and is not updated for a non-interactive caller,
# while tput reads terminfo and the tty.
#
# The fallback is a constant, which is a deliberate change. mq-ui.sh's version
# fell back to "${BOX_INNER:-92}", and mq-ui.sh also defaults BOX_INNER to 88 —
# so the menus fell back to 88 while gitlaunch's copy hardcoded 92, and the
# value depended on whether mq-ui.sh had been sourced yet. The two were meant
# to agree: gitlaunch's comment said it matched the surface so nested panels
# line up. BOX_INNER is a box width anyway, not a terminal width; borrowing it
# here conflated the two.
surface_terminal_width() {
  local cols width

  cols="$(tput cols 2>/dev/null || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=92

  width="$cols"
  (( width > 112 )) && width=112
  (( width < 60 )) && width=60

  printf '%s' "$width"
}
