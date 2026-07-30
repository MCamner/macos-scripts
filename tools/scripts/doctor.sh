#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source "$BASE_DIR/tools/cli/mq-ui.sh"

_J_STATUS="ok"
_J_OK=0
_J_WARN=0
_J_FAIL=0
_J_SEP=""
_J_CHECKS=""
_J_UNRESOLVED=""

# What to do about a check that did not pass.
#
# The nine brew formulae are listed by name rather than caught by a `*` arm.
# A fallback would turn any check added later into `brew install <whatever>`,
# and a confidently wrong instruction is worse than none — `pbcopy` has no
# formula at all. Names were confirmed with `brew info`, not from memory.
# tests/doctor-status-contract-smoke.sh fails when a check has no hint, so the
# missing arm is caught here rather than printed at an operator.
hint_for() {
  case "$1" in
    git|gh|uv|python3|node|eza|fzf|jq|gitleaks)
      printf 'brew install %s' "$1" ;;
    pbcopy)
      # No em dash inside a hint: the human row already joins message and hint
      # with one, and two in a line reads as a broken sentence.
      printf 'ships with macOS; this shell is not on one' ;;
    OPENAI_API_KEY)
      printf 'export OPENAI_API_KEY=... in your shell profile' ;;
    mqlaunch)
      printf 'run ./install.sh from the repo to install the symlink' ;;
    *)
      printf '' ;;
  esac
}

# The order a machine is worth fixing in, which is not the order the checks are
# printed in — those are grouped for reading. The launcher comes first because
# nothing else here is reachable without it, then the tools the launcher itself
# shells out to, then the ones only some commands need. `eza` is last of the
# tools because it only changes how listings look.
FIX_ORDER=(mqlaunch git python3 jq fzf gh uv node gitleaks pbcopy eza OPENAI_API_KEY)

# What to do on a machine where every check passes.
#
# Ending at "12 checks passed" answers half of what ROADMAP P2's exit gate asks:
# the operator learns the machine is fine and nothing about what to run. This is
# the landing because it is the one command that shows the whole stack — every
# repo, its readiness, and its own next action — rather than a menu they would
# then have to navigate.
#
# tests/doctor-status-contract-smoke.sh requires this to be a command help
# advertises: recommending an unadvertised one would send a new operator
# somewhere they could not find their way back to.
HEALTHY_NEXT="mqlaunch stack"

# Records a check that needs attention, so the next step can be chosen from all
# of them rather than from whichever one happened to be printed first.
note_unresolved() {
  _J_UNRESOLVED="${_J_UNRESOLVED} $1"
}

# The single thing to do next, as a ready-to-run instruction: the
# highest-priority unresolved check while anything needs attention, and the
# recommended landing once nothing does. Never empty — a run that ends without
# telling the operator what to do is the defect this exists to prevent.
next_step() {
  local candidate
  for candidate in "${FIX_ORDER[@]}"; do
    case " $_J_UNRESOLVED " in
      *" $candidate "*)
        hint_for "$candidate"
        return 0
        ;;
    esac
  done
  printf '%s' "$HEALTHY_NEXT"
}

# Appends one check to the checks buffer and updates counters (no subshell).
_jc() {
  local name="$1" st="$2" detail="${3:-}"
  case "$st" in
    ok)   _J_OK=$((_J_OK+1)) ;;
    warn) _J_WARN=$((_J_WARN+1)); [[ "$_J_STATUS" == "ok" ]] && _J_STATUS="warn" ;;
    fail) _J_FAIL=$((_J_FAIL+1)); _J_STATUS="fail" ;;
  esac
  local obj hint=""
  if [[ "$st" != "ok" ]]; then
    note_unresolved "$name"
    hint="$(hint_for "$name")"
  fi
  obj='{"name":"'"$name"'","status":"'"$st"'"'
  [[ -n "$detail" ]] && obj="${obj},\"detail\":\"${detail}\""
  [[ -n "$hint" ]] && obj="${obj},\"hint\":\"${hint}\""
  obj="${obj}}"
  _J_CHECKS="${_J_CHECKS}${_J_SEP}${obj}"
  _J_SEP=","
}

# Prints a passing row and counts it.
#
# The counters were only ever updated in JSON mode, so the screen had nothing to
# summarise and ended in a constant. These two wrappers give both modes the same
# arithmetic.
check_ok() {
  _J_OK=$((_J_OK+1))
  ok "$1"
}

