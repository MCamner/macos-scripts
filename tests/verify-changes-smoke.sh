#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
run_agent_command() {
  [[ "$1" == verify-changes && "$2" == --repo && "$3" == "$PWD" ]]
  [[ "$4" == --base && "$5" == 'topic with spaces' && "$6" == --json ]]
  return 7
}
set +e
dispatch_cli_command verify-changes --base 'topic with spaces' --json
rc=$?
set -e
[[ $rc -eq 7 ]]
bash -n "$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
echo 'OK: verify-changes preserves caller repo, argument boundaries and delegate exit code'

# The terminal route must forward exactly one JSON document without decoration.
run_agent_command() {
  [[ "$1" == verify-changes && "$2" == --repo && "$3" == "$PWD" && "$4" == --json ]]
  printf '{"schema":"mq.verification-receipt.v1","status":"PASS"}\n'
}
out="$(dispatch_cli_command verify-changes --json)"
python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"] == "mq.verification-receipt.v1" and d["status"] == "PASS"' <<<"$out"
echo 'OK: verify-changes JSON stdout is clean'
