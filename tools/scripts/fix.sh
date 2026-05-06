#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source ~/.env 2>/dev/null || true
source "$BASE_DIR/.env" 2>/dev/null || true

VECTOR_STORE_ID="vs_69f93de12f508191bd6a36ea3b825beb"

if [[ $# -eq 0 ]]; then
  cat <<'HELP'
Usage:
  mqlaunch fix "<error or task>"

Examples:
  mqlaunch fix "ERROR: CHANGELOG does not contain version 0.1.9"
  mqlaunch fix "write a function that monitors disk usage"
  mqlaunch fix "add a case for 'atlas' in dispatch_cli_command"
HELP
  exit 0
fi

TASK="$*"

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$BASE_DIR")"
BRANCH="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "unknown")"

SYSTEM_PROMPT="You are a senior shell/bash engineer working in the macos-scripts repository.

Repo: $REPO_ROOT
Branch: $BRANCH

Rules:
- Always respond with copy-paste ready shell commands.
- Use cat heredocs for file creation or multi-line edits:
    cat > path/to/file.sh << 'EOF'
    ...content...
    EOF
- Use sed for targeted single-line fixes:
    sed -i '' 's/old/new/' path/to/file.sh
- For appending content use:
    cat >> path/to/file.sh << 'EOF'
    ...content...
    EOF
- For new directories: mkdir -p path/
- Always include the exact file path.
- Add a short comment above each block explaining what it does.
- Do NOT explain theory. Only output runnable commands.
- If multiple steps are needed, number them."

PAYLOAD="$(jq -n \
  --arg system "$SYSTEM_PROMPT" \
  --arg task "$TASK" \
  --arg vs "$VECTOR_STORE_ID" \
  '{
    model: "gpt-4.1",
    input: ($system + "\n\nTask: " + $task),
    tools: [{ type: "file_search", vector_store_ids: [$vs] }]
  }')"

printf "fixing... "

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
