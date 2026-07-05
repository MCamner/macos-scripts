#!/usr/bin/env bash
# Smoke: the runtime authority freeze gate (P1 Step 10) passes on the current
# tree — i.e. no live shell file outside the documented compat allowlist
# references terminal/mqlaunch-v1/. Local parity for the CI step.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! out="$("$ROOT/scripts/check-runtime-authority.sh" 2>&1)"; then
  printf '[FAIL] runtime authority freeze check failed on a clean tree:\n%s\n' "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '\[PASS\] Runtime authority freeze' || {
  printf '[FAIL] unexpected output from freeze check:\n%s\n' "$out" >&2
  exit 1
}

printf '[PASS] runtime authority freeze smoke\n'
