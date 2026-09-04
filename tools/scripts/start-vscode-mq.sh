#!/usr/bin/env bash
set -euo pipefail

KEYCHAIN_SERVICE="${MQ_OPENAI_KEYCHAIN_SERVICE:-mq-openai-api-key}"
KEYCHAIN_ACCOUNT="${MQ_OPENAI_KEYCHAIN_ACCOUNT:-${USER:-$(id -un)}}"
SECURITY_BIN="${MQ_SECURITY_BIN:-/usr/bin/security}"
PGREP_BIN="${MQ_PGREP_BIN:-/usr/bin/pgrep}"
TARGET="${1:-$PWD}"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit "${2:-1}"
}

if [[ ! -e "$TARGET" ]]; then
  fail "VS Code target does not exist: $TARGET" 2
fi

if [[ -x "$PGREP_BIN" ]] && "$PGREP_BIN" -f '/Visual Studio Code\.app/Contents/MacOS/Electron' >/dev/null 2>&1; then
  fail "VS Code is already running. Quit it fully with Cmd+Q, then launch it from mqlaunch so Claude/Codex inherit the Keychain-backed API key." 2
fi

CODE_BIN="${MQ_CODE_BIN:-}"
if [[ -z "$CODE_BIN" ]]; then
  CODE_BIN="$(command -v code || true)"
fi
if [[ -z "$CODE_BIN" && -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi
[[ -n "$CODE_BIN" ]] || fail "VS Code CLI 'code' was not found. Install the Shell Command from VS Code or set MQ_CODE_BIN." 2
[[ -x "$CODE_BIN" ]] || fail "VS Code launcher is not executable: $CODE_BIN" 2

key="$($SECURITY_BIN find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)" || \
  fail "OpenAI API key is missing from macOS Keychain service '$KEYCHAIN_SERVICE'." 1
[[ -n "$key" ]] || fail "OpenAI API key in macOS Keychain is empty." 1

printf 'Starting VS Code with Keychain-backed OPENAI_API_KEY for: %s\n' "$TARGET"
OPENAI_API_KEY="$key" "$CODE_BIN" --reuse-window "$TARGET"
status=$?

key=''
unset key
exit "$status"
