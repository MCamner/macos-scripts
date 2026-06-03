#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source ~/.env 2>/dev/null || true
source "$BASE_DIR/.env" 2>/dev/null || true

VECTOR_STORE_ID="${MQ_REPO_VECTOR_STORE_ID:-${OPENAI_VECTOR_STORE_ID:-vs_69f93de12f508191bd6a36ea3b825beb}}"
previous_id=""

# Coordinates chat sep behavior.
_chat_sep() { printf '%.0s─' $(seq 1 "${COLUMNS:-80}"); printf '\n'; }

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "OPENAI_API_KEY is not set. Add it to ~/.env or $BASE_DIR/.env."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for mqlaunch chat."
  exit 1
fi

clear
_chat_sep
printf " mqlaunch chat  —  Repo Memory Assistant, skriv exit för att avsluta\n"
_chat_sep
echo ""

while true; do
  printf "chat > "
  IFS= read -r question || break
  [[ "$question" == "exit" || "$question" == "quit" || "$question" == "q" ]] && break
  [[ -z "${question// }" ]] && continue

  if [[ -z "$previous_id" ]]; then
    PAYLOAD="$(jq -n \
      --arg q "$question" \
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
  else
    PAYLOAD="$(jq -n \
      --arg q "$question" \
      --arg prev "$previous_id" \
      --arg vs "$VECTOR_STORE_ID" \
      '{
        model: "gpt-4.1-mini",
        input: $q,
        previous_response_id: $prev,
        tools: [{ type: "file_search", vector_store_ids: [$vs] }]
      }')"
  fi

  printf "thinking..."

  RESPONSE="$(curl -s https://api.openai.com/v1/responses \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")"

  printf "\r\033[2K"

  previous_id="$(echo "$RESPONSE" | jq -r '.id // empty')"

  TEXT="$(echo "$RESPONSE" | jq -r '
    first(
      .output[]
      | select(.type == "message")
      | .content[]
      | select(.type == "output_text")
      | .text
    ) // .error.message // "No response"
  ' 2>/dev/null)"

  echo ""
  echo "$TEXT"
  echo ""
done

echo "Chat avslutat."
