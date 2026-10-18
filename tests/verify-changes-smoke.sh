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
