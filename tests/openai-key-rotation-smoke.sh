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
exit "${MQ_TEST_UV_RC:-0}"
STUB
chmod +x "$BIN/uv"

export PATH="$BIN:/usr/bin:/bin"
export MQ_TEST_OPEN_LOG="$LOG/open.log"
export MQ_TEST_UV_LOG="$LOG/uv.log"
export MQ_AGENT_HOME="$HOME_DIR/mq-agent"
export MQ_OPENAI_KEY_TARGET="$HOME_DIR/mq-agent/.env"

# Synthetic values deliberately avoid real provider token prefixes while still
# satisfying the helper's generic `sk-...` shape check.
OLD='sk-test-old-key-material-for-tests-VpEA'
NEW='sk-test-new-key-material-for-tests-Zq8A'

printf 'FOO=one\nOPENAI_API_KEY=%s\nBAR=two\n' "$OLD" > "$MQ_OPENAI_KEY_TARGET"
chmod 644 "$MQ_OPENAI_KEY_TARGET"

printf '[1/7] mqlaunch maintenance exposes the safe rotation helper\n'
[[ -f "$MENU" ]]
grep -Fq '"3. Rotate OpenAI API key"' "$MENU"
grep -Fq 'tools/scripts/rotate-openai-key.sh' "$MENU"
printf '  ok\n'

printf '[2/7] successful rotation is atomic, confirmed, quiet, and preserves the env file\n'
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT")"
grep -q '^FOO=one$' "$MQ_OPENAI_KEY_TARGET"
grep -q "^OPENAI_API_KEY=$NEW$" "$MQ_OPENAI_KEY_TARGET"
grep -q '^BAR=two$' "$MQ_OPENAI_KEY_TARGET"
mode="$(python3 - "$MQ_OPENAI_KEY_TARGET" <<'PY'
import os, stat, sys
print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))
PY
)"
[[ "$mode" == "0o600" ]]
[[ "$(wc -l < "$MQ_TEST_OPEN_LOG" | tr -d ' ')" == "2" ]]
grep -q 'run --project' "$MQ_TEST_UV_LOG"
grep -q 'Old key to revoke: ...VpEA' <<<"$out"
! grep -q "$OLD" <<<"$out"
! grep -q "$NEW" <<<"$out"
printf '  ok\n'

printf '[3/7] cancelling after verification leaves the old file untouched\n'
printf 'OPENAI_API_KEY=%s\n' "$OLD" > "$MQ_OPENAI_KEY_TARGET"
: > "$MQ_TEST_OPEN_LOG"
: > "$MQ_TEST_UV_LOG"
set +e
out="$(printf '%s\nn\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT" 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]]
grep -q 'Rotation cancelled' <<<"$out"
grep -q "$OLD" "$MQ_OPENAI_KEY_TARGET"
[[ "$(wc -l < "$MQ_TEST_OPEN_LOG" | tr -d ' ')" == "1" ]]
[[ ! -s "$MQ_TEST_UV_LOG" ]]
printf '  ok\n'

printf '[4/7] a shell override is refused before anything changes\n'
printf 'OPENAI_API_KEY=%s\n' "$OLD" > "$MQ_OPENAI_KEY_TARGET"
: > "$MQ_TEST_OPEN_LOG"
set +e
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" OPENAI_API_KEY="$OLD" "$SCRIPT" 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]]
grep -q 'would override' <<<"$out"
grep -q "$OLD" "$MQ_OPENAI_KEY_TARGET"
[[ ! -s "$MQ_TEST_OPEN_LOG" ]]
printf '  ok\n'

printf '[5/7] a startup-file assignment is refused without printing the secret\n'
printf 'export OPENAI_API_KEY=%s\n' "$OLD" > "$HOME_DIR/.zshrc"
set +e
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT" 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]]
grep -q "$HOME_DIR/.zshrc" <<<"$out"
! grep -q "$OLD" <<<"$out"
rm "$HOME_DIR/.zshrc"
printf '  ok\n'

printf '[6/7] a rejected new key leaves the old file untouched\n'
printf 'OPENAI_API_KEY=%s\n' "$OLD" > "$MQ_OPENAI_KEY_TARGET"
: > "$MQ_TEST_UV_LOG"
export MQ_TEST_HTTP_CODE=401
set +e
out="$(printf '%s\ny\n' "$NEW" | HOME="$HOME_DIR" "$SCRIPT" 2>&1)"
rc=$?
set -e
unset MQ_TEST_HTTP_CODE
[[ $rc -eq 2 ]]
grep -q 'HTTP 401' <<<"$out"
grep -q "$OLD" "$MQ_OPENAI_KEY_TARGET"
[[ ! -s "$MQ_TEST_UV_LOG" ]]
printf '  ok\n'

printf '[7/7] dry-run reveals only safe metadata and changes nothing\n'
before="$(cat "$MQ_OPENAI_KEY_TARGET")"
out="$(HOME="$HOME_DIR" "$SCRIPT" --dry-run)"
after="$(cat "$MQ_OPENAI_KEY_TARGET")"
[[ "$before" == "$after" ]]
grep -q 'Current key suffix: ...VpEA' <<<"$out"
grep -q 'DRY RUN' <<<"$out"
! grep -q "$OLD" <<<"$out"
printf '  ok\n'

printf 'OK: OpenAI key rotation smoke passed\n'
