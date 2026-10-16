#!/bin/zsh
# Snapshot the era gate for automatic routing: `mq-agent route divergence`.
# Records what mq-agent reports; never synthesizes outcomes or promotes a route.
# `route readiness` counts all history and decides nothing, so it is not used.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
root="${MQ_AGENT_BIN:-${HOME}/mq-agent}"
out="${MQ_ROUTING_EVIDENCE_DIR:-${HOME}/mq-evidence/routing-divergence}"
if [[ ! -d "$root" ]]; then
  print -u2 "Missing mq-agent checkout: $root"
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  print -u2 "uv not found on PATH"
  exit 1
fi
mkdir -p "$out" || exit 1
stamp=$(/bin/date -u +%Y-%m-%dT%H-%M-%SZ)
file="$out/$stamp.json"
if uv --project "$root" run mq-agent route divergence --json > "$file.tmp"; then
  /bin/mv "$file.tmp" "$file"
  print -- "$stamp PASS $file" >> "$out/evaluation.log"
else
  /bin/rm -f "$file.tmp"
  print -- "$stamp ERROR" >> "$out/evaluation.log"
  exit 1
fi
