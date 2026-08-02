#!/usr/bin/env bash

# ----------------------------
# Theme system
# ----------------------------

MQ_THEME="${MQ_THEME:-green}"

# Colour is opt-out here, on the same condition as the central guard in
# ui/terminal-ui/mq-ui.sh: a TTY and no NO_COLOR (https://no-color.org).
#
# This file is sourced by scan.sh, brew-check.sh and doctor.sh, and it used to
# assign the escapes regardless of where stdout pointed — `mqlaunch scan > file`
# wrote 36 ANSI sequences into the file, and NO_COLOR=1 changed nothing. The P1
# output contract was true only for the commands that went through the shared
# library; these three went around it.
#
# The theme still picks the palette, so a real terminal is unaffected. Only the
# escapes are gated: every heading, rule, glyph and label the helpers below
# print is emitted either way, because the variables expand to nothing rather
# than to a colour.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  case "$MQ_THEME" in
    green)
      C_OK="\033[1;32m"
      C_WARN="\033[1;33m"
      C_ERR="\033[1;31m"
      C_TITLE="\033[1;36m"
      ;;
    amber)
      C_OK="\033[38;5;214m"
      C_WARN="\033[38;5;222m"
      C_ERR="\033[38;5;196m"
      C_TITLE="\033[38;5;220m"
      ;;
    ice)
      C_OK="\033[38;5;51m"
      C_WARN="\033[38;5;117m"
      C_ERR="\033[38;5;39m"
      C_TITLE="\033[38;5;123m"
      ;;
    *)
      C_OK="\033[1;32m"
      C_WARN="\033[1;33m"
      C_ERR="\033[1;31m"
      C_TITLE="\033[1;36m"
      ;;
  esac

  C_RESET="\033[0m"
  # Blink, used by blink_err for CRITICAL. It lived inline in that function's
  # printf format, which meant it kept leaking one escape per call even after
  # the colour variables were emptied.
  C_BLINK="\033[5m"
else
  C_OK=""
  C_WARN=""
  C_ERR=""
  C_TITLE=""
  C_RESET=""
  C_BLINK=""
fi

# ----------------------------
# Layout
# ----------------------------

# Width comes from the shared helper, not a local `tput cols`. With TERM unset —
# a GUI launch, cron, a nested launcher, a CI runner — tput prints its own
# complaint and returns nothing, and printf then rejects the empty field width.
# `mqlaunch doctor` emitted twelve such error pairs while still exiting 0, and
# drew blank lines where its separators should be. The helper owns the fallback
# and the clamp; this file should not carry a fourth copy of that decision.
_mq_cli_ui_self="${BASH_SOURCE[0]-}"
# shellcheck source=../../ui/terminal-ui/terminal-width.sh
source "${_mq_cli_ui_self%/*}/../../ui/terminal-ui/terminal-width.sh"
unset _mq_cli_ui_self

# Handles hr.
hr() {
  local pad
  # Not `| tr ' ' '─'`. tr is byte-oriented: in a C locale it maps each space to
  # 0xe2, the first byte of ─, and the rule arrives as a run of invalid UTF-8. A
  # stripped environment loses LANG for the same reason it loses TERM, so this is
  # the same call. Parameter expansion substitutes the whole sequence.
  printf -v pad '%*s' "$(surface_terminal_width)" ''
  printf '%s\n' "${pad// /─}"
}

# Handles header.
header() {
  echo -e "${C_TITLE}$1${C_RESET}"
  hr
}

# Handles section.
section() {
  echo
  echo -e "${C_TITLE}$1${C_RESET}"
  hr
}

# Handles ok.
ok()   { printf "${C_OK}✔ %-30s${C_RESET}\n" "$1"; }
# Handles warn.
warn() { printf "${C_WARN}⚠ %-30s${C_RESET}\n" "$1"; }
# Handles err.
err()  { printf "${C_ERR}✖ %-30s${C_RESET}\n" "$1"; }

# Blink helper (used for CRITICAL)
blink_err() {
  printf "${C_BLINK}${C_ERR}✖ %-30s${C_RESET}\n" "$1"
}
