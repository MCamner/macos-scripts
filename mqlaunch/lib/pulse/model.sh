#!/usr/bin/env bash
# Pulse status model — the canonical states, the aggregation rule, and the exit
# codes for `mqlaunch pulse`.
#
# This file holds the whole of the v2.1.0 P0 contract that can be executed. The
# prose lives in docs/PULSE_CONTRACT.md; the rules live here, so a collector or
# a renderer added later cannot invent a second definition of "healthy". It
# defines no collectors and reads nothing about the machine: everything below is
# a pure function of the states it is handed.
#
# Pure bash, no UI, no I/O beyond stdout on the query functions — so it can be
# sourced by the dispatcher, by a collector, and by a test without dragging in
# the terminal library.

# The five states a single Pulse check may report.
#
# Order is severity order for PASS/WARN/FAIL. UNAVAILABLE and SKIPPED are not
# points on that scale — see pulse_state_severity.
PULSE_STATES=(PASS WARN FAIL UNAVAILABLE SKIPPED)

# The run as a whole reaches one of PASS, WARN, FAIL and INCOMPLETE. That list
# is not a variable, because pulse_exit_code below already enumerates it and a
# second copy could disagree with the one that decides anything. INCOMPLETE is
# deliberately absent from PULSE_STATES: no check reports it, and it exists so a
# run that measured nothing cannot report the same thing as a run that measured
# everything and found it healthy.

# Answers whether a word is a check state this contract knows.
pulse_state_is_valid() {
  local candidate="${1:-}" state
  for state in "${PULSE_STATES[@]}"; do
    [[ "$candidate" == "$state" ]] && return 0
  done
  return 1
}

# Maps a check state to its contribution to the run's severity.
#
# UNAVAILABLE ranks with WARN rather than with PASS. "The check could not run"
# is the case the roadmap's P0 names directly — an unavailable check must not
# silently pass — and an exit code of 0 would be exactly that silent pass, one
# level down from the screen.
#
# It does not rank with FAIL, because not measuring something is not the same as
# measuring it and finding it broken. An operator can act on the difference:
# FAIL means fix the subject, UNAVAILABLE means fix the reach.
#
# SKIPPED contributes nothing. It is the operator's own choice — `--no-network`
# and the like — and a run cannot be called unhealthy for honouring a flag. What
# it also cannot do is stand in for a measurement, which is why a run of nothing
# but SKIPPED reaches INCOMPLETE below rather than PASS.
pulse_state_severity() {
  case "${1:-}" in
    PASS)        printf '0' ;;
    WARN)        printf '1' ;;
    UNAVAILABLE) printf '1' ;;
    FAIL)        printf '2' ;;
    SKIPPED)     printf '-' ;;
    *)           return 1 ;;
  esac
}

# Reduces the states of every check in a run to one overall state.
#
# Takes the states as arguments, or one per line on stdin when given none and
# stdin is not a terminal.
#
# The TTY check is not defensive tidying. Without it, a caller with no states to
# hand over — which is every caller before a collector is registered — blocks on
# a read from the operator's keyboard, and a status command that never returns
# is worse for a script than one that fails. It is the same rule
# tests/menu-eof-smoke.sh holds the interactive surfaces to, applied to the one
# function here that reads anything at all.
#
# A run with no contributing state — no checks at all, or every check SKIPPED —
# is INCOMPLETE. That is the honest answer: Pulse is a read-only view over other
# people's signals, and when it holds none of them it knows nothing about the
# machine. Reporting PASS there would make the healthiest-looking run the one
# where every collector failed to register.
pulse_overall_state() {
  local -a states=()
  if [[ $# -gt 0 ]]; then
    states=("$@")
  elif [[ ! -t 0 ]]; then
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && states+=("$line")
    done
  fi

  local worst=-1 state severity
  for state in "${states[@]}"; do
    if ! pulse_state_is_valid "$state"; then
      printf 'pulse: unknown check state: %s\n' "$state" >&2
      return 1
    fi
    severity="$(pulse_state_severity "$state")"
    [[ "$severity" == "-" ]] && continue
    (( severity > worst )) && worst="$severity"
  done

  case "$worst" in
    0) printf 'PASS' ;;
    1) printf 'WARN' ;;
    2) printf 'FAIL' ;;
    *) printf 'INCOMPLETE' ;;
  esac
}

# Maps an overall state to the exit code `mqlaunch pulse` returns.
#
#   0  healthy, nothing needs attention
#   1  one or more warnings, including checks that could not be reached
#   2  one or more failures
#   3  Pulse itself could not complete reliably
#
# An unknown word is a defect in the caller rather than a state of the machine,
# so it returns 3 as well: a run that cannot name its own result has not
# completed reliably either.
pulse_exit_code() {
  case "${1:-}" in
    PASS)       printf '0' ;;
    WARN)       printf '1' ;;
    FAIL)       printf '2' ;;
    INCOMPLETE) printf '3' ;;
    *)          printf '3' ;;
  esac
}

# The exit code for a run, straight from the states of its checks.
#
# The one call a collector-driven `pulse` needs, so the two-step above cannot be
# assembled wrongly at the call site.
pulse_run_exit_code() {
  local overall
  overall="$(pulse_overall_state "$@")" || return 3
  pulse_exit_code "$overall"
}
