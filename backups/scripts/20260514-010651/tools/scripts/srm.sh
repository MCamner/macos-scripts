#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
source ~/.env 2>/dev/null || true
source "$BASE_DIR/.env" 2>/dev/null || true

VECTOR_STORE_ID="${SRM_VECTOR_STORE_ID:-${OPENAI_VECTOR_STORE_ID:-vs_69ffa9a4ef5c81919d7d237c3ecdc260}}"
MODEL="${SRM_MODEL:-gpt-4.1-mini}"

usage() {
  cat <<HELP
Usage:
  mqlaunch srm ask "<question>"
  mqlaunch srm search "<query>"
  mqlaunch srm inspect
  mqlaunch srm "<question>"

Examples:
  mqlaunch srm ask "what repo is indexed here?"
  mqlaunch srm search "vector store upload flow"
  mqlaunch srm inspect

Memory:
  SRM_VECTOR_STORE_ID="$VECTOR_STORE_ID"
HELP
}

require_runtime() {
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "OPENAI_API_KEY is not set. Add it to ~/.env or $BASE_DIR/.env."
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for mqlaunch srm."
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required for mqlaunch srm."
    exit 1
  fi
}

build_question() {
  local mode="$1"
  local question="$2"

  case "$mode" in
    inspect)
      printf '%s\n' "Inspect this vector store. Identify what repository or project it appears to contain, the strongest evidence, likely entrypoints, and any uncertainty."
      ;;
    search)
      printf '%s\n' "Search this semantic repository memory for: $question"
      ;;
    *)
      printf '%s\n' "$question"
      ;;
  esac
}

ask_srm() {
  local mode="$1"
  local question="$2"
  local prompt payload response text

  prompt="$(build_question "$mode" "$question")"

  payload="$(jq -n \
    --arg model "$MODEL" \
    --arg q "$prompt" \
    --arg vs "$VECTOR_STORE_ID" \
    '{
      model: $model,
      input: (
        "You are Semantic Repository Memory Assistant. " +
        "Use file_search against the attached vector store as your source of truth. " +
        "Help the user inspect what this repository memory contains, answer source-aware questions, " +
        "identify relevant files, functions, concepts, and explain confidence. " +
        "Be practical, concise, and honest when the vector store does not contain enough evidence. " +
        "Do not pretend to know files that are not retrieved.\n\n" +
        $q
      ),
      tools: [
        {
          type: "file_search",
          vector_store_ids: [$vs]
        }
      ]
    }')"

  printf "srm thinking... "
  response="$(curl -sS https://api.openai.com/v1/responses \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")"
  printf "\r\033[2K"

  text="$(echo "$response" | jq -r '
    first(
      .output[]
      | select(.type == "message")
      | .content[]
      | select(.type == "output_text")
      | .text
    ) // .error.message // "No response"
  ' 2>/dev/null)"

  if [[ -z "$text" || "$text" == "null" ]]; then
    echo "Error: $(echo "$response" | jq -r '.error.message // "unexpected response"')"
    exit 1
  fi

  echo "$text"
}

main() {
  local mode question

  if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    usage
    exit 0
  fi

  mode="ask"
  case "${1:-}" in
    ask|search|inspect)
      mode="$1"
      shift
      ;;
  esac

  if [[ "$mode" == "inspect" ]]; then
    question=""
  else
    question="$*"
    if [[ -z "${question// }" ]]; then
      usage
      exit 1
    fi
  fi

  require_runtime
  ask_srm "$mode" "$question"
}

main "$@"
