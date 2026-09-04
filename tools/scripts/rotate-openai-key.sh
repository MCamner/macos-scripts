#!/usr/bin/env bash
set -euo pipefail
set +x

umask 077

MQ_AGENT_HOME="${MQ_AGENT_HOME:-$HOME/mq-agent}"
OPENAI_KEYS_URL="${MQ_OPENAI_KEYS_URL:-https://platform.openai.com/api-keys}"
OPENAI_VERIFY_URL="${MQ_OPENAI_VERIFY_URL:-https://api.openai.com/v1/models}"
KEYCHAIN_SERVICE="${MQ_OPENAI_KEYCHAIN_SERVICE:-mq-openai-api-key}"
KEYCHAIN_ACCOUNT="${MQ_OPENAI_KEYCHAIN_ACCOUNT:-${USER:-$(id -un)}}"
SECURITY_BIN="${MQ_SECURITY_BIN:-/usr/bin/security}"
DRY_RUN=0

usage() {
  cat <<'USAGE'
rotate-openai-key.sh - safely rotate the OpenAI key used by MQ tools

Usage:
  rotate-openai-key.sh [--dry-run]

Credential model:
  macOS Keychain is the canonical local store. codex-mq / claude-mq read the
  Keychain item and expose OPENAI_API_KEY only to the launched process and its
  descendants. No repository .env file is written.

Flow:
  1. Refuse permanent shell overrides that would bypass the Keychain model.
  2. Read only the old key suffix from the current Keychain credential.
  3. Open OpenAI Platform so the operator can create a new key.
  4. Read the new key without echoing it and verify it before local mutation.
  5. Ask explicitly before updating the Keychain item.
  6. Read the Keychain item back and smoke-test it through mq-agent's uv env.
  7. Roll back the Keychain item automatically if readback or smoke fails.
  8. Re-open the key page and show only the old suffix for manual revoke.

The secret is never accepted as a command-line argument and is never printed.
The old OpenAI key is never revoked automatically in v1.
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

check_no_shell_override() {
  local startup file hits=()

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    fail "OPENAI_API_KEY is already exported in this shell. Run 'unset OPENAI_API_KEY' before rotating so Keychain remains the single credential source." 2
  fi

  for startup in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" \
                 "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    if [[ -f "$startup" ]] \
       && grep -Eq '^[[:space:]]*(export[[:space:]]+)?OPENAI_API_KEY=[^[:space:]]+[[:space:]]*$' "$startup"; then
      hits+=("$startup")
    fi
  done

  if (( ${#hits[@]} > 0 )); then
    printf 'ERROR: a shell startup file still contains a persistent OPENAI_API_KEY assignment:\n' >&2
    for file in "${hits[@]}"; do
      printf '  %s\n' "$file" >&2
    done
    printf 'Remove the persistent assignment before rotating. Process-scoped wrapper lines such as env OPENAI_API_KEY="$key" codex are allowed.\n' >&2
    exit 2
  fi
}

validate_keychain_selector() {
  local value="$1" name="$2"
  [[ "$value" =~ ^[A-Za-z0-9._@+-]+$ ]] \
    || fail "$name contains unsupported characters for the secret-safe Keychain command path." 2
}

check_prerequisites() {
  [[ -x "$SECURITY_BIN" ]] || fail "macOS Keychain command not found or not executable: $SECURITY_BIN"
  [[ -d "$MQ_AGENT_HOME" ]] || fail "mq-agent directory not found: $MQ_AGENT_HOME"
  command -v curl >/dev/null 2>&1 || fail "curl is required to verify the new key."
  command -v uv >/dev/null 2>&1 || fail "uv is required for the mq-agent credential smoke test."
  validate_keychain_selector "$KEYCHAIN_ACCOUNT" "Keychain account"
  validate_keychain_selector "$KEYCHAIN_SERVICE" "Keychain service"
}

read_keychain_key() {
  "$SECURITY_BIN" find-generic-password \
    -a "$KEYCHAIN_ACCOUNT" \
    -s "$KEYCHAIN_SERVICE" \
    -w 2>/dev/null
}

write_keychain_key() {
  local key="$1"

  # `security add-generic-password -w <value>` exposes <value> in argv. Leaving
  # -w without a value is TTY-interactive and cannot consume our already-read
  # secret from a pipe. Instead run security's documented interactive command
  # mode: the command arrives on stdin, while the security process argv contains
  # no credential. Account/service are restricted above to parser-safe chars;
  # OpenAI keys are restricted by validate_key_shape before this is called.
  printf 'add-generic-password -a %s -s %s -U -w %s\n' \
    "$KEYCHAIN_ACCOUNT" "$KEYCHAIN_SERVICE" "$key" \
    | "$SECURITY_BIN" -q -i >/dev/null 2>&1
}

delete_keychain_key() {
  "$SECURITY_BIN" delete-generic-password \
    -a "$KEYCHAIN_ACCOUNT" \
    -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1
}

validate_key_shape() {
  local key="$1"
  [[ "$key" =~ ^sk-[A-Za-z0-9_-]{20,}$ ]] \
    || fail "The pasted value does not look like a complete OpenAI API key. Nothing was changed." 2
}

verify_key_before_write() {
  local key="$1" http_code

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
  printf 'Install the verified key into macOS Keychain service %s? [y/N] ' "$KEYCHAIN_SERVICE" >&2
  IFS= read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) fail "Rotation cancelled. Nothing was changed." 2 ;;
  esac
}

credential_smoke() {
  local key="$1"

  # The read-back Keychain value is passed only in this child process environment.
  # No .env file is loaded, and the smoke touches no route/execution stores.
  OPENAI_API_KEY="$key" \
    uv run --project "$MQ_AGENT_HOME" python - <<'PY' >/dev/null
from openai import OpenAI

OpenAI().models.list()
PY
}

rollback_keychain() {
  local had_old="$1" old_key="$2"

  if [[ "$had_old" == "1" ]]; then
    if ! write_keychain_key "$old_key"; then
      return 1
    fi
    local restored
    restored="$(read_keychain_key)" || return 1
    [[ "$restored" == "$old_key" ]]
  else
    delete_keychain_key || true
    if read_keychain_key >/dev/null 2>&1; then
      return 1
    fi
  fi
}

open_keys_page() {
  if command -v open >/dev/null 2>&1; then
    open "$OPENAI_KEYS_URL" >/dev/null 2>&1 || true
  else
    printf 'Open this page in your browser: %s\n' "$OPENAI_KEYS_URL"
  fi
}

main() {
  local old_key="" old_suffix new_key="" saved_key="" recommended_name had_old=0

  case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help|help) usage; return 0 ;;
    *) usage >&2; return 2 ;;
  esac

  check_no_shell_override
  check_prerequisites

  if old_key="$(read_keychain_key)"; then
    had_old=1
  else
    old_key=""
  fi
  old_suffix="$(key_suffix "$old_key")"
  recommended_name="mq-agent-$(date '+%Y-%m-%d')"

  printf 'OpenAI key rotation\n'
  printf 'Credential store: macOS Keychain\n'
  printf 'Service: %s\n' "$KEYCHAIN_SERVICE"
  printf 'Account: %s\n' "$KEYCHAIN_ACCOUNT"
  printf 'Current key suffix: ...%s\n' "$old_suffix"
  printf 'Recommended new key name: %s\n' "$recommended_name"

  if (( DRY_RUN == 1 )); then
    printf 'DRY RUN: no browser opened, no key requested, no Keychain item changed.\n'
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

  printf 'Verifying new key before changing Keychain ...\n'
  verify_key_before_write "$new_key"
  printf 'New key accepted by OpenAI.\n'

  confirm_install

  if ! write_keychain_key "$new_key"; then
    fail "Could not update the Keychain item. The old OpenAI key was not revoked."
  fi

  if ! saved_key="$(read_keychain_key)" || [[ "$saved_key" != "$new_key" ]]; then
    if rollback_keychain "$had_old" "$old_key"; then
      fail "Keychain readback did not match the verified key; the previous Keychain state was restored." 2
    fi
    fail "Keychain readback failed and automatic rollback also failed. Do not revoke the old OpenAI key." 1
  fi

  if ! credential_smoke "$saved_key"; then
    if rollback_keychain "$had_old" "$old_key"; then
      fail "mq-agent credential smoke failed; the previous Keychain state was restored. Do not revoke the old OpenAI key." 2
    fi
    fail "mq-agent credential smoke failed and automatic rollback also failed. Do not revoke the old OpenAI key." 1
  fi

  new_key=""
  saved_key=""
  old_key=""
  unset new_key saved_key old_key

  printf 'Keychain readback: PASS\n'
  printf 'mq-agent credential smoke: PASS\n'

  if [[ "$old_suffix" != "none" ]]; then
    printf '\nOld key to revoke later: ...%s\n' "$old_suffix"
    printf 'IMPORTANT: already-running Codex/Claude processes still hold their previous process-scoped environment.\n'
    printf 'Restart those sessions with codex-mq / claude-mq before revoking the old key.\n'
    printf 'Opening OpenAI Platform again for manual revoke when you are ready.\n'
    open_keys_page
  else
    printf '\nNo previous Keychain credential was present; there is no old key from this store to revoke.\n'
  fi

  printf 'Rotation staged successfully. The old OpenAI key is not revoked automatically in v1.\n'
}

main "$@"
