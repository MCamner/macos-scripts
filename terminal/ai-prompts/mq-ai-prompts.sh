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
Use repo-product-auditor.

You are auditing this repository as a product, not only reviewing a diff.

Focus on the highest-signal product and repo issues first:
- broken or confusing workflows
- unclear command names, prompts, or UX
- mismatches between intent, docs, and implementation
- missing verification for important user paths
- correctness, regression, security, or data-loss risks

Lead with findings, ordered by severity. Include file/line references when available.
Recommend concrete fixes. Keep summaries brief and avoid theory unless it directly supports a practical next step.
PROMPT
)"

  mq_ai_copy_prompt "/review" "$prompt"
}

mq_ai_prompt_ui() {
  local prompt
  prompt="$(cat <<'PROMPT'
Use terminal-ui-polisher.

You are improving a terminal UI, CLI, or TUI experience for mqlaunch.

Prioritize:
- clear command hierarchy
- discoverable terminal actions
- readable labels and help text
- consistent spacing, prompts, and states
- keyboard-friendly flows
- practical, polished CLI/TUI interactions

Make the actual terminal workflow usable first. Keep decoration subordinate to clarity.
Verify that text fits in common terminal widths, commands are reachable, and output remains readable in light and dark themes.
PROMPT
)"

  mq_ai_copy_prompt "/ui" "$prompt"
}

mq_ai_prompt_ask() {
  local question="${*:-}"

  if [[ -z "$question" ]]; then
    echo "Usage: mqlaunch ask \"your question\""
    return 1
  fi

  local prompt
  prompt="$(cat <<PROMPT
Use repo-aware reasoning.

You are answering a question about the macos-scripts repository.

Question:
$question

Instructions:
- Answer based on provided repo context when available.
- If repo context is missing, ask for the relevant README, file tree, script, or command output.
- Do not invent files, functions, or behavior.
- Prefer concrete file paths and commands.
- Keep the answer practical and concise.
PROMPT
)"

  mq_ai_copy_prompt "/ask" "$prompt"
}
