#!/usr/bin/env bash
# Canonical semantic memory identity for this repo's shell consumers.
#
# mq-agent owns the canonical store and declares it in tracked code
# (mq_agent/memory/semantic.py). This file is the single place macos-scripts
# names it, so no shell consumer carries a store id of its own. A consumer that
# hardcodes an id drifts silently the day the canonical store changes — which is
# exactly how four scripts came to point at a retired store.
#
# The id is an addressable name, not a credential. The API key stays in .env.

MQ_CANONICAL_VECTOR_STORE_ID="vs_69ffa9a4ef5c81919d7d237c3ecdc260"

# Resolves the vector store id: the first non-empty override wins, otherwise the
# canonical store. Pass override variable NAMES in priority order, e.g.
#   mq_vector_store_id MQ_REPO_VECTOR_STORE_ID OPENAI_VECTOR_STORE_ID
# An unset, empty or whitespace-only variable is not an override, so a blank
# value in a sourced .env cannot silently redirect a consumer.
mq_vector_store_id() {
  local name value
  for name in "$@"; do
    value="${!name:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  printf '%s\n' "$MQ_CANONICAL_VECTOR_STORE_ID"
}
