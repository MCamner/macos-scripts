#!/usr/bin/env bash
# Terminal width for the mqlaunch surface, shared by bash menus and the zsh
# gitlaunch launcher.
#
# This lived in two places — surface_terminal_width in mq-ui.sh and
# gitlaunch_terminal_width in gitlaunch.sh. Their tput source and clamp were
# identical, but their fallbacks were caller policy: mq-ui used BOX_INNER
# (normally 88) while gitlaunch used 92. This helper shares the algorithm
# without silently changing either policy.
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
# The required argument is the caller's fallback policy. Keeping it explicit
# prevents a shared implementation from accidentally converging two distinct
# existing behaviours.
mq_terminal_width() {
  local fallback="${1:?terminal width fallback required}"
  local cols width

  cols="$(tput cols 2>/dev/null || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="$fallback"

  width="$cols"
  (( width > 112 )) && width=112
  (( width < 60 )) && width=60

  printf '%s' "$width"
}
