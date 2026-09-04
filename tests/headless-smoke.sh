#!/usr/bin/env bash
set -euo pipefail

ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
VSCODE_LAUNCHER="$ROOT/tools/scripts/start-vscode-mq.sh"
MAIN_MENU="$ROOT/terminal/menus/mq-main-menu.sh"

echo "SMOKE: mqlaunch headless mode"

echo "[1/7] launcher exists"
test -x "$LAUNCHER"

# doctor exits 1 when a check warns, and a runner without `eza` or `gitleaks`
# always warns. These steps are about pausing and output shape, not about the
# health of the machine running them, so either verdict is acceptable — but a
# timeout is not, and `timeout` reports that as 124. Checking for 0 or 1 keeps
# the hang detectable where a bare `|| true` would swallow it.
run_doctor() {
  # run_doctor <output-file> [args...]
  local out="$1"; shift
  local status=0
  timeout 15 "$LAUNCHER" doctor "$@" </dev/null >"$out" 2>&1 || status=$?
  case "$status" in
    0|1) ;;
    *)
      echo "FAIL: doctor exited $status (124 means it hung)" >&2
      exit 1
      ;;
  esac
}

echo "[2/7] doctor does not pause without TTY"
run_doctor /tmp/mqlaunch-doctor-headless.out
! grep -q "Press Enter" /tmp/mqlaunch-doctor-headless.out
grep -q "MQ DOCTOR" /tmp/mqlaunch-doctor-headless.out

echo "[3/7] explicit headless flag does not pause"
MQLAUNCH_HEADLESS=1 run_doctor /tmp/mqlaunch-doctor-env-headless.out
! grep -q "Press Enter" /tmp/mqlaunch-doctor-env-headless.out

echo "[4/7] doctor json stays machine-readable"
run_doctor /tmp/mqlaunch-doctor-headless.json --json
grep -q '^{"project":"macos-scripts"' /tmp/mqlaunch-doctor-headless.json
! grep -q "Press Enter" /tmp/mqlaunch-doctor-headless.json

echo "[5/7] main menu exposes Keychain-backed VS Code launch"
grep -Fq 'v. VS Code MQ (Keychain)' "$MAIN_MENU"
grep -Fq 'v) bash "$BASE_DIR/tools/scripts/start-vscode-mq.sh" "$PWD"; pause_enter ;;' "$MAIN_MENU"

echo "[6/7] VS Code launch injects Keychain key without printing it"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/project"
secret='sk-test-vscode-key-for-tests'
cat >"$tmp_dir/security" <<EOF
#!/usr/bin/env bash
printf '%s\n' '$secret'
EOF
cat >"$tmp_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$tmp_dir/code" <<'EOF'
#!/usr/bin/env bash
printf 'key=%s\n' "${OPENAI_API_KEY:-}" >"${MQ_VSCODE_TEST_LOG:?}"
printf 'arg=%s\n' "$@" >>"${MQ_VSCODE_TEST_LOG:?}"
EOF
chmod +x "$tmp_dir/security" "$tmp_dir/pgrep" "$tmp_dir/code"

vscode_output="$(
  MQ_SECURITY_BIN="$tmp_dir/security" \
  MQ_PGREP_BIN="$tmp_dir/pgrep" \
  MQ_CODE_BIN="$tmp_dir/code" \
  MQ_VSCODE_TEST_LOG="$tmp_dir/code.log" \
  bash "$VSCODE_LAUNCHER" "$tmp_dir/project"
)"
grep -Fq "key=$secret" "$tmp_dir/code.log"
grep -Fq 'arg=--reuse-window' "$tmp_dir/code.log"
grep -Fq "arg=$tmp_dir/project" "$tmp_dir/code.log"
! grep -Fq "$secret" <<<"$vscode_output"

# The secret belongs in the child environment, not as a command argument.
! grep '^arg=' "$tmp_dir/code.log" | grep -Fq "$secret"

echo "[7/7] VS Code launch refuses an already-running VS Code process"
cat >"$tmp_dir/pgrep-running" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$tmp_dir/pgrep-running"
status=0
MQ_SECURITY_BIN="$tmp_dir/security" \
MQ_PGREP_BIN="$tmp_dir/pgrep-running" \
MQ_CODE_BIN="$tmp_dir/code" \
MQ_VSCODE_TEST_LOG="$tmp_dir/should-not-exist.log" \
  bash "$VSCODE_LAUNCHER" "$tmp_dir/project" >"$tmp_dir/running.out" 2>&1 || status=$?
[[ "$status" -eq 2 ]]
grep -Fq 'VS Code is already running' "$tmp_dir/running.out"
[[ ! -e "$tmp_dir/should-not-exist.log" ]]

echo "OK: mqlaunch headless smoke test passed"
