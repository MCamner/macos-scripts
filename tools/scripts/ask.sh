#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source "$BASE_DIR/.env" 2>/dev/null || true

VECTOR_STORE_ID="vs_69f93de12f508191bd6a36ea3b825beb"
MODEL="gpt-4.1-mini"

if [[ $# -eq 0 ]]; then
  echo "Usage: mqlaunch ask \"<question>\""
  exit 1
fi

QUESTION="$*"

RESPONSE=$(curl -s https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL\",
    \"input\": \"$QUESTION\",
    \"tools\": [
      {
        \"type\": \"file_search\",
        \"vector_store_ids\": [\"$VECTOR_STORE_ID\"]
      }
    ]
  }")

echo "$RESPONSE" | jq -r '.output[1].content[0].text // .error.message // "No response"'
