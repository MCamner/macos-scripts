#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source "$BASE_DIR/tools/cli/mq-ui.sh"

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
