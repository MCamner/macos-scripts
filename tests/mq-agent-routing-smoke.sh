#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mq-agent review routing boundary"

echo "[1/9] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"

echo "[2/9] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/9] review delegates to mq-agent review command group"
grep -q "_run_agent review diff" "$AGENT_MENU"
grep -q "_run_agent review file" "$AGENT_MENU"
grep -q "_run_agent review repo" "$AGENT_MENU"

echo "[4/9] risk review uses mq-agent risk flag"
grep -q "_run_agent review diff --risk" "$AGENT_MENU"

echo "[5/9] repo health targets macos-scripts by default"
grep -q 'repo_path=\$repo_path' "$AGENT_MENU"
grep -q 'MQ_REPO_HEALTH_PATH:-\$BASE_DIR' "$AGENT_MENU"

echo "[6/9] mqlaunch command mode exposes top-level routes"
grep -q "run_agent_command review" "$COMMAND_MODE"
grep -q "run_agent_command architecture" "$COMMAND_MODE"
grep -q "run_agent_command risk-review" "$COMMAND_MODE"
grep -q "run_agent_command repo-health" "$COMMAND_MODE"
grep -q "run_agent_command stack" "$COMMAND_MODE"
grep -q "run_agent_command mcp-status" "$COMMAND_MODE"

# This step used to also assert two strings in ROADMAP.md: 'Boundary test' and a
# verbatim '| Done | ... |' table row. The roadmap was rewritten from tables to
# prose sections with 'Status: Done', so neither could ever match again — and
# neither proved anything about the boundary in the first place. A roadmap is a
# plan, and rewriting it is its job. The contract lives in docs/COMMANDS.md and
# in the routes asserted above.
echo "[7/9] docs describe delegation boundary"
grep -q "review current diff via mq-agent -> mq-mcp" "$DOC"
grep -q "mqlaunch stack status" "$DOC"
grep -q 'mq-agent stack status' "$DOC"
grep -q '`mqlaunch` only delegates' "$DOC"

# Steps 3 and 4 grep the menu for the strings it is supposed to contain, which
# proves the file mentions `mq-agent review file` — not that typing
# `mqlaunch review file X` reaches it with X intact. The two steps below run the
# translation and read what comes out. That distinction is the whole finding:
# `--repo` used to match the scope arm and silently rewrote
# `review file X --repo /p` into `review repo /p`, reviewing a whole repo
# instead of the named file, and every grep above still passed.
translate() {
  (
    # shellcheck source=/dev/null
    source "$AGENT_MENU" >/dev/null 2>&1
    _run_agent() {
      printf 'mq-agent'
      printf ' %s' "$@"
      printf '\n'
    }
    _run_agent_review "$@"
  )
}

expect_translation() {
  local want="$1"
  shift
  local got
  got="$(translate "$@")"
  if [[ "$got" != "$want" ]]; then
    printf 'FAIL: mqlaunch review %s\n  want: %s\n  got : %s\n' "$*" "$want" "$got" >&2
    exit 1
  fi
}

echo "[8/9] review translates the operator vocabulary to mq-agent flags"
expect_translation "mq-agent review diff"                       # scope defaults to diff
expect_translation "mq-agent review repo" repo
expect_translation "mq-agent review file lib/x.sh" file lib/x.sh
expect_translation "mq-agent review file lib/x.sh --security" file lib/x.sh security
expect_translation "mq-agent review diff --architecture" diff architecture
expect_translation "mq-agent review repo --risk" repo --mode risk

echo "[9/9] mq-agent's own options survive the translation"
# `--repo <path>` is a real mq-agent option on `review file`: the external repo
# the file lives in. mqlaunch must pass it through rather than read it as a
# scope word, or the option is unreachable from the launcher.
expect_translation "mq-agent review file lib/x.sh --repo /tmp/other" file lib/x.sh --repo /tmp/other
expect_translation "mq-agent review diff --fast --json" diff --fast --json
expect_translation "mq-agent review file lib/x.sh --security --brain" file lib/x.sh security --brain

echo "OK: mq-agent review routing boundary smoke test passed"
