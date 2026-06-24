#!/usr/bin/env bash
# Action gating for the recommendations consumer. Read-only — decides whether an
# action is permitted by the file's contract and hands back template TEXT; it
# never runs anything. The producer's contract is FILE-WIDE
# (allowed_actions: ["show","copy"]) — there is no per-pattern action list — so
# the gate is one contract check, not a per-pattern lookup. The per-pattern guard
# is visibility (risk_class), enforced where patterns are listed, not here.
# Depends on: errors.sh, parse.sh.

# Fail (non-zero) unless the contract permits this action. Emits the precise
# reason. Does not take a pattern id — the contract applies to the whole file.
assert_action_allowed() {
  local path="$1" action="$2"
  if ! rec_action_allowed "$path" "$action"; then
    rec_error "action '$action' is not in this file's contract (allowed: $(rec_allowed_actions "$path"))"
    return 1
  fi
}

# Echo a pattern's template text, or fail clearly if it is missing/empty. This is
# the text that show renders and copy places on the clipboard — never executed.
get_pattern_template_text() {
  local path="$1" id="$2" text
  text="$(rec_template "$path" "$id")"
  if [[ -z "$text" ]]; then
    rec_error "pattern has no command_template to show/copy: $id"
    return 1
  fi
  printf '%s' "$text"
}

# One-line summary of how this consumer may handle a pattern: the file-wide
# actions, plus whether the pattern is in the default-visible set. Read-only.
render_pattern_action_summary() {
  local path="$1" id="$2" vis="hidden (non-default risk — opt-in by exact id)"
  if rec_pattern_visible "$path" "$id"; then
    vis="visible (default list)"
  fi
  printf 'actions: %s (show/copy only — not executed) · %s\n' \
    "$(rec_allowed_actions "$path")" "$vis"
}
