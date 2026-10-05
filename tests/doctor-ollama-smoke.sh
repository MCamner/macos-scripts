#!/usr/bin/env bash
set -euo pipefail

# `mqlaunch hal` and `mqlaunch ollama-review` need a running Ollama with
# qwen3:4b-instruct, and mq-agent's semantic memory needs nomic-embed-text.
# doctor is where an operator learns that before one of them fails mid-run.
#
# Each world is a PATH with stubs, as in doctor-status-contract-smoke.sh. The
# curl stub plays the Ollama API, so no test here touches the network. The
# ollama stub leaves a marker if it is run at all: `ollama list` starts the
# server when it is down, and doctor must stay read-only.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="$ROOT/tools/scripts/doctor.sh"

echo "SMOKE: doctor Ollama checks"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

HELPERS=(bash sh cat sed awk tr wc head tail date hostname uname stty tput id)
marker="$run_dir/ollama-was-run"

# Builds a world with the helpers and an ollama stub that records being run.
build_world() {
  # build_world <dir> <with-ollama: yes|no>
  local dir="$1" with_ollama="$2" tool resolved
  mkdir -p "$dir"
  for tool in "${HELPERS[@]}"; do
    resolved="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$resolved" ]] && ln -sf "$resolved" "$dir/$tool"
  done
  if [[ "$with_ollama" == "yes" ]]; then
    printf '#!/usr/bin/env bash\ntouch %q\nexit 0\n' "$marker" >"$dir/ollama"
    chmod +x "$dir/ollama"
  fi
}

# Adds a curl stub that logs its URL and answers like /api/tags.
fake_api() {
  # fake_api <dir> <exit-code> <model>...
  local dir="$1" rc="$2" models="" sep="" model; shift 2
  for model in "$@"; do
    models="${models}${sep}{\"name\":\"${model}\",\"size\":1}"
    sep=","
  done
  cat >"$dir/curl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\${@: -1}" >>"$dir/curl.log"
[[ "$rc" == "0" ]] || exit $rc
printf '{"models":[%s]}' '$models'
EOF
  chmod +x "$dir/curl"
}

# Runs doctor --json in a world and prints the checks as name=status|hint.
doctor_checks() {
  # doctor_checks <dir> [VAR=value]...
  local dir="$1"; shift
  env -i HOME="$HOME" MACOS_SCRIPTS_HOME="$ROOT" PATH="$dir" "$@" \
    bash "$DOCTOR" --json >"$dir/out.json" 2>"$dir/out.err" || true
  python3 - "$dir/out.json" <<'PY'
import json
import sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
for check in doc["checks"]:
    if check["name"].startswith("ollama"):
        print(f'{check["name"]}={check["status"]}|{check.get("hint", "")}')
PY
}

expect() {
  # expect <label> <actual> <expected>
  if [[ "$2" != "$3" ]]; then
    printf 'FAIL: %s\n  expected:\n%s\n  got:\n%s\n' "$1" "$3" "$2" >&2
    exit 1
  fi
  printf '  ok: %s\n' "$1"
}

echo "[1/6] not installed: one warning, nothing further probed"
w="$run_dir/absent"; build_world "$w" no; fake_api "$w" 0
expect "missing ollama" "$(doctor_checks "$w")" \
  "ollama=warn|brew install --cask ollama-app"
[[ ! -e "$w/curl.log" ]] || { echo "FAIL: probed the API without ollama" >&2; exit 1; }

echo "[2/6] installed but not running: server warning, models not judged"
w="$run_dir/down"; build_world "$w" yes; fake_api "$w" 7
expect "server down" "$(doctor_checks "$w")" \
  "ollama=ok|
ollama-server=warn|open -a Ollama"

echo "[3/6] running with both models: all four pass"
w="$run_dir/ready"; build_world "$w" yes
fake_api "$w" 0 "qwen3:4b-instruct" "nomic-embed-text:latest" "llama3.2:latest"
expect "ready" "$(doctor_checks "$w")" \
  "ollama=ok|
ollama-server=ok|
ollama-model=ok|
ollama-embed=ok|"

echo "[4/6] a missing model is named with the pull that fixes it"
w="$run_dir/no-embed"; build_world "$w" yes; fake_api "$w" 0 "qwen3:4b-instruct"
expect "embed model missing" "$(doctor_checks "$w")" \
  "ollama=ok|
ollama-server=ok|
ollama-model=ok|
ollama-embed=warn|ollama pull nomic-embed-text"
# A prefix is not the model: qwen3:4b is a different pull from qwen3:4b-instruct.
w="$run_dir/near-miss"; build_world "$w" yes
fake_api "$w" 0 "qwen3:4b" "nomic-embed-text:latest"
expect "near-miss name is not accepted" "$(doctor_checks "$w" | grep model)" \
  "ollama-model=warn|ollama pull qwen3:4b-instruct"

echo "[5/6] the API is asked at OLLAMA_HOST, as Ollama itself resolves it"
w="$run_dir/host"; build_world "$w" yes
fake_api "$w" 0 "qwen3:4b-instruct" "nomic-embed-text:latest"
doctor_checks "$w" >/dev/null
expect "default host" "$(cat "$w/curl.log")" "http://127.0.0.1:11434/api/tags"
rm -f "$w/curl.log"
doctor_checks "$w" OLLAMA_HOST=10.0.0.5:9999 >/dev/null
expect "OLLAMA_HOST without scheme" "$(cat "$w/curl.log")" "http://10.0.0.5:9999/api/tags"

echo "[6/6] doctor never runs the ollama binary"
if [[ -e "$marker" ]]; then
  echo "FAIL: doctor ran ollama, which can start the server" >&2
  exit 1
fi
echo "  ok: only the HTTP API was asked"

echo "OK: doctor reports Ollama, its server and both models, read-only"
