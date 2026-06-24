#!/usr/bin/env bash
# Clipboard copy for the recommendations consumer. Places template TEXT on the
# macOS clipboard via pbcopy and nothing more — it does not execute, open, or
# route. After copy, the user decides what (if anything) to do with the text.
# Depends on: errors.sh, parse.sh, actions.sh.
#
# pbcopy is invoked through "$REC_PBCOPY" (an absolute path) for the same reason
# jq goes through "$REC_JQ": the launcher can strip/reset PATH between calls, so
# a bare `pbcopy` (or a `command -v pbcopy` check) fails even though pbcopy is a
# macOS system binary at /usr/bin/pbcopy. An absolute path needs no PATH.
: "${REC_PBCOPY:=pbcopy}"

# Resolve pbcopy to an ABSOLUTE path held in REC_PBCOPY. Prefer one on PATH
# (resolved to absolute), else the macOS system location. Non-zero only if no
# pbcopy exists anywhere we look.
rec_ensure_pbcopy() {
  [[ -n "${REC_PBCOPY:-}" && "$REC_PBCOPY" != pbcopy && -x "$REC_PBCOPY" ]] && return 0
  local cand
  cand="$(command -v pbcopy 2>/dev/null || true)"
  if [[ -n "$cand" && -x "$cand" ]]; then
    REC_PBCOPY="$cand"; export REC_PBCOPY; return 0
  fi
  if [[ -x /usr/bin/pbcopy ]]; then
    REC_PBCOPY=/usr/bin/pbcopy; export REC_PBCOPY; return 0
  fi
  return 1
}

# Fail (non-zero) unless pbcopy is available (resolved to an absolute path).
assert_clipboard_available() {
  if ! rec_ensure_pbcopy; then
    rec_error "pbcopy not found (looked on PATH and at /usr/bin/pbcopy) — clipboard copy unavailable"
    rec_info "current PATH: ${PATH}"
    return 1
  fi
}

# Copy text read from stdin to the clipboard, verbatim. No execution.
copy_text_to_clipboard() { "$REC_PBCOPY"; }

# Copy one pattern's template text to the clipboard. Fails clearly if the action
# is not permitted, the template is missing, or pbcopy is unavailable. Copies the
# template verbatim (placeholders unexpanded) — it is never run.
copy_pattern_template_to_clipboard() {
  local path="$1" id="$2" text
  assert_action_allowed "$path" copy || return 1
  assert_clipboard_available || return 1
  text="$(get_pattern_template_text "$path" "$id")" || return 1
  printf '%s' "$text" | copy_text_to_clipboard
}
