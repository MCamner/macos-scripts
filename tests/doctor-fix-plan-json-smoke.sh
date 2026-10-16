#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="$ROOT/tools/scripts/doctor.sh"

echo "SMOKE: doctor fix-plan JSON contract"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

CHECKED=(git gh uv python3 node eza fzf jq gitleaks pbcopy)
HELPERS=(bash sh cat sed awk tr wc head tail date hostname uname stty tput id)

build_world() {
  local dir="$1"; shift
  mkdir -p "$dir"
  local tool resolved
  for tool in "${HELPERS[@]}"; do
    resolved="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$resolved" ]] && ln -sf "$resolved" "$dir/$tool"
  done
  for tool in "$@"; do
    printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/$tool"
    chmod +x "$dir/$tool"
  done
}

# A working local Ollama: the binary, and a curl that answers /api/tags with
# the two models doctor looks for. tests/doctor-ollama-smoke.sh covers the
# states in between; here it is only part of a provisioned machine.
provide_ollama() {
  local dir="$1"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/ollama"
  printf '#!/usr/bin/env bash\nprintf %s\n' \
    "'{\"models\":[{\"name\":\"qwen3:4b-instruct\"},{\"name\":\"nomic-embed-text:latest\"}]}'" \
    >"$dir/curl"
  chmod +x "$dir/ollama" "$dir/curl"
}

doctor_run() {
  local bin="$1" key="$2" out="$3"; shift 3
  local -a env_args=(HOME="$HOME" MACOS_SCRIPTS_HOME="$ROOT" PATH="$bin")
  [[ "$key" == "key" ]] && env_args+=(OPENAI_API_KEY="stub-key")
  set +e
  env -i "${env_args[@]}" bash "$DOCTOR" "$@" >"$out" 2>"$out.err"
  local rc=$?
  set -e
  printf '%s\n' "$rc"
}

provisioned="$run_dir/provisioned"
degraded="$run_dir/degraded"
# Deliberately omit jq from the degraded world: JSON plan generation must not
# depend on the dependency it may be recommending the operator install.
build_world "$provisioned" "${CHECKED[@]}" mqlaunch
provide_ollama "$provisioned"
build_world "$degraded"

echo "[1/6] script compiles"
bash -n "$DOCTOR"

echo "[2/6] degraded machine emits parseable mq.doctor-fix-plan.v1 without jq"
warn_rc="$(doctor_run "$degraded" nokey "$run_dir/warn.json" --fix-plan --json)"
if [[ "$warn_rc" == "0" ]]; then
  echo "FAIL: degraded fix plan must preserve warning exit status" >&2
  exit 1
fi

python3 - "$run_dir/warn.json" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["schema"] == "mq.doctor-fix-plan.v1", doc
assert doc["read_only"] is True, doc
assert doc["status"] == "warn", doc
assert doc["source"]["schema"] == "mq.doctor-status.v1", doc
assert doc["source"]["summary"]["warn"] > 0, doc
assert len(doc["actions"]) == doc["source"]["summary"]["warn"] + doc["source"]["summary"]["fail"], doc
assert doc["first_action"], doc
assert doc["verification"] == "mqlaunch doctor --json", doc
print(f"  ok: {len(doc['actions'])} evidence-bound actions")
PY

echo "[3/6] every action is bound to a non-passing observed check"
python3 - "$run_dir/warn.json" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1], encoding="utf-8"))
checks = {c["name"]: c for c in doc["source"]["checks"]}
orders = []
for action in doc["actions"]:
    check = checks.get(action["check"])
    assert check is not None, action
    assert check["status"] != "ok", action
    assert action["observed_status"] == check["status"], (action, check)
    assert action["execution"] == "manual-review", action
    assert action["verify"] == "mqlaunch doctor --json", action
    orders.append(action["order"])
assert orders == list(range(1, len(orders) + 1)), orders
print("  ok: no action exists without supporting doctor evidence")
PY

echo "[4/6] repair order follows FIX_ORDER rather than check print order"
python3 - "$run_dir/warn.json" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1], encoding="utf-8"))
names = [a["check"] for a in doc["actions"]]
expected = [
    "mqlaunch", "git", "python3", "jq", "fzf", "gh", "uv", "node",
    "gitleaks", "ollama", "pbcopy", "eza", "OPENAI_API_KEY",
]
assert names == expected, (names, expected)
assert doc["first_action"] == doc["actions"][0]["command"], doc
print("  ok: action order and first_action agree")
PY

echo "[5/6] healthy machine has no repair actions"
ok_rc="$(doctor_run "$provisioned" key "$run_dir/ok.json" --fix-plan --json)"
if [[ "$ok_rc" != "0" ]]; then
  echo "FAIL: healthy fix plan must exit 0" >&2
  exit 1
fi
python3 - "$run_dir/ok.json" <<'PY'
import json
import sys

doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["status"] == "ok", doc
assert doc["actions"] == [], doc
assert doc["first_action"] is None, doc
assert doc["source"]["summary"]["warn"] == 0, doc
print("  ok: healthy plan is empty rather than inventing work")
PY

echo "[6/6] fix-plan JSON performs no repair command"
marker="$run_dir/executed"
probe="$run_dir/probe"
build_world "$probe"
cat >"$probe/brew" <<EOF
#!/usr/bin/env bash
touch "$marker"
exit 99
EOF
chmod +x "$probe/brew"
doctor_run "$probe" nokey "$run_dir/probe.json" --fix-plan --json >/dev/null
if [[ -e "$marker" ]]; then
  echo "FAIL: fix-plan executed a repair command" >&2
  exit 1
fi
echo "  ok: plan generation is read-only"

echo "OK: doctor safe repair plan JSON contract"
