#!/usr/bin/env bash
set -euo pipefail

# Without OPENAI_API_KEY, `mqlaunch apps` used to answer questions with a grep
# of the guide. When a local Ollama is running it now answers from the guide
# lines that match the question, and grep stays the last fallback.
#
# The base dir is a copy without .env, and HOME is empty, so no real key is
# loaded. A curl stub plays both APIs and logs what it was sent.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL terminal guide Ollama fallback"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

base="$run_dir/base"
mkdir -p "$base/tools/scripts" "$base/tools/cli" "$base/docs"
cp "$ROOT/tools/scripts/hal-terminal-guide.sh" "$base/tools/scripts/"
cp "$ROOT/tools/cli/mq-vector-store.sh" "$base/tools/cli/"
cat >"$base/docs/mac-terminal-guide.html" <<'HTML'
<script>
  { cat: "Felsökning", cmd: "lsof", shortEn: "List open files and the processes using them" },
      { code: "lsof -i :8080", desc: "Visar vad som använder port 8080" },
  { cat: "Filer", cmd: "ditto", shortEn: "Copy folders and keep metadata" },
</script>
HTML

stubs="$run_dir/stubs"
mkdir -p "$stubs"

# fake_curl <ollama: answer|down> — /api/generate answers or fails; the
# OpenAI endpoint always answers, so a call there is visible in the output.
fake_curl() {
  cat >"$stubs/curl" <<EOF
#!/usr/bin/env bash
url="" data=""
while (( \$# )); do
  case "\$1" in
    -d) data="\$2"; shift 2 ;;
    http*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "\$url" >>"$run_dir/curl.log"
printf '%s' "\$data" >"$run_dir/payload.json"
case "\$url" in
  */api/generate)
    [[ "$1" == "answer" ]] || exit 7
    printf '{"response":"Use lsof -i :8080 to see what holds the port."}' ;;
  https://api.openai.com/*)
    printf '{"output":[{"type":"message","content":[{"type":"output_text","text":"OPENAI_ANSWER"}]}]}' ;;
esac
EOF
  chmod +x "$stubs/curl"
}

ask() {
  # ask <question> [VAR=value]...
  local question="$1"; shift
  rm -f "$run_dir/curl.log" "$run_dir/payload.json"
  env -i HOME="$run_dir/home" PATH="$stubs:$PATH" MACOS_SCRIPTS_HOME="$base" "$@" \
    bash "$base/tools/scripts/hal-terminal-guide.sh" ask "$question" 2>&1 || true
}

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

echo "[1/4] no key, Ollama running: the local model answers from the guide"
fake_curl answer
out="$(ask "what process holds port 8080?")"
grep -q "Use lsof -i :8080" <<<"$out" || fail "no Ollama answer: $out"
grep -q "qwen3:4b-instruct" <<<"$out" || fail "answer does not name the local model: $out"
[[ "$(cat "$run_dir/curl.log")" == "http://127.0.0.1:11434/api/generate" ]] \
  || fail "unexpected calls: $(cat "$run_dir/curl.log")"
python3 - "$run_dir/payload.json" <<'PY'
import json
import sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
assert p["model"] == "qwen3:4b-instruct", p
assert p["stream"] is False, p
assert "lsof -i :8080" in p["prompt"], "matching guide line missing from prompt"
assert "ditto" not in p["prompt"], "unrelated guide line sent to the model"
assert "<script>" not in p["prompt"], "HTML tags sent to the model"
PY
echo "  ok: answered locally, prompt holds only the matching guide lines"

echo "[2/4] model and host follow MQ_HAL_GUIDE_OLLAMA_MODEL and OLLAMA_HOST"
ask "port 8080" MQ_HAL_GUIDE_OLLAMA_MODEL=llama3.2 OLLAMA_HOST=10.0.0.5:9999 >/dev/null
[[ "$(cat "$run_dir/curl.log")" == "http://10.0.0.5:9999/api/generate" ]] \
  || fail "OLLAMA_HOST ignored: $(cat "$run_dir/curl.log")"
grep -q '"model":"llama3.2"' <(tr -d ' \n' <"$run_dir/payload.json") || fail "model override ignored"
echo "  ok: overrides respected"

echo "[3/4] no key, Ollama down: grep fallback as before"
fake_curl down
out="$(ask "what process holds port 8080?")"
grep -q "Local guide matches:" <<<"$out" || fail "no grep fallback: $out"
grep -q "local Ollama did not answer" <<<"$out" || fail "fallback reason missing: $out"
echo "  ok: falls back to local guide search"

echo "[4/4] with a key, OpenAI answers and Ollama is not asked"
fake_curl answer
out="$(ask "what process holds port 8080?" OPENAI_API_KEY=stub-key)"
grep -q "OPENAI_ANSWER" <<<"$out" || fail "OpenAI path broken: $out"
if grep -q "/api/generate" "$run_dir/curl.log"; then
  fail "asked Ollama although OpenAI is configured"
fi
echo "  ok: OpenAI stays first"

echo "OK: HAL guide answers locally when OpenAI is not set up"
