#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$ROOT/tools/scripts/rotate-openai-key.sh}"
MENU="${MQ_TEST_SYSTEM_MENU:-$ROOT/terminal/menus/mq-system-menu.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME_DIR="$TMP/home"
BIN="$TMP/bin"
LOG="$TMP/log"
KEYCHAIN_FILE="$TMP/keychain-value"
mkdir -p "$HOME_DIR/mq-agent" "$BIN" "$LOG"

cat > "$BIN/open" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MQ_TEST_OPEN_LOG"
STUB
chmod +x "$BIN/open"

cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
printf '%s' "${MQ_TEST_HTTP_CODE:-200}"
STUB
chmod +x "$BIN/curl"

cat > "$BIN/uv" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MQ_TEST_UV_LOG"
cat >/dev/null || true
exit "${MQ_TEST_UV_RC:-0}"
STUB
chmod +x "$BIN/uv"

cat > "$BIN/security" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MQ_TEST_SECURITY_LOG"

if [[ " $* " == *" -i "* ]]; then
  IFS= read -r command || exit 1
  case "$command" in
    add-generic-password*)
      key="${command##* -w }"
      [[ -n "$key" ]] || exit 2
      printf '%s' "$key" > "$MQ_TEST_KEYCHAIN_FILE"
      exit 0
      ;;
    *)
      exit 2
      ;;
  esac
fi

case "${1:-}" in
  find-generic-password)
    [[ -f "$MQ_TEST_KEYCHAIN_FILE" ]] || exit 44
    cat "$MQ_TEST_KEYCHAIN_FILE"
    ;;
  delete-generic-password)
    rm -f "$MQ_TEST_KEYCHAIN_FILE"
    ;;
  *)
    exit 2
    ;;
esac
STUB
chmod +x "$BIN/security"

export PATH="$BIN:/usr/bin:/bin"
export MQ_TEST_OPEN_LOG="$LOG/open.log"
export MQ_TEST_UV_LOG="$LOG/uv.log"
export MQ_TEST_SECURITY_LOG="$LOG/security.log"
export MQ_TEST_KEYCHAIN_FILE="$KEYCHAIN_FILE"
export MQ_AGENT_HOME="$HOME_DIR/mq-agent"
export MQ_SECURITY_BIN="$BIN/security"
export MQ_OPENAI_KEYCHAIN_SERVICE="mq-openai-api-key"
export MQ_OPENAI_KEYCHAIN_ACCOUNT="test-user"

# Synthetic values deliberately avoid real provider token prefixes while still
# satisfying the helper's generic `sk-...` shape check.
OLD='sk-test-old-key-material-for-tests-VpEA'
NEW='sk-test-new-key-material-for-tests-Zq8A'

reset_old_key() {
  printf '%s' "$OLD" > "$KEYCHAIN_FILE"
  : > "$MQ_TEST_OPEN_LOG"
  : > "$MQ_TEST_UV_LOG"
  : > "$MQ_TEST_SECURITY_LOG"
}

reset_old_key

printf '[1/8] mqlaunch maintenance exposes the safe rotation helper\n'
[[ -f "$MENU" ]]
grep -Fq '"3. Rotate OpenAI API key"' "$MENU"
grep -Fq 'tools/scripts/rotate-openai-key.sh' "$MENU"
printf '  ok\n'

printf '[2/8] successful rotation updates Keychain, verifies readback, and keeps secrets quiet\n'
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT")"
[[ "$(cat "$KEYCHAIN_FILE")" == "$NEW" ]]
[[ ! -e "$MQ_AGENT_HOME/.env" ]]
[[ "$(wc -l < "$MQ_TEST_OPEN_LOG" | tr -d ' ')" == "2" ]]
grep -q 'run --project' "$MQ_TEST_UV_LOG"
grep -q 'Keychain readback: PASS' <<<"$out"
grep -q 'mq-agent credential smoke: PASS' <<<"$out"
grep -q 'Old key to revoke later: ...VpEA' <<<"$out"
grep -q 'Restart those sessions with codex-mq / claude-mq before revoking' <<<"$out"
! grep -q "$OLD" <<<"$out"
! grep -q "$NEW" <<<"$out"
! grep -q "$OLD" "$MQ_TEST_SECURITY_LOG"
! grep -q "$NEW" "$MQ_TEST_SECURITY_LOG"
grep -q -- '-q -i' "$MQ_TEST_SECURITY_LOG"
printf '  ok\n'

