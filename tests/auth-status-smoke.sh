#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$ROOT/tools/scripts/auth.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
KEYCHAIN_FILE="$TMP/keychain"
CURL_LOG="$TMP/curl.log"
mkdir -p "$BIN"

cat > "$BIN/security" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  find-generic-password)
    [[ -f "$MQ_TEST_KEYCHAIN_FILE" ]] || exit 44
    cat "$MQ_TEST_KEYCHAIN_FILE"
    ;;
  *) exit 2 ;;
esac
STUB
chmod +x "$BIN/security"

cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cfg="$(cat)"
printf 'called\n' >> "$MQ_TEST_CURL_LOG"
case "$cfg" in
  *"env-stale"*) printf '%s' 401 ;;
  *) printf '%s' "${MQ_TEST_HTTP_CODE:-200}" ;;
esac
STUB
chmod +x "$BIN/curl"

export MQ_SECURITY_BIN="$BIN/security"
export MQ_CURL_BIN="$BIN/curl"
export MQ_TEST_KEYCHAIN_FILE="$KEYCHAIN_FILE"
export MQ_TEST_CURL_LOG="$CURL_LOG"
export MQ_OPENAI_KEYCHAIN_ACCOUNT="test-user"
export MQ_OPENAI_KEYCHAIN_SERVICE="mq-openai-api-key"
: > "$CURL_LOG"

KEYCHAIN_KEY='sk-test-keychain-material-123456789'
ENV_KEY='sk-test-env-material-123456789'
STALE='sk-test-env-stale-material-123456789'

printf '[1/8] syntax and help\n'
bash -n "$SCRIPT"
out="$("$SCRIPT" --help)"
grep -q 'auth status' <<<"$out"
grep -q 'auth test openai' <<<"$out"
printf '  ok\n'

printf '[2/8] matching process and Keychain are locally ok\n'
printf '%s' "$KEYCHAIN_KEY" > "$KEYCHAIN_FILE"
set +e
out="$(OPENAI_API_KEY="$KEYCHAIN_KEY" "$SCRIPT" status)"
rc=$?
set -e
[[ $rc -eq 0 ]]
grep -q 'Keychain store: present' <<<"$out"
grep -q 'Process env:    present' <<<"$out"
grep -q 'Consistency:    match' <<<"$out"
grep -q 'Status:         ok' <<<"$out"
! grep -q "$KEYCHAIN_KEY" <<<"$out"
[[ ! -s "$CURL_LOG" ]]
printf '  ok\n'

printf '[3/8] Keychain-only is reported separately and stays local-only\n'
: > "$CURL_LOG"
set +e
out="$(env -u OPENAI_API_KEY "$SCRIPT" status)"
rc=$?
set -e
[[ $rc -eq 1 ]]
grep -q 'Keychain store: present' <<<"$out"
grep -q 'Process env:    missing' <<<"$out"
grep -q 'Effective:      keychain' <<<"$out"
grep -q 'Status:         warn' <<<"$out"
[[ ! -s "$CURL_LOG" ]]
! grep -q "$KEYCHAIN_KEY" <<<"$out"
printf '  ok\n'

printf '[4/8] differing process and Keychain credentials are visible without values\n'
set +e
out="$(OPENAI_API_KEY="$ENV_KEY" "$SCRIPT" status)"
rc=$?
set -e
[[ $rc -eq 1 ]]
grep -q 'Consistency:    different' <<<"$out"
grep -q 'current process credential differs' <<<"$out"
! grep -q "$ENV_KEY" <<<"$out"
! grep -q "$KEYCHAIN_KEY" <<<"$out"
printf '  ok\n'

printf '[5/8] API test falls back to Keychain when process env is absent\n'
: > "$CURL_LOG"
out="$(env -u OPENAI_API_KEY "$SCRIPT" test openai)"
grep -q 'Source:      keychain' <<<"$out"
grep -q 'HTTP:        200' <<<"$out"
grep -q 'Result:      PASS' <<<"$out"
[[ "$(wc -l < "$CURL_LOG" | tr -d ' ')" == "1" ]]
! grep -q "$KEYCHAIN_KEY" <<<"$out"
printf '  ok\n'

printf '[6/8] API test prefers current process env and exposes a stale credential\n'
: > "$CURL_LOG"
set +e
out="$(OPENAI_API_KEY="$STALE" "$SCRIPT" test openai)"
rc=$?
set -e
[[ $rc -eq 1 ]]
grep -q 'Source:      environment' <<<"$out"
grep -q 'HTTP:        401' <<<"$out"
grep -q 'Result:      FAIL' <<<"$out"
grep -q 'Reason:      rejected' <<<"$out"
! grep -q "$STALE" <<<"$out"
printf '  ok\n'

printf '[7/8] no credential fails before network access\n'
rm -f "$KEYCHAIN_FILE"
: > "$CURL_LOG"
set +e
out="$(env -u OPENAI_API_KEY "$SCRIPT" test openai)"
rc=$?
set -e
[[ $rc -eq 1 ]]
grep -q 'Source:      none' <<<"$out"
grep -q 'no process or Keychain credential' <<<"$out"
[[ ! -s "$CURL_LOG" ]]
printf '  ok\n'

printf '[8/8] JSON contracts are parseable and secret-free\n'
printf '%s' "$KEYCHAIN_KEY" > "$KEYCHAIN_FILE"
env -u OPENAI_API_KEY "$SCRIPT" status --json > "$TMP/status.json" || true
env -u OPENAI_API_KEY "$SCRIPT" test openai --json > "$TMP/test.json"
python3 - "$TMP/status.json" "$TMP/test.json" <<'PY'
import json
import sys

status = json.load(open(sys.argv[1], encoding="utf-8"))
test = json.load(open(sys.argv[2], encoding="utf-8"))

assert status["schema"] == "mq.auth-status.v1"
assert status["keychain"]["status"] == "present"
assert status["process"]["status"] == "missing"
assert status["api_tested"] is False
assert test["schema"] == "mq.auth-test.v1"
assert test["status"] == "ok"
assert test["source"] == "keychain"
assert test["http_status"] == 200
PY
! grep -q "$KEYCHAIN_KEY" "$TMP/status.json"
! grep -q "$KEYCHAIN_KEY" "$TMP/test.json"
printf '  ok\n'

printf 'OK: mqlaunch auth credential status and OpenAI API test contracts passed\n'
