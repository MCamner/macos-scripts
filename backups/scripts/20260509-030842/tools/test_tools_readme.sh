#!/usr/bin/env bash
set -euo pipefail

FILE="tools/README.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f "$FILE" ]] || fail "Missing $FILE"

grep -q '^# Tools' "$FILE" || fail "Missing heading '# Tools'"
grep -q '^## Purpose' "$FILE" || fail "Missing section '## Purpose'"
grep -q '^## Contents' "$FILE" || fail "Missing section '## Contents'"
grep -q '^## How to run' "$FILE" || fail "Missing section '## How to run'"
grep -q '`bash tools/cli/ai-mode\.sh`' "$FILE" || fail "Missing example: bash tools/cli/ai-mode.sh"
grep -q 'mac-terminal-guide' "$FILE" || fail "Missing reference to mac-terminal-guide"

echo "OK: tools/README.md looks good"