printf '[3/8] cancelling after verification leaves the old Keychain value untouched\n'
reset_old_key
set +e
out="$(printf '%s\nn\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT" 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]]
grep -q 'Rotation cancelled' <<<"$out"
[[ "$(cat "$KEYCHAIN_FILE")" == "$OLD" ]]
[[ "$(wc -l < "$MQ_TEST_OPEN_LOG" | tr -d ' ')" == "1" ]]
[[ ! -s "$MQ_TEST_UV_LOG" ]]
printf '  ok\n'

printf '[4/8] an exported shell override is refused before anything changes\n'
reset_old_key
set +e
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" OPENAI_API_KEY="$OLD" "$SCRIPT" 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]]
grep -q 'single credential source' <<<"$out"
[[ "$(cat "$KEYCHAIN_FILE")" == "$OLD" ]]
[[ ! -s "$MQ_TEST_OPEN_LOG" ]]
printf '  ok\n'

printf '[5/8] process-scoped wrappers are allowed but persistent startup exports are refused\n'
reset_old_key
cat > "$HOME_DIR/.zshrc" <<'ZSHRC'
codex-mq() {
  local key
  env OPENAI_API_KEY="$key" codex "$@"
}
ZSHRC
out="$(HOME="$HOME_DIR" "$SCRIPT" --dry-run)"
grep -q 'DRY RUN' <<<"$out"
printf 'export OPENAI_API_KEY=%s\n' "$OLD" >> "$HOME_DIR/.zshrc"
set +e
out="$(HOME="$HOME_DIR" "$SCRIPT" --dry-run 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]]
grep -q "$HOME_DIR/.zshrc" <<<"$out"
! grep -q "$OLD" <<<"$out"
rm "$HOME_DIR/.zshrc"
printf '  ok\n'

printf '[6/8] a rejected new key leaves the old Keychain credential untouched\n'
reset_old_key
export MQ_TEST_HTTP_CODE=401
set +e
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT" 2>&1)"
rc=$?
set -e
unset MQ_TEST_HTTP_CODE
[[ $rc -eq 2 ]]
grep -q 'HTTP 401' <<<"$out"
[[ "$(cat "$KEYCHAIN_FILE")" == "$OLD" ]]
[[ ! -s "$MQ_TEST_UV_LOG" ]]
printf '  ok\n'

printf '[7/8] a failed mq-agent smoke rolls Keychain back to the previous credential\n'
reset_old_key
export MQ_TEST_UV_RC=1
set +e
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT" 2>&1)"
rc=$?
set -e
unset MQ_TEST_UV_RC
[[ $rc -eq 2 ]]
grep -q 'previous Keychain state was restored' <<<"$out"
[[ "$(cat "$KEYCHAIN_FILE")" == "$OLD" ]]
[[ "$(wc -l < "$MQ_TEST_OPEN_LOG" | tr -d ' ')" == "1" ]]
! grep -q "$OLD" <<<"$out"
! grep -q "$NEW" <<<"$out"
printf '  ok\n'

printf '[8/8] dry-run reveals only safe Keychain metadata and changes nothing\n'
reset_old_key
before="$(cat "$KEYCHAIN_FILE")"
out="$(HOME="$HOME_DIR" "$SCRIPT" --dry-run)"
after="$(cat "$KEYCHAIN_FILE")"
[[ "$before" == "$after" ]]
grep -q 'Credential store: macOS Keychain' <<<"$out"
grep -q 'Current key suffix: ...VpEA' <<<"$out"
grep -q 'DRY RUN' <<<"$out"
[[ ! -s "$MQ_TEST_OPEN_LOG" ]]
[[ ! -s "$MQ_TEST_UV_LOG" ]]
! grep -q "$OLD" <<<"$out"
printf '  ok\n'

printf 'OK: OpenAI Keychain rotation smoke passed\n'
