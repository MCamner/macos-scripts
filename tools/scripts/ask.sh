#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source ~/.env 2>/dev/null || true
source "$BASE_DIR/.env" 2>/dev/null || true

VECTOR_STORE_ID="vs_69f93de12f508191bd6a36ea3b825beb"

if [[ $# -eq 0 ]]; then
  cat <<'HELP'
Usage:
  mqlaunch ask "<question>"
  mqlaunch ask quick "<question>"

Examples:
  mqlaunch ask "Vad gör doctor.sh?"
  mqlaunch ask "Hur fungerar command routing i mqlaunch?"
  mqlaunch ask quick "Hur dödar jag en process på macOS?"
HELP
  exit 0
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
  PAYLOAD="$(jq -n \
    --arg q "$QUESTION" \
    --arg vs "$VECTOR_STORE_ID" \
    '{
      model: "gpt-4.1-mini",
      input: ("Use file search. " + $q),
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
