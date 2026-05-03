#!/usr/bin/env bash

source "$HOME/macos-scripts/tools/cli/mq-ui.sh"

header "MQ DOCTOR"

section "SYSTEM"
ok "User: $USER"
ok "Shell: $SHELL"

section "TOOLS"
for cmd in git eza fzf jq; do
  command -v "$cmd" >/dev/null && ok "$cmd" || warn "$cmd missing"
done

section "SUMMARY"
ok "MQ operational"

echo
