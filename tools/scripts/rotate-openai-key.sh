#!/usr/bin/env bash
set -euo pipefail
set +x

umask 077

MQ_AGENT_HOME="${MQ_AGENT_HOME:-$HOME/mq-agent}"
TARGET="${MQ_OPENAI_KEY_TARGET:-$MQ_AGENT_HOME/.env}"
OPENAI_KEYS_URL="${MQ_OPENAI_KEYS_URL:-https://platform.openai.com/api-keys}"
OPENAI_VERIFY_URL="${MQ_OPENAI_VERIFY_URL:-https://api.openai.com/v1/models}"
DRY_RUN=0
TMP_FILE=""

cleanup() {
  if [[ -n "${TMP_FILE:-}" ]]; then
    rm -f -- "$TMP_FILE"
  fi
}
trap cleanup EXIT HUP INT TERM

usage() {
  cat <<'USAGE'
rotate-openai-key.sh - safely rotate the OpenAI key used by mq-agent

Usage:
  rotate-openai-key.sh [--dry-run]

Flow:
  1. Refuse shell/startup-file overrides that would shadow mq-agent/.env.
  2. Open OpenAI Platform so the operator can create a new key.
  3. Read the new key without echoing it.
  4. Verify the key before writing anything.
  5. Ask before replacing OPENAI_API_KEY in mq-agent/.env.
  6. Replace the key atomically, chmod 600, then smoke-test the persisted key.
  7. Re-open the key page and show only the old suffix for manual revoke.

The secret is never accepted as a command-line argument and is never printed.
The old key is never revoked automatically in v1.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit "${2:-1}"
}

