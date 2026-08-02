#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_MENU="$ROOT/terminal/menus/mq-agent-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: mq-agent review routing boundary"

echo "[1/13] files exist"
test -f "$AGENT_MENU"
test -f "$COMMAND_MODE"

echo "[2/13] shell syntax"
bash -n "$AGENT_MENU"
bash -n "$COMMAND_MODE"

echo "[3/13] review delegates to mq-agent review command group"
grep -q "_run_agent review diff" "$AGENT_MENU"
grep -q "_run_agent review file" "$AGENT_MENU"
grep -q "_run_agent review repo" "$AGENT_MENU"

echo "[4/13] risk review uses mq-agent risk flag"
grep -q "_run_agent review diff --risk" "$AGENT_MENU"

echo "[5/13] repo health targets macos-scripts by default"
grep -q 'repo_path=\$repo_path' "$AGENT_MENU"
grep -q 'MQ_REPO_HEALTH_PATH:-\$BASE_DIR' "$AGENT_MENU"

echo "[6/13] mqlaunch command mode exposes top-level routes"
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
echo "[7/13] docs describe delegation boundary"
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

echo "[8/13] review translates the operator vocabulary to mq-agent flags"
expect_translation "mq-agent review diff"                       # scope defaults to diff
expect_translation "mq-agent review repo" repo
expect_translation "mq-agent review file lib/x.sh" file lib/x.sh
expect_translation "mq-agent review file lib/x.sh --security" file lib/x.sh security
expect_translation "mq-agent review diff --architecture" diff architecture
expect_translation "mq-agent review repo --risk" repo --mode risk

echo "[9/13] mq-agent's own options survive the translation"
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

echo "[10/13] stack forwards every verb to mq-agent, and bare stack means status"
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

echo "[11/13] the delegate's exit code survives the route"
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

# `srm` was the one command that could not carry a local_role. Its first four
# verbs delegate to `mq-agent memory-*`; everything else fell through to
# tools/scripts/srm.sh, which called api.openai.com directly with file_search
# against a hardcoded vector store — semantic memory cognition in shell, on the
# same vector store `mq-agent memory status` already reports. These steps pin
# the retirement: every verb reaches mq-agent, and no word reaches an AI from
# here.
# `srm` is dispatched in mqlaunch-command-mode.sh, not in run_agent_command, so
# the harness above tests the wrong layer for it. This one sources the command
# mode and stubs the bridge it calls, which is the seam the srm route actually
# crosses.
cli() {
  (
    export MACOS_SCRIPTS_HOME="$ROOT"
    # shellcheck source=/dev/null
    source "$COMMAND_MODE" >/dev/null 2>&1
    run_agent_command() {
      printf 'mq-agent'
      printf ' %s' "$@"
      printf '\n'
      return "${STUB_EXIT:-0}"
    }
    pause_enter() { :; }
    dispatch_cli_command "$@"
  )
}

expect_cli() {
  local want="$1"
  shift
  local got
  got="$(cli "$@" 2>&1)"
  if [[ "$got" != "$want" ]]; then
    printf 'FAIL: mqlaunch %s\n  want: %s\n  got : %s\n' "$*" "$want" "$got" >&2
    exit 1
  fi
}

echo "[12/13] srm delegates every verb to mq-agent, including the read paths"
expect_cli "mq-agent memory-search vector store upload flow" srm search vector store upload flow
expect_cli "mq-agent memory-search what is indexed here" srm ask what is indexed here
expect_cli "mq-agent memory-status" srm inspect
# `memory status` defaults to `.`, which resolves inside mq-agent's checkout
# because _run_agent cd's there. The operator's directory is supplied, and an
# explicit one is never overwritten.
expect_dispatch "mq-agent memory status $PWD" memory-status
expect_dispatch "mq-agent memory status /tmp/elsewhere" memory-status /tmp/elsewhere
expect_cli "mq-agent memory-cochange macos-scripts lib/x.sh" srm cochange macos-scripts lib/x.sh
expect_cli "mq-agent memory-review-status" srm review-status
expect_cli "mq-agent memory-promote-from-review 7" srm promote-from-review 7
expect_cli "mq-agent memory-resolve-supersede 9" srm resolve-supersede 9

echo "[13/13] the retired local AI path is gone and unknown words fail clearly"
if [[ -e "$ROOT/tools/scripts/srm.sh" ]]; then
  echo "FAIL: tools/scripts/srm.sh is back — the local OpenAI path was retired" >&2
  exit 1
fi
# Code, not comments: the arm that retired this path explains what it retired,
# and a plain grep would match that explanation and fail on its own changelog.
if sed 's/#.*//' "$AGENT_MENU" "$COMMAND_MODE" | grep -q "api\.openai\.com"; then
  echo "FAIL: an OpenAI endpoint is reachable from the srm route again" >&2
  exit 1
fi
# A word this repo does not route must not become an AI question. ROADMAP.md
# lists "do not introduce hidden AI fallbacks for unknown commands" as a
# non-goal, and the fall-through was exactly that.
if out="$(cli srm not-a-verb 2>&1)"; then
  echo "FAIL: an unknown srm verb was accepted: $out" >&2
  exit 1
fi
case "$out" in
  *"Usage: mqlaunch srm"*) ;;
  *) echo "FAIL: unknown srm verb did not print usage: $out" >&2; exit 1 ;;
esac
echo "  ok: srm.sh is gone, no AI fallback, unknown verbs print usage"

echo "OK: mq-agent review routing boundary smoke test passed"
