#!/usr/bin/env bash
# Clipboard copy for the recommendations consumer. Places template TEXT on the
# macOS clipboard via pbcopy and nothing more — it does not execute, open, or
# route. After copy, the user decides what (if anything) to do with the text.
# Depends on: errors.sh, parse.sh, actions.sh.

# Fail (non-zero) unless pbcopy is available.
assert_clipboard_available() {
  if ! command -v pbcopy >/dev/null 2>&1; then
    rec_error "pbcopy not found on PATH — clipboard copy is unavailable on this host"
    return 1
  fi
}

# Copy text read from stdin to the clipboard, verbatim. No execution.
copy_text_to_clipboard() { pbcopy; }

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
