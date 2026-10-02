#!/usr/bin/env bash
set -euo pipefail
set +x

KEYCHAIN_SERVICE="${MQ_OPENAI_KEYCHAIN_SERVICE:-mq-openai-api-key}"
KEYCHAIN_ACCOUNT="${MQ_OPENAI_KEYCHAIN_ACCOUNT:-${USER:-$(id -un)}}"
SECURITY_BIN="${MQ_SECURITY_BIN:-/usr/bin/security}"
CURL_BIN="${MQ_CURL_BIN:-$(command -v curl 2>/dev/null || true)}"
OPENAI_VERIFY_URL="${MQ_OPENAI_VERIFY_URL:-https://api.openai.com/v1/models}"

usage() {
  cat <<'USAGE'
Usage:
  mqlaunch auth status [--json]
  mqlaunch auth test openai [--json]

status is local-only and never makes a network request.
test openai makes an explicit API request. It tests OPENAI_API_KEY when the
current process has one; otherwise it falls back to the canonical macOS
Keychain credential used by MQ wrappers.

No credential value is printed.
USAGE
}

usage_error() {
  printf 'ERROR: %s\n' "$1" >&2
  usage >&2
  return 2
}

validate_selector() {
  local value="$1" name="$2"
  [[ "$value" =~ ^[A-Za-z0-9._@+-]+$ ]] || {
    printf 'ERROR: %s contains unsupported characters.\n' "$name" >&2
    return 2
  }
}

read_keychain_key() {
  "$SECURITY_BIN" find-generic-password \
    -a "$KEYCHAIN_ACCOUNT" \
    -s "$KEYCHAIN_SERVICE" \
    -w 2>/dev/null
}

parse_json_flag() {
  local arg
  JSON_MODE=0
  for arg in "$@"; do
    case "$arg" in
      --json) JSON_MODE=1 ;;
      *) usage_error "unknown option: $arg"; return $? ;;
    esac
  done
}

status_command() {
  parse_json_flag "$@" || return $?
  validate_selector "$KEYCHAIN_ACCOUNT" "Keychain account" || return $?
  validate_selector "$KEYCHAIN_SERVICE" "Keychain service" || return $?

  local env_key="${OPENAI_API_KEY:-}"
  local keychain_key="" keychain_state="unavailable"
  local env_state="missing" consistency="not-comparable" effective_source="none"
  local overall="warn" rc=1

  [[ -n "$env_key" ]] && env_state="present"

  if [[ -x "$SECURITY_BIN" ]]; then
    if keychain_key="$(read_keychain_key)"; then
      keychain_state="present"
    else
      keychain_state="missing"
    fi
  fi

  if [[ "$env_state" == "present" && "$keychain_state" == "present" ]]; then
    if [[ "$env_key" == "$keychain_key" ]]; then
      consistency="match"
    else
      consistency="different"
    fi
  elif [[ "$keychain_state" == "unavailable" ]]; then
    consistency="unknown"
  fi

  if [[ "$env_state" == "present" ]]; then
    effective_source="environment"
  elif [[ "$keychain_state" == "present" ]]; then
    effective_source="keychain"
  fi

  if [[ "$env_state" == "present" && "$keychain_state" == "present" && "$consistency" == "match" ]]; then
    overall="ok"
    rc=0
  elif [[ "$env_state" == "missing" && "$keychain_state" == "missing" ]]; then
    overall="fail"
  else
    overall="warn"
  fi

  if [[ $JSON_MODE -eq 1 ]]; then
    printf '{"schema":"mq.auth-status.v1","provider":"openai","status":"%s","keychain":{"status":"%s","service":"%s","account":"%s"},"process":{"env":"OPENAI_API_KEY","status":"%s"},"consistency":"%s","effective_source":"%s","api_tested":false}\n' \
      "$overall" "$keychain_state" "$KEYCHAIN_SERVICE" "$KEYCHAIN_ACCOUNT" \
      "$env_state" "$consistency" "$effective_source"
  else
    printf 'MQ AUTH // OPENAI\n'
    printf 'Keychain store: %s\n' "$keychain_state"
    printf 'Keychain item:  %s / %s\n' "$KEYCHAIN_SERVICE" "$KEYCHAIN_ACCOUNT"
    printf 'Process env:    %s (OPENAI_API_KEY)\n' "$env_state"
    printf 'Consistency:    %s\n' "$consistency"
    printf 'Effective:      %s\n' "$effective_source"
    printf 'API tested:     no\n'
    printf 'Status:         %s\n' "$overall"
    if [[ "$consistency" == "different" ]]; then
      printf 'Note: current process credential differs from canonical Keychain.\n'
    elif [[ "$env_state" == "missing" && "$keychain_state" == "present" ]]; then
      printf 'Note: Keychain is available, but this process does not expose OPENAI_API_KEY.\n'
    elif [[ "$env_state" == "present" && "$keychain_state" == "missing" ]]; then
      printf 'Note: this process has a credential, but the canonical Keychain item is missing.\n'
    elif [[ "$keychain_state" == "unavailable" ]]; then
      printf 'Note: macOS Keychain could not be inspected from this process.\n'
    fi
  fi

  env_key=""
  keychain_key=""
  unset env_key keychain_key
  return "$rc"
}

