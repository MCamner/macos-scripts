#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export MACOS_SCRIPTS_HOME="$ROOT"
# shellcheck source=../terminal/launchers/mqlaunch-command-mode.sh
source "$ROOT/terminal/launchers/mqlaunch-command-mode.sh"

CAPTURE="$TMP/args"
run_agent_command() {
  printf '%s\n' "$@" >"$CAPTURE"
  return 37
}

echo "SMOKE: feedback delegation"

echo "[1/5] feedback forwards every argument unchanged"
set +e
dispatch_cli_command feedback report --task-class repo-review --since 30d --json
rc=$?
set -e
[[ "$rc" -eq 37 ]]
cat >"$TMP/expected" <<'EOF'
feedback
report
--task-class
repo-review
--since
30d
--json
EOF
cmp -s "$CAPTURE" "$TMP/expected"

echo "[2/5] feedback run is delegated, not implemented by shell"
set +e
dispatch_cli_command feedback run --task "review repo" --repo .
rc=$?
set -e
[[ "$rc" -eq 37 ]]
head -n 2 "$CAPTURE" | grep -qx $'feedback\nrun'

echo "[3/5] delegate exit status is preserved"
run_agent_command() { return 2; }
set +e
dispatch_cli_command feedback inspect missing
rc=$?
set -e
[[ "$rc" -eq 2 ]]

echo "[4/5] --json is producer output, unchanged"
run_agent_command() {
  [[ "$1" == "feedback" ]] || return 2
  printf '%s\n' '{"schema":"mq.feedback-report.v1","health":"HEALTHY"}'
  return 0
}
out="$(dispatch_cli_command feedback report --json)"
python3 - "$out" <<'PY'
import json, sys
d=json.loads(sys.argv[1])
assert d == {"schema":"mq.feedback-report.v1","health":"HEALTHY"}
PY

echo "[5/5] registry declares mq-agent ownership and no local policy"
python3 - "$ROOT/mqlaunch/lib/command-registry.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
x=next(c for c in d["commands"] if c["name"]=="feedback")
assert x["owner"]=="mq-agent"
assert x["delegates_to"]=="mq-agent feedback"
assert x["safety"]=="delegating"
assert "unknown_subcommand" not in x
assert x["json"] is True
assert "local_role" not in x
PY

echo "OK: feedback delegation is thin and exit-code preserving"
