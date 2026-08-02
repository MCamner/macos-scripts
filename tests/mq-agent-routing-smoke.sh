#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mq-agent review routing boundary"

echo "[1/11] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"

echo "[2/11] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/11] review delegates to mq-agent review command group"
grep -q "_run_agent review diff" "$AGENT_MENU"
grep -q "_run_agent review file" "$AGENT_MENU"
grep -q "_run_agent review repo" "$AGENT_MENU"

echo "[4/11] risk review uses mq-agent risk flag"
grep -q "_run_agent review diff --risk" "$AGENT_MENU"

echo "[5/11] repo health targets macos-scripts by default"
grep -q 'repo_path=\$repo_path' "$AGENT_MENU"
grep -q 'MQ_REPO_HEALTH_PATH:-\$BASE_DIR' "$AGENT_MENU"

echo "[6/11] mqlaunch command mode exposes top-level routes"
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
echo "[7/11] docs describe delegation boundary"
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

echo "[8/11] review translates the operator vocabulary to mq-agent flags"
expect_translation "mq-agent review diff"                       # scope defaults to diff
expect_translation "mq-agent review repo" repo
expect_translation "mq-agent review file lib/x.sh" file lib/x.sh
expect_translation "mq-agent review file lib/x.sh --security" file lib/x.sh security
expect_translation "mq-agent review diff --architecture" diff architecture
expect_translation "mq-agent review repo --risk" repo --mode risk

echo "[9/11] mq-agent's own options survive the translation"
# `--repo <path>` is a real mq-agent option on `review file`: the external repo
# the file lives in. mqlaunch must pass it through rather than read it as a
# scope word, or the option is unreachable from the launcher.
expect_translation "mq-agent review file lib/x.sh --repo /tmp/other" file lib/x.sh --repo /tmp/other
expect_translation "mq-agent review diff --fast --json" diff --fast --json
expect_translation "mq-agent review file lib/x.sh --security --brain" file lib/x.sh security --brain

# `stack` is a forwarding route: mqlaunch owns the entrypoint, mq-agent owns
# every verb behind it. The only local decision is what a bare `mqlaunch stack`
# means, and that decision is the thing worth pinning — everything else must
# arrive at the delegate untouched, including the words this repo has never
# heard of. Step 6 above greps the command-mode file for `run_agent_command
# stack`, which proves the route is mentioned, not that it forwards.
dispatch() {
  (
    # shellcheck source=/dev/null
    source "$AGENT_MENU" >/dev/null 2>&1
    _run_agent() {
      printf 'mq-agent'
      printf ' %s' "$@"
      printf '\n'
      return "${STUB_EXIT:-0}"
    }
    run_agent_command "$@"
  )
}

expect_dispatch() {
  local want="$1"
  shift
  local got
  got="$(dispatch "$@")"
  if [[ "$got" != "$want" ]]; then
    printf 'FAIL: mqlaunch %s\n  want: %s\n  got : %s\n' "$*" "$want" "$got" >&2
    exit 1
  fi
}

echo "[10/11] stack forwards every verb to mq-agent, and bare stack means status"
expect_dispatch "mq-agent stack status" stack
expect_dispatch "mq-agent stack status" stack status
expect_dispatch "mq-agent stack status --json" stack status --json
# The release cockpit. mqlaunch must not reimplement or rename it: the contract
# is that the word reaches mq-agent unchanged.
expect_dispatch "mq-agent stack cockpit" stack cockpit
expect_dispatch "mq-agent stack cockpit --json" stack cockpit --json
expect_dispatch "mq-agent stack contract-check" stack contract-check
expect_dispatch "mq-agent stack truth-export" stack truth-export
# A verb this repo has never heard of must still forward, or a new mq-agent
# subcommand would need a mqlaunch change to become reachable.
expect_dispatch "mq-agent stack brain-gate --strict" stack brain-gate --strict

echo "[11/11] the delegate's exit code survives the route"
# `mqlaunch stack --json` really does fail: --json is an option on the
# subcommands, not on the group, so mq-agent exits 2. A launcher that swallowed
# that would make the failure invisible to a script.
for code in 0 1 2 127; do
  # `|| got=$?` rather than a bare call: under `set -e` a non-zero delegate
  # would abort the suite here instead of being compared, which would make this
  # step pass only for 0 and never run the cases that matter.
  got=0
  STUB_EXIT="$code" dispatch stack cockpit >/dev/null || got=$?
  if [[ "$got" != "$code" ]]; then
    printf 'FAIL: delegate exited %s but mqlaunch returned %s\n' "$code" "$got" >&2
    exit 1
  fi
done

echo "OK: mq-agent review routing boundary smoke test passed"
