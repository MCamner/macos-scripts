#!/usr/bin/env bash
# Regression guard (P1 Step 11b): the HAL command surface must never eval user
# input. It tokenizes the request into argv with `read -ra` and passes it as
# positional args instead, so glob/`;`/`|`/`$()` in a request stay literal. If
# `eval` on the user's hal args returns, this fails.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

for f in terminal/launchers/mqlaunch-repl.sh terminal/menus/mq-main-menu.sh; do
  if grep -Eq 'eval[[:space:]]+"?mq_hal' "$ROOT/$f"; then
    fail "$f still eval's HAL user input — use read -ra + array passing"
  fi
done

printf '[PASS] HAL command surface passes user args as argv, not via eval\n'
