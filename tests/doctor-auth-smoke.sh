#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/security" <<'STUB'
#!/usr/bin/env bash
[[ "${TEST_KEYCHAIN:-missing}" != missing ]] || exit 44
printf '%s' "$TEST_KEYCHAIN"
STUB
chmod +x "$TMP/security"
# No live network or real credential store is consulted by this test.
printf '#!/usr/bin/env bash\nexit 7\n' > "$TMP/curl"
chmod +x "$TMP/curl"
run_case() {
  local keychain="$1" env_key="$2" expected="$3" mode out rc
  for mode in json human plan plan-json; do
    local -a args=("")
    case "$mode" in
      json) args=(--json);;
      plan) args=(--fix-plan);;
      plan-json) args=(--fix-plan --json);;
    esac
    set +e
    out="$(env -u OPENAI_API_KEY TEST_KEYCHAIN="$keychain" OPENAI_API_KEY="$env_key" \
      PATH="$TMP:$PATH" MQ_SECURITY_BIN="$TMP/security" MQ_OPENAI_KEYCHAIN_ACCOUNT=test-user \
      MACOS_SCRIPTS_HOME="$ROOT" bash "$ROOT/tools/scripts/doctor.sh" "${args[@]}" 2>&1)"
    rc=$?
    set -e
    [[ "$out" != *sk-test-* ]] || { echo 'FAIL: credential leaked'; exit 1; }
    case "$mode" in
      json|plan-json)
        python3 -c 'import json,sys; d=json.load(sys.stdin); d=d.get("source",d); c=next(c for c in d["checks"] if c["name"]=="OPENAI_API_KEY"); assert c["status"]==sys.argv[1],c' "$expected" <<<"$out";;
      human)
        if [[ "$expected" == ok ]]; then
          [[ "$out" == *'OpenAI credential available'* ]] || { echo "FAIL: $mode $keychain $env_key"; exit 1; }
        else
          [[ "$out" == *'OpenAI credential needs attention'* ]] || exit 1
        fi;;
      plan)
        if [[ "$expected" == ok ]]; then
          [[ "$out" != *'OPENAI_API_KEY'* ]] || exit 1
        else
          [[ "$out" == *'mqlaunch auth status'* && $rc -eq 1 ]] || exit 1
        fi;;
    esac
  done
  echo "PASS: $expected across all doctor modes"
}
run_case sk-test-keychain '' ok
run_case sk-test-keychain sk-test-keychain ok
run_case missing sk-test-env ok
run_case sk-test-keychain sk-test-different warn
run_case missing '' warn
echo 'OK: doctor accepts Keychain and detects conflicts without leaking credentials'
