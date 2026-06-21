#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source "$BASE_DIR/tools/cli/mq-ui.sh"

_J_STATUS="ok"
_J_OK=0
_J_WARN=0
_J_FAIL=0
_J_SEP=""
_J_CHECKS=""

# Appends one check to the checks buffer and updates counters (no subshell).
_jc() {
  local name="$1" st="$2" detail="${3:-}"
  case "$st" in
    ok)   _J_OK=$((_J_OK+1)) ;;
    warn) _J_WARN=$((_J_WARN+1)); [[ "$_J_STATUS" == "ok" ]] && _J_STATUS="warn" ;;
    fail) _J_FAIL=$((_J_FAIL+1)); _J_STATUS="fail" ;;
  esac
  local obj
  if [[ -n "$detail" ]]; then
    obj='{"name":"'"$name"'","status":"'"$st"'","detail":"'"$detail"'"}'
  else
    obj='{"name":"'"$name"'","status":"'"$st"'"}'
  fi
  _J_CHECKS="${_J_CHECKS}${_J_SEP}${obj}"
  _J_SEP=","
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

  printf '{"project":"macos-scripts","version":"%s","status":"%s","checks":[%s],"summary":{"ok":%d,"warn":%d,"fail":%d}}\n' \
    "$version" "$_J_STATUS" "$_J_CHECKS" "$_J_OK" "$_J_WARN" "$_J_FAIL"
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
      ok "$cmd"
    else
      warn "$cmd missing"
    fi
  done

  section "ENV"
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    ok "OPENAI_API_KEY set"
  else
    warn "OPENAI_API_KEY missing"
  fi

  section "MQ SETUP"
  if command -v mqlaunch >/dev/null 2>&1; then
    ok "mqlaunch available"
  else
    warn "mqlaunch not in PATH"
  fi

  section "SUMMARY"
  ok "MQ operational"

  echo
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
