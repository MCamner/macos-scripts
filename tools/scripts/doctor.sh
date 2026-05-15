#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source "$BASE_DIR/tools/cli/mq-ui.sh"

_JSON_OVERALL="ok"

# Outputs a single JSON check object and updates overall status.
_json_check() {
  local name="$1" status="$2" detail="${3:-}"
  [[ "$status" == "warn" && "$_JSON_OVERALL" == "ok" ]] && _JSON_OVERALL="warn"
  [[ "$status" == "fail" ]] && _JSON_OVERALL="fail"
  if [[ -n "$detail" ]]; then
    printf '{"name":"%s","status":"%s","detail":"%s"}' "$name" "$status" "$detail"
  else
    printf '{"name":"%s","status":"%s"}' "$name" "$status"
  fi
}

# Runs JSON report mode.
run_json_mode() {
  local version sep check
  local checks=()
  version="$(cat "$BASE_DIR/VERSION" 2>/dev/null || printf 'unknown')"

  for cmd in git eza fzf jq gitleaks pbcopy; do
    if command -v "$cmd" >/dev/null 2>&1; then
      checks+=("$(_json_check "$cmd" "ok")")
    else
      checks+=("$(_json_check "$cmd" "warn" "missing")")
    fi
  done

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    checks+=("$(_json_check "OPENAI_API_KEY" "ok")")
  else
    checks+=("$(_json_check "OPENAI_API_KEY" "warn" "missing")")
  fi

  if command -v mqlaunch >/dev/null 2>&1; then
    checks+=("$(_json_check "mqlaunch" "ok")")
  else
    checks+=("$(_json_check "mqlaunch" "warn" "not in PATH")")
  fi

  printf '{"status":"%s","version":"%s","checks":[' "$_JSON_OVERALL" "$version"
  sep=""
  for check in "${checks[@]}"; do
    printf '%s%s' "$sep" "$check"
    sep=","
  done
  printf ']}\n'
}

# Runs normal interactive mode.
run_normal_mode() {
  header "MQ DOCTOR"

  section "SYSTEM"
  ok "User: $USER"
  ok "Shell: $SHELL"

  section "TOOLS"
  for cmd in git eza fzf jq gitleaks pbcopy; do
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