key_suffix() {
  local key="${1:-}"
  if [[ ${#key} -ge 4 ]]; then
    printf '%s' "${key: -4}"
  else
    printf 'none'
  fi
}

read_env_key() {
  local file="$1" line value=""
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      OPENAI_API_KEY=*)
        value="${line#OPENAI_API_KEY=}"
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
          value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
          value="${value:1:${#value}-2}"
        fi
        printf '%s' "$value"
        return 0
        ;;
    esac
  done < "$file"
}

check_no_shell_override() {
  local startup file hits=()

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    fail "OPENAI_API_KEY is set in this shell and would override $TARGET. Run 'unset OPENAI_API_KEY' first." 2
  fi

  for startup in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" \
                 "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    if [[ -f "$startup" ]] \
       && grep -Eq '^[[:space:]]*(export[[:space:]]+)?OPENAI_API_KEY=' "$startup"; then
      hits+=("$startup")
    fi
  done

  if (( ${#hits[@]} > 0 )); then
    printf 'ERROR: a shell startup file still assigns OPENAI_API_KEY:\n' >&2
    for file in "${hits[@]}"; do
      printf '  %s\n' "$file" >&2
    done
    printf 'Remove those assignments before rotating; a new shell would otherwise shadow %s.\n' "$TARGET" >&2
    exit 2
  fi
}

check_target() {
  local count=0 rel=""

  [[ -d "$MQ_AGENT_HOME" ]] || fail "mq-agent directory not found: $MQ_AGENT_HOME"

  if [[ -f "$TARGET" ]]; then
    count="$(grep -c '^OPENAI_API_KEY=' "$TARGET" 2>/dev/null || true)"
    if (( count > 1 )); then
      fail "$TARGET contains more than one OPENAI_API_KEY assignment; refusing an ambiguous rotation." 2
    fi
  fi

  if git -C "$MQ_AGENT_HOME" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    case "$TARGET" in
      "$MQ_AGENT_HOME"/*)
        rel="${TARGET#"$MQ_AGENT_HOME"/}"
        if git -C "$MQ_AGENT_HOME" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
          fail "$TARGET is tracked by git; refusing to write a secret there." 2
        fi
        ;;
    esac
  fi
}

validate_key_shape() {
  local key="$1"
  [[ "$key" =~ ^sk-[A-Za-z0-9_-]{20,}$ ]] \
    || fail "The pasted value does not look like a complete OpenAI API key. Nothing was changed." 2
}

verify_key_before_write() {
  local key="$1" http_code

  command -v curl >/dev/null 2>&1 || fail "curl is required to verify the new key before writing it."

  http_code="$({
    printf 'header = "Authorization: Bearer %s"\n' "$key"
  } | curl --config - --silent --show-error --output /dev/null \
      --write-out '%{http_code}' "$OPENAI_VERIFY_URL")" || {
        fail "Could not reach OpenAI to verify the new key. Nothing was changed."
      }

  case "$http_code" in
    200) return 0 ;;
    401) fail "OpenAI rejected the new key (HTTP 401). Nothing was changed." 2 ;;
    *) fail "OpenAI key verification returned HTTP $http_code. Nothing was changed." ;;
  esac
}

confirm_install() {
  local answer=""
  printf 'Install the verified key into %s? [y/N] ' "$TARGET" >&2
  IFS= read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) fail "Rotation cancelled. Nothing was changed." 2 ;;
  esac
}

write_key_atomically() {
  local key="$1" dir line wrote=0
  dir="$(dirname "$TARGET")"
  mkdir -p "$dir"
  TMP_FILE="$(mktemp "$dir/.openai-key.XXXXXX")"
  chmod 600 "$TMP_FILE"

  if [[ -f "$TARGET" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        OPENAI_API_KEY=*)
          if (( wrote == 0 )); then
            printf 'OPENAI_API_KEY=%s\n' "$key" >> "$TMP_FILE"
            wrote=1
          fi
          ;;
        *) printf '%s\n' "$line" >> "$TMP_FILE" ;;
      esac
    done < "$TARGET"
  fi

  if (( wrote == 0 )); then
    printf 'OPENAI_API_KEY=%s\n' "$key" >> "$TMP_FILE"
  fi

  mv -f "$TMP_FILE" "$TARGET"
  TMP_FILE=""
  chmod 600 "$TARGET"
}

verify_persisted_key() {
  local expected="$1" saved
  saved="$(read_env_key "$TARGET")"
  [[ -n "$saved" ]] || fail "The new key was not readable from $TARGET after the atomic write."
  [[ "$saved" == "$expected" ]] || fail "The persisted OPENAI_API_KEY does not match the verified key."

  command -v uv >/dev/null 2>&1 || fail "uv is required for the mq-agent credential smoke test."

  # Use mq-agent's own Python environment and load exactly the file just written.
  # This touches no route/execution store and prints no secret.
  MQ_OPENAI_SMOKE_TARGET="$TARGET" \
    uv run --project "$MQ_AGENT_HOME" python - <<'PY' >/dev/null
import os
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

target = Path(os.environ["MQ_OPENAI_SMOKE_TARGET"])
os.environ.pop("OPENAI_API_KEY", None)
load_dotenv(target, override=True)
OpenAI().models.list()
PY
}

open_keys_page() {
  if command -v open >/dev/null 2>&1; then
    open "$OPENAI_KEYS_URL" >/dev/null 2>&1 || true
  else
    printf 'Open this page in your browser: %s\n' "$OPENAI_KEYS_URL"
  fi
}

main() {
  local old_key old_suffix new_key="" recommended_name

  case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help|help) usage; return 0 ;;
    *) usage >&2; return 2 ;;
  esac

  check_no_shell_override
  check_target

  old_key="$(read_env_key "$TARGET")"
  old_suffix="$(key_suffix "$old_key")"
  recommended_name="mq-agent-$(date '+%Y-%m-%d')"

  printf 'OpenAI key rotation\n'
  printf 'Target: %s\n' "$TARGET"
  printf 'Current key suffix: ...%s\n' "$old_suffix"
  printf 'Recommended new key name: %s\n' "$recommended_name"

  if (( DRY_RUN == 1 )); then
    printf 'DRY RUN: no browser opened, no key requested, no file changed.\n'
    return 0
  fi

  printf '\nOpening OpenAI Platform. Create a new project API key, then return here.\n'
  open_keys_page

  if [[ -t 0 ]]; then
    printf 'Paste the NEW OpenAI API key (input hidden): ' >&2
    IFS= read -r -s new_key
    printf '\n' >&2
  else
    IFS= read -r new_key || fail "No new key was provided on stdin." 2
  fi

  validate_key_shape "$new_key"

  printf 'Verifying new key before changing %s ...\n' "$TARGET"
  verify_key_before_write "$new_key"
  printf 'New key accepted by OpenAI.\n'

  confirm_install
  write_key_atomically "$new_key"
  verify_persisted_key "$new_key"

  new_key=""
  unset new_key

  printf 'mq-agent credential smoke: PASS\n'
  printf 'Permissions set to 600: %s\n' "$TARGET"

  if [[ "$old_suffix" != "none" ]]; then
    printf '\nOld key to revoke: ...%s\n' "$old_suffix"
    printf 'Opening OpenAI Platform again. Revoke the old key with that suffix.\n'
    open_keys_page
  else
    printf '\nNo previous key was present in %s; there is nothing to revoke there.\n' "$TARGET"
  fi

  printf 'Rotation staged successfully. The old key is not deleted automatically in v1.\n'
}

main "$@"
