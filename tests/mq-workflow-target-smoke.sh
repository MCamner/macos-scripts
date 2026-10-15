#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/target repo/sub" "$tmp/agent"
git init -q "$tmp/target repo"
source "$ROOT/terminal/menus/mq-agent-menu.sh"
_run_agent() { printf '%s\n' "$@"; }
cd "$tmp"
expected="$(cd 'target repo' && pwd -P)"
out="$(_run_agent_flow plan repo-preflight 'target repo/sub')"
[[ "$out" == $'workflow\nplan\nrepo-preflight\n--repo\n'"$expected" ]]
out="$(_run_agent_flow run repo-preflight --repo='target repo')"
[[ "$out" == *$'--repo\n'"$expected" ]]
if _run_agent_flow plan repo-preflight --repo missing >"$tmp/error" 2>&1; then exit 1; fi
if _run_agent_flow plan repo-preflight 'target repo' --repo 'target repo' >"$tmp/error" 2>&1; then exit 1; fi
out="$(run_agent_command do 'review this repo' --repo 'target repo/sub' --plan --json)"
[[ "$out" == $'workflow\ndo\nreview this repo\n--repo\n'"$expected"$'\n--plan\n--json' ]]
if run_agent_command do 'review' --repo >"$tmp/error" 2>&1; then exit 1; fi
out="$(_run_agent_flow do 'review this repo' --repo 'target repo')"
[[ "$out" == $'workflow\ndo\nreview this repo\n--repo\n'"$expected" ]]
# Exercise the real cwd-changing delegate with a fake uv, without an API.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/uv" <<'STUB'
#!/usr/bin/env bash
printf 'cwd=%s\n' "$PWD"
printf '%s\n' "$@"
exit 7
STUB
chmod +x "$tmp/bin/uv"
source "$ROOT/terminal/menus/mq-agent-menu.sh"
export MQ_AGENT_BIN="$tmp/agent"
set +e
out="$(PATH="$tmp/bin:$PATH" run_agent_command do 'review this repo' --repo 'target repo' --plan)"
rc=$?
set -e
[[ $rc -eq 7 ]]
[[ "$out" == *"cwd=$tmp/agent"* && "$out" == *"$expected"* ]]
echo 'OK: canonical workflow target, do forwarding and delegated exit status'
