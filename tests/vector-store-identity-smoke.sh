#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Marks a failing check.
fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

# Marks a passing check.
pass() {
  printf '[PASS] %s\n' "$1"
}

LEGACY_ID="vs_69f93de12f508191bd6a36ea3b825beb"
LIB="$ROOT/tools/cli/mq-vector-store.sh"

# --- Architectural regression -------------------------------------------------
# The canonical id is declared in exactly one place. A consumer that grows its
# own hardcoded store id reintroduces the drift this migration removed, whatever
# the id happens to be — so this check is about the contract, not one value.

[[ -f "$LIB" ]] || fail "canonical vector store library is missing"

offenders="$(grep -rlE 'vs_[0-9a-f]{16,}' "$ROOT/tools" 2>/dev/null | grep -v "^$LIB$" || true)"
if [[ -n "$offenders" ]]; then
  printf '%s\n' "$offenders" >&2
  fail "a hardcoded vector store id exists outside the canonical library"
fi
pass "only the canonical library names a vector store id"

for consumer in ask.sh chat.sh fix.sh hal-terminal-guide.sh; do
  path="$ROOT/tools/scripts/$consumer"
  grep -q 'mq_vector_store_id' "$path" || fail "$consumer does not resolve through mq_vector_store_id"
  grep -q 'tools/cli/mq-vector-store.sh' "$path" || fail "$consumer does not source the canonical library"
done
pass "all four consumers resolve through the canonical resolver"

# --- Legacy regression --------------------------------------------------------
# The specific store these consumers used to reach. Retired or not, nothing in
# tools/ may name it again.

if grep -rq "$LEGACY_ID" "$ROOT/tools" 2>/dev/null; then
  grep -rn "$LEGACY_ID" "$ROOT/tools" >&2
  fail "the legacy vector store id has returned to tools/"
fi
pass "the legacy vector store id is absent from tools/"

# --- Resolver semantics -------------------------------------------------------
# shellcheck disable=SC1090
source "$LIB"

[[ -n "${MQ_CANONICAL_VECTOR_STORE_ID:-}" ]] || fail "canonical id is not declared"

unset MQ_REPO_VECTOR_STORE_ID OPENAI_VECTOR_STORE_ID MQ_TERMINAL_GUIDE_VECTOR_STORE_ID
resolved="$(mq_vector_store_id MQ_REPO_VECTOR_STORE_ID OPENAI_VECTOR_STORE_ID)"
[[ "$resolved" == "$MQ_CANONICAL_VECTOR_STORE_ID" ]] \
  || fail "no environment must resolve to the canonical store, got: $resolved"
pass "no environment resolves to the canonical store"

resolved="$(MQ_TERMINAL_GUIDE_VECTOR_STORE_ID='' mq_vector_store_id MQ_TERMINAL_GUIDE_VECTOR_STORE_ID)"
[[ "$resolved" == "$MQ_CANONICAL_VECTOR_STORE_ID" ]] \
  || fail "the terminal guide must fall back to canonical, got: $resolved"
pass "the terminal guide has a canonical fallback"

resolved="$(MQ_REPO_VECTOR_STORE_ID='vs_explicit' mq_vector_store_id MQ_REPO_VECTOR_STORE_ID OPENAI_VECTOR_STORE_ID)"
[[ "$resolved" == "vs_explicit" ]] || fail "an explicit override must win, got: $resolved"
pass "an explicit override wins"

resolved="$(MQ_REPO_VECTOR_STORE_ID='   ' OPENAI_VECTOR_STORE_ID='vs_second' \
  mq_vector_store_id MQ_REPO_VECTOR_STORE_ID OPENAI_VECTOR_STORE_ID)"
[[ "$resolved" == "vs_second" ]] \
  || fail "a whitespace-only value must not count as an override, got: $resolved"
pass "a blank value is not an override"

resolved="$(MQ_REPO_VECTOR_STORE_ID='  vs_padded  ' mq_vector_store_id MQ_REPO_VECTOR_STORE_ID)"
[[ "$resolved" == "vs_padded" ]] || fail "surrounding whitespace must be stripped, got: $resolved"
pass "surrounding whitespace is stripped"

printf 'vector-store-identity-smoke: OK\n'
