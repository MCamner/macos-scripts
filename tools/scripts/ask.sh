#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
[[ -f "$HOME/.env" ]] && source "$HOME/.env"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env"

VECTOR_STORE_ID="${MQ_REPO_VECTOR_STORE_ID:-${OPENAI_VECTOR_STORE_ID:-vs_69f93de12f508191bd6a36ea3b825beb}}"

PROMPT_BUILDER="${REPO_SIGNAL_PROMPT_BUILDER:-$HOME/repo-signal/tools/build_prompt.py}"

# Builds ai prompt for later command execution.
build_ai_prompt() {
  local question="$1"
  local prompt

  if [[ -x "$PROMPT_BUILDER" ]]; then
    if prompt="$(python3 "$PROMPT_BUILDER" --raw "$question" 2>/dev/null)" && [[ -n "$prompt" ]]; then
      printf '%s\n' "$prompt"
      return 0
    fi
  fi

  printf '%s\n' "$question"
}

if [[ $# -eq 0 ]]; then
  cat <<HELP
Usage:
  mqlaunch ask "<question>"
  mqlaunch ask quick "<question>"

Examples:
  mqlaunch ask "Vad gör doctor.sh?"
  mqlaunch ask "Hur fungerar command routing i mqlaunch?"
  mqlaunch ask quick "Hur dödar jag en process på macOS?"

Memory:
  MQ_REPO_VECTOR_STORE_ID="$VECTOR_STORE_ID"
HELP
  exit 0
fi

NO_CLIPBOARD=0
if [[ "${1:-}" == "--no-clipboard" ]]; then
  NO_CLIPBOARD=1
  shift
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  if [[ "$NO_CLIPBOARD" -eq 1 ]]; then
    echo "ERROR: OPENAI_API_KEY is required for mqlaunch ask --no-clipboard"
  else
    echo "OPENAI_API_KEY is not set. Add it to ~/.env or $BASE_DIR/.env."
  fi
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for mqlaunch ask."
  exit 1
fi

if [[ "${1:-}" == "quick" ]]; then
  shift
  QUESTION="$*"
  PAYLOAD="$(jq -n --arg q "$QUESTION" '{
    model: "gpt-4.1-mini",
    input: ("Answer briefly and practically. Prefer concrete commands.\n\nQuestion: " + $q)
  }')"
else
  QUESTION="$*"
  PROMPT="$(build_ai_prompt "$QUESTION")"
  PAYLOAD="$(jq -n \
    --arg q "$PROMPT" \
    --arg vs "$VECTOR_STORE_ID" \
    '{
      model: "gpt-4.1-mini",
      input: (
        "You are Repo Memory Assistant for macos-scripts. " +
        "Use file search from the Semantic Repository Memory vector store. " +
        "Answer practically with source-aware references when useful. " +
        "Prefer filenames, functions, why they matter, and confidence over generic advice.\n\n" +
        $q
      ),
      tools: [{ type: "file_search", vector_store_ids: [$vs] }]
    }')"
fi

printf "asking... "

RESPONSE="$(curl -s https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

printf "\r\033[2K"

TEXT="$(echo "$RESPONSE" | jq -r '
  first(
    .output[]
    | select(.type == "message")
    | .content[]
    | select(.type == "output_text")
    | .text
  ) // .error.message // "No response"
' 2>/dev/null)"

if [[ -z "$TEXT" || "$TEXT" == "null" ]]; then
  echo "Error: $(echo "$RESPONSE" | jq -r '.error.message // "unexpected response"')"
  exit 1
fi

echo "$TEXT"
