#!/bin/zsh
# Capture actual applied routing evidence readiness; never synthesize outcomes.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
root="${HOME}/mq-agent"
out="${HOME}/mq-evidence/routing-readiness"
mkdir -p "$out" || exit 1
stamp=$(/bin/date +%Y-%m-%d_%H-%M-%S)
file="$out/$stamp.json"
if [[ ! -d "$root" ]]; then
  print -u2 "Missing mq-agent checkout: $root"
  exit 1
fi
if ( cd "$root" && /opt/homebrew/bin/uv run mq-agent route readiness --json ) > "$file"; then
  print -- "$stamp PASS $file" >> "$out/evaluation.log"
else
  /bin/rm -f "$file"
  print -- "$stamp ERROR" >> "$out/evaluation.log"
  exit 1
fi