# Prints a warning row and counts it.
#
# Takes the check's name as well as the message: the name is what `hint_for` and
# the fix order are keyed on, and it is not always a prefix of what is printed
# ("OPENAI_API_KEY missing" versus "mqlaunch not in PATH").
check_warn() {
  local name="$1" message="$2"
  _J_WARN=$((_J_WARN+1))
  if [[ "$_J_STATUS" == "ok" ]]; then
    _J_STATUS="warn"
  fi
  note_unresolved "$name"
  local hint
  hint="$(hint_for "$name")"
  if [[ -n "$hint" ]]; then
    warn "$message — $hint"
  else
    warn "$message"
  fi
}

# Maps the run's status to an exit code: 0 only when nothing needs attention.
#
# `warn` counts as non-zero because every check here is a warn — nothing sets
# `fail` — so treating warnings as success would leave the exit code constant,
# which is the defect this file just had on the screen.
status_exit_code() {
  [[ "$_J_STATUS" == "ok" ]] && return 0
  return 1
}

# Runs JSON report mode.
run_json_mode() {
  local version
  version="$(cat "$BASE_DIR/VERSION" 2>/dev/null || printf 'unknown')"

  for cmd in git gh uv python3 node eza fzf jq gitleaks pbcopy; do
    if command -v "$cmd" >/dev/null 2>&1; then
      _jc "$cmd" "ok"
    else
      _jc "$cmd" "warn" "missing"
    fi
  done

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    _jc "OPENAI_API_KEY" "ok"
  else
    _jc "OPENAI_API_KEY" "warn" "missing"
  fi

  if command -v mqlaunch >/dev/null 2>&1; then
    _jc "mqlaunch" "ok"
  else
    _jc "mqlaunch" "warn" "not in PATH"
  fi

  local next
  next="$(next_step)"

  printf '{"project":"macos-scripts","version":"%s","status":"%s","checks":[%s],"summary":{"ok":%d,"warn":%d,"fail":%d},"next":%s}\n' \
    "$version" "$_J_STATUS" "$_J_CHECKS" "$_J_OK" "$_J_WARN" "$_J_FAIL" \
    "$([[ -n "$next" ]] && printf '"%s"' "$next" || printf 'null')"

  status_exit_code
}

# Runs normal interactive mode.
run_normal_mode() {
  header "MQ DOCTOR"

  section "SYSTEM"
  ok "User: $USER"
  ok "Shell: $SHELL"

  section "TOOLS"
  for cmd in git gh uv python3 node eza fzf jq gitleaks pbcopy; do
    if command -v "$cmd" >/dev/null 2>&1; then
      check_ok "$cmd"
    else
      check_warn "$cmd" "$cmd missing"
    fi
  done

  section "ENV"
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    check_ok "OPENAI_API_KEY set"
  else
    check_warn "OPENAI_API_KEY" "OPENAI_API_KEY missing"
  fi

  section "MQ SETUP"
  if command -v mqlaunch >/dev/null 2>&1; then
    check_ok "mqlaunch available"
  else
    check_warn "mqlaunch" "mqlaunch not in PATH"
  fi

  section "SUMMARY"
  # Branch on the status rather than on a warn count, so a `fail` check added
  # later cannot slip past a `warn`-shaped condition and print "operational"
  # again. The word is reachable from exactly one place: `_J_STATUS` being ok.
  local total=$((_J_OK + _J_WARN + _J_FAIL))
  if [[ "$_J_STATUS" == "ok" ]]; then
    ok "MQ operational — $total checks passed"
  else
    warn "$((_J_WARN + _J_FAIL)) of $total checks need attention"
  fi

  # One instruction, not a list, and on every run rather than only the bad ones.
  # When something needs attention the warnings above each carry their own hint
  # and this names which to do first; when nothing does, it names where to go.
  local next
  next="$(next_step)"
  [[ -n "$next" ]] && printf '\n  Next: %s\n' "$next"

  echo
  status_exit_code
}

JSON_MODE=0
for arg in "$@"; do
  [[ "$arg" == "--json" ]] && JSON_MODE=1
done

if [[ $JSON_MODE -eq 1 ]]; then
  run_json_mode
else
  run_normal_mode
fi