test_openai() {
  parse_json_flag "$@" || return $?
  validate_selector "$KEYCHAIN_ACCOUNT" "Keychain account" || return $?
  validate_selector "$KEYCHAIN_SERVICE" "Keychain service" || return $?

  local key="" source="none" http_code="" reason="" overall="fail"
  local curl_rc=0 rc=1

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    key="$OPENAI_API_KEY"
    source="environment"
  elif [[ -x "$SECURITY_BIN" ]] && key="$(read_keychain_key)"; then
    source="keychain"
  else
    reason="credential-missing"
  fi

  if [[ "$source" == "none" ]]; then
    if [[ $JSON_MODE -eq 1 ]]; then
      printf '{"schema":"mq.auth-test.v1","provider":"openai","status":"fail","source":"none","http_status":null,"reason":"%s"}\n' "$reason"
    else
      printf 'MQ AUTH TEST // OPENAI\n'
      printf 'Source:      none\n'
      printf 'Result:      FAIL\n'
      printf 'Reason:      no process or Keychain credential is available\n'
    fi
    return 1
  fi

  if [[ -z "$CURL_BIN" || ! -x "$CURL_BIN" ]]; then
    reason="curl-missing"
  else
    set +e
    http_code="$({
      printf 'header = "Authorization: Bearer %s"\n' "$key"
    } | "$CURL_BIN" --config - --silent --show-error --output /dev/null \
        --write-out '%{http_code}' "$OPENAI_VERIFY_URL")"
    curl_rc=$?
    set -e

    if [[ $curl_rc -ne 0 ]]; then
      reason="network-error"
      http_code=""
    else
      case "$http_code" in
        200)
          overall="ok"
          reason="accepted"
          rc=0
          ;;
        401)
          reason="rejected"
          ;;
        403)
          reason="forbidden"
          ;;
        429)
          overall="warn"
          reason="rate-limited"
          ;;
        *)
          reason="http-error"
          ;;
      esac
    fi
  fi

  key=""
  unset key

  if [[ $JSON_MODE -eq 1 ]]; then
    if [[ -n "$http_code" ]]; then
      printf '{"schema":"mq.auth-test.v1","provider":"openai","status":"%s","source":"%s","http_status":%s,"reason":"%s"}\n' \
        "$overall" "$source" "$http_code" "$reason"
    else
      printf '{"schema":"mq.auth-test.v1","provider":"openai","status":"%s","source":"%s","http_status":null,"reason":"%s"}\n' \
        "$overall" "$source" "$reason"
    fi
  else
    printf 'MQ AUTH TEST // OPENAI\n'
    printf 'Source:      %s\n' "$source"
    printf 'API request: yes\n'
    [[ -n "$http_code" ]] && printf 'HTTP:        %s\n' "$http_code"
    case "$overall" in
      ok) printf 'Result:      PASS\n' ;;
      warn) printf 'Result:      WARN\n' ;;
      *) printf 'Result:      FAIL\n' ;;
    esac
    printf 'Reason:      %s\n' "$reason"
  fi

  return "$rc"
}

main() {
  local command="${1:-}"
  case "$command" in
    status)
      shift
      status_command "$@"
      ;;
    test)
      shift
      local provider="${1:-}"
      [[ -n "$provider" ]] || { usage_error "missing provider for auth test"; return $?; }
      shift
      case "$provider" in
        openai) test_openai "$@" ;;
        *) usage_error "unsupported auth provider: $provider" ;;
      esac
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      usage_error "unknown auth command: $command"
      ;;
  esac
}

main "$@"
