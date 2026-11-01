#!/usr/bin/env bash
# The rotation smoke must not depend on the caller's credential environment.
# A launchd job (se.mq.mcp) exports OPENAI_API_KEY, and mqlaunch selftest run
# from it failed at [2/8] because the smoke inherited that key (mq-agent#440).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AMBIENT='ambient-dummy-not-a-real-key-7Hq2'

printf '[1/2] rotation smoke passes with OPENAI_API_KEY exported by the caller\n'
out="$(OPENAI_API_KEY="$AMBIENT" bash "$ROOT/tests/openai-key-rotation-smoke.sh" 2>&1)"
grep -q 'OK: OpenAI Keychain rotation smoke passed' <<<"$out"
printf '  ok\n'

printf '[2/2] the inherited value never reaches the output\n'
! grep -q "$AMBIENT" <<<"$out"
printf '  ok\n'

echo "OK: rotation smoke is independent of an inherited OPENAI_API_KEY"
