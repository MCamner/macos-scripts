#!/usr/bin/env bash

mq_ai_copy_prompt() {
  local name="$1"
  local prompt="$2"

  if ! command -v pbcopy >/dev/null 2>&1; then
    echo "pbcopy missing."
    return 1
  fi

  printf '%s\n' "$prompt" | pbcopy
  echo "Copied $name prompt to clipboard."
}

mq_ai_prompt_review() {
  local prompt
  prompt="$(cat <<'PROMPT'
You are reviewing code changes.

Focus on the highest-signal issues first:
- correctness bugs
- regressions
- missing tests
- security or data-loss risk
- confusing UX or unclear behavior

Lead with findings, ordered by severity. Include file/line references when available.
Keep summaries brief and avoid theory unless it directly supports a concrete fix.
PROMPT
)"

  mq_ai_copy_prompt "/review" "$prompt"
}

mq_ai_prompt_ui() {
  local prompt
  prompt="$(cat <<'PROMPT'
You are improving a user interface.

Prioritize:
- clear hierarchy
- discoverable controls
- responsive layout
- readable labels
- consistent spacing and states
- practical, polished interactions

Build the actual usable screen first. Keep decoration subordinate to clarity.
Verify that text fits, controls are reachable, and the UI works on mobile and desktop.
PROMPT
)"

  mq_ai_copy_prompt "/ui" "$prompt"
}
