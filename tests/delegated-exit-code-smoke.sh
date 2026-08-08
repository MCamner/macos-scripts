#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

export MACOS_SCRIPTS_HOME="$ROOT"
# shellcheck source=/dev/null
source "$COMMAND_MODE"

# Pauses until Enter is pressed.
pause_enter() {
  printf 'pause-called\n' >> "$TMPDIR_TEST/pause.log"
  return 0
}

# Coordinates assert status behavior.
assert_status() {
  local expected="$1"
  shift
  local actual

  set +e
  "$@" >"$TMPDIR_TEST/stdout" 2>"$TMPDIR_TEST/stderr"
  actual=$?
  set -e
  [[ $actual -eq $expected ]] || {
    echo "expected exit $expected, got $actual for: $*" >&2
    return 1
  }
}

echo "SMOKE: delegated exit-code contract"

echo "[1/12] missing backend is non-zero"
unset -f run_agent_command 2>/dev/null || true
assert_status 1 dispatch_cli_command review
grep -q 'bridge not loaded' "$TMPDIR_TEST/stderr"

echo "[2/12] usage and runtime failures propagate"
# Runs agent command.
run_agent_command() { return "${MQ_TEST_BACKEND_STATUS:-0}"; }
MQ_TEST_BACKEND_STATUS=2 assert_status 2 dispatch_cli_command review
MQ_TEST_BACKEND_STATUS=42 assert_status 42 dispatch_cli_command stack status

echo "[3/12] HAL pause does not overwrite backend status"
# Coordinates mq hal run behavior.
mq_hal_run() { return "${MQ_TEST_BACKEND_STATUS:-0}"; }
rm -f "$TMPDIR_TEST/pause.log"
MQ_TEST_BACKEND_STATUS=42 assert_status 42 dispatch_cli_command hal brief
[[ -s "$TMPDIR_TEST/pause.log" ]]

echo "[4/12] JSON stdout stays clean"
# Coordinates mq hal run behavior.
mq_hal_run() {
  printf '{"schema":"hal.test.v1"}\n'
  return 42
}
rm -f "$TMPDIR_TEST/pause.log"
assert_status 42 dispatch_cli_command hal brief --json
[[ "$(cat "$TMPDIR_TEST/stdout")" == '{"schema":"hal.test.v1"}' ]]
[[ ! -e "$TMPDIR_TEST/pause.log" ]]
[[ ! -s "$TMPDIR_TEST/stderr" ]]

echo "[5/12] full launcher returns backend status without double dispatch"
mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/agent"
cat > "$TMPDIR_TEST/bin/uv" <<EOF
#!/usr/bin/env bash
printf 'called\n' >> '$TMPDIR_TEST/backend.log'
exit 42
EOF
chmod +x "$TMPDIR_TEST/bin/uv"
set +e
HOME="$TMPDIR_TEST" \
  PATH="$TMPDIR_TEST/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  MACOS_SCRIPTS_HOME="$ROOT" \
  MQ_AGENT_BIN="$TMPDIR_TEST/agent" \
  MQ_NO_TUI=1 \
  MQLAUNCH_HEADLESS=1 \
  "$ROOT/terminal/launchers/mqlaunch.sh" review \
  >"$TMPDIR_TEST/launcher.stdout" 2>"$TMPDIR_TEST/launcher.stderr"
launcher_status=$?
set -e
[[ $launcher_status -eq 42 ]] || {
  echo "full launcher: expected exit 42, got $launcher_status" >&2
  exit 1
}
[[ "$(wc -l < "$TMPDIR_TEST/backend.log" | tr -d ' ')" -eq 1 ]] || {
  echo "full launcher delegated more than once" >&2
  exit 1
}

echo "[6/12] external script delegates propagate their status"
# Steps 1-5 stub shell functions, which only reaches the agent and HAL families.
# Most of the surface delegates to scripts under $BASE_DIR instead, and those
# were never covered. Both cases below are real argparse failures.
run_launcher() {
  set +e
  MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 MQLAUNCH_HEADLESS=1 \
    timeout 60 "$ROOT/terminal/launchers/mqlaunch.sh" "$@" \
    </dev/null >"$TMPDIR_TEST/stdout" 2>"$TMPDIR_TEST/stderr"
  local status=$?
  set -e
  return "$status"
}

for bad_case in "repos no-such-subcommand" "skills no-such-subcommand"; do
  # shellcheck disable=SC2086
  set -- $bad_case
  if run_launcher "$@"; then
    echo "delegated failure reported success: mqlaunch $bad_case" >&2
    exit 1
  fi
  grep -q 'usage:' "$TMPDIR_TEST/stderr" || {
    echo "expected a delegate usage error on stderr for: mqlaunch $bad_case" >&2
    exit 1
  }
done

# The success path must stay 0, so the fix cannot be "always return non-zero".
run_launcher repos list || {
  echo "successful delegation no longer exits 0" >&2
  exit 1
}

echo "[7/12] no delegating branch ends in an unconditional return 0"
# The behavioural cases above pin two branches. This keeps the other nineteen
# from drifting back, and stops new ones from being written that way.
python3 - "$COMMAND_MODE" <<'PY'
import re
import sys

lines = open(sys.argv[1]).read().splitlines()
start = next(i for i, l in enumerate(lines) if l.strip() == 'case "$area" in')

branch = re.compile(
    r'((?:"[^"]*"|[A-Za-z0-9_*/.\-])+(?:\|(?:"[^"]*"|[A-Za-z0-9_*/.\-])+)*)\)'
)
depth = 0
current = None
bodies = {}
for i in range(start, len(lines)):
    s = lines[i].strip()
    if s.startswith("case ") and re.match(r'case\s+"?\$', s):
        depth += 1
    elif s.startswith("esac"):
        depth -= 1
        if depth == 0:
            break
    elif branch.match(s):
        if depth == 1:
            current = (branch.match(s).group(1), i + 1)
            bodies[current] = []
        elif current is not None:
            bodies[current].append(s)
    elif current is not None:
        bodies[current].append(s)

# Branches that hold a deliberate `return 0` beside a path that does propagate.
# The shape is always the same: bare command opens something interactive, and a
# menu or session ending is not a failure (tests/menu-eof-smoke.sh); the same
# branch with an argument runs real work and keeps its status.
#
# Being named here is not enough. Each entry must also propagate somewhere in
# the same branch, checked below, so an exception cannot cover a branch that
# discards status on every path — and a stale entry is an error rather than a
# silent pass. The behavioural proof for each lives in steps 10 to 12.
DELIBERATE_ZERO = {
    "system": "bare `system` opens the system menu; every subcommand propagates",
    "apps|guide-ai|terminal-guide-ai":
        "bare `apps` opens the interactive guide; `apps ask` propagates",
}

PROPAGATES = re.compile(r'^return "\$command_status"$|^return \$\?$', re.M)

offenders = []
excused = set()
for (name, line), body in bodies.items():
    text = "\n".join(body)
    if not re.search(r"\$BASE_DIR/(tools|terminal|bin|automation)", text):
        continue
    if not re.search(r"^return 0$", text, re.M):
        continue
    if name in DELIBERATE_ZERO and PROPAGATES.search(text):
        excused.add(name)
        continue
    offenders.append(f"  line {line}: {name}")

if offenders:
    print(
        "these branches delegate and then discard the delegate's status:",
        file=sys.stderr,
    )
    print("\n".join(offenders), file=sys.stderr)
    sys.exit(1)

stale = set(DELIBERATE_ZERO) - excused
if stale:
    print(
        "these exceptions no longer describe the tree and must be removed:",
        file=sys.stderr,
    )
    for name in sorted(stale):
        print(f"  {name}: {DELIBERATE_ZERO[name]}", file=sys.stderr)
    sys.exit(1)
PY

echo "[8/12] the brain bridge's exit status reaches the caller"
# Step 7 only inspects branches that invoke a $BASE_DIR script. The brain
# branches call a shell function, mq_brain_run, so the structural check never
# looked at them and both ended in an unconditional `return 0` — the delegate
# could fail and mqlaunch would report success.
brain_status() {
  local code="$1" verb="$2"
  (
# Coordinates mq brain run behavior.
    mq_brain_run() { return "$code"; }
    dispatch_cli_command "$verb" note-arg >/dev/null 2>&1
  )
}

for code in 0 1 2 127; do
  for verb in brain note sessions decisions reviews learn verified systems; do
    got=0
    brain_status "$code" "$verb" || got=$?
    if [[ "$got" != "$code" ]]; then
      echo "FAIL: mq_brain_run exited $code but 'mqlaunch $verb' returned $got" >&2
      exit 1
    fi
  done
done
echo "  ok: 8 brain verbs propagate 0, 1, 2 and 127"

echo "[9/12] a missing brain bridge still fails, and says so"
# The `else` arm was already correct. It is pinned here so fixing the success
# path cannot quietly turn a missing bridge into a silent success.
(
  unset -f mq_brain_run 2>/dev/null || true
  out="$(dispatch_cli_command brain 2>&1)" && {
    echo "FAIL: a missing brain bridge was reported as success" >&2
    exit 1
  }
  case "$out" in
    *"brain-bridge not loaded"*) ;;
    *) echo "FAIL: missing bridge did not say so: $out" >&2; exit 1 ;;
  esac
)
echo "  ok: a missing bridge fails with a named reason"

echo "[10/12] function delegates that run an operation propagate their status"
# Seven branches called a shell-function delegate and ended in `return 0`. Step
# 7 never looked at them, because it only inspects branches invoking a
# $BASE_DIR script. Each was measured with the delegate stubbed to exit 7
# before deciding what to do about it, rather than sorted by reading.
fn_status() {
  local code="$1" fn="$2"
  shift 2
  (
    eval "$fn() { return $code; }"
    dispatch_cli_command "$@" >/dev/null 2>&1
  )
}

# Coordinates expect status behavior.
expect_status() {
  local want="$1" fn="$2"
  shift 2
  local got=0
  fn_status 7 "$fn" "$@" || got=$?
  if [[ "$got" != "$want" ]]; then
    printf 'FAIL: %s exited 7 but `mqlaunch %s` returned %s (want %s)\n' \
      "$fn" "$*" "$got" "$want" >&2
    exit 1
  fi
}

# Real operations. `learn-promote` is the one that matters most: it runs
# `mq-agent learn promote <slug> --approve`, a Class C write, and reported
# success whatever happened.
expect_status 7 _run_agent       review-brain .
expect_status 7 _run_agent       signal-brain .
expect_status 7 _run_agent       learn-promote some-slug
# Mixed branches: a menu with no argument, an operation with one. Only the
# operation's status is real.
expect_status 7 run_mqworkflows  workflows save
expect_status 7 run_mqlogin      login status
expect_status 7 run_mqshortcuts  shortcuts list
# `theme` and `system` are the same mixed shape, found by the P2 operator sweep
# rather than by this test: both propagated in *both* directions, so their menu
# path reported failure with no terminal. Their argument paths are real work and
# must keep propagating, which is what these four lines hold.
expect_status 7 theme_cmd        theme apply amber
expect_status 7 theme_cmd        theme current
expect_status 7 system_check     system check
expect_status 7 show_network_info system network
echo "  ok: ten operation paths propagate a failing delegate"

echo "[11/12] a menu ending is not a failure"
# Deliberate exit 0, and the reason is in tests/menu-eof-smoke.sh: without a
# terminal a menu loop exits non-zero by design. Propagating that would report
# "the command failed" for "there was no terminal". Pinned so the deliberate
# part cannot be mistaken for the bug above and "fixed".
expect_status 0 run_mqworkflows  workflows
expect_status 0 run_mqlogin      login
expect_status 0 run_mqshortcuts  shortcuts
# atlas is an interactive session in both forms — there is no non-interactive
# result for a caller to act on.
expect_status 0 mq_ai_run_atlas  atlas
expect_status 0 mq_ai_run_atlas  atlas "some prompt"
# The two the P2 sweep caught. Measured headless: `git`, `release`, `shortcuts`,
# `tools`, `workflows`, `dev`, `hal` and `performance` all ended at their prompt
# and exited 0; `system` and `theme` ended at the identical prompt and exited 1.
# One surface, two answers, and the difference was invisible to step 7 because
# neither branch invokes a $BASE_DIR script.
expect_status 0 open_themes_menu theme
expect_status 0 open_themes_menu theme menu
expect_status 0 open_system_menu system
expect_status 0 open_system_menu system menu
echo "  ok: eight interactive entrypoints return 0 on purpose"

echo "[12/12] apps splits the same way, with an external delegate"
# `apps` is the third outlier and does not fit the harness above: it runs
# tools/scripts/hal-terminal-guide.sh rather than a shell function. Stubbed
# through a fake BASE_DIR so both paths are observed rather than reasoned about.
apps_fake="$(mktemp -d)"
mkdir -p "$apps_fake/tools/scripts"
cat > "$apps_fake/tools/scripts/hal-terminal-guide.sh" <<'STUB'
#!/usr/bin/env bash
exit 7
STUB
chmod +x "$apps_fake/tools/scripts/hal-terminal-guide.sh"

# Coordinates apps status behavior.
apps_status() {
  local got=0
  (
    # shellcheck disable=SC2034  # read by the dispatcher, which is sourced above
    BASE_DIR="$apps_fake"
    dispatch_cli_command "$@" >/dev/null 2>&1
  ) || got=$?
  printf '%s' "$got"
}

bare_got="$(apps_status apps)"
if [[ "$bare_got" != "0" ]]; then
  printf 'FAIL: bare `mqlaunch apps` returned %s, want 0 (the guide is interactive)\n' \
    "$bare_got" >&2
  rm -rf "$apps_fake"
  exit 1
fi
ask_got="$(apps_status apps ask what is this)"
if [[ "$ask_got" != "7" ]]; then
  printf 'FAIL: `mqlaunch apps ask ...` returned %s, want 7 (a real question failed)\n' \
    "$ask_got" >&2
  rm -rf "$apps_fake"
  exit 1
fi
rm -rf "$apps_fake"
echo "  ok: the guide opening is 0, a failed question is 7"

bash -n "$0"
echo "OK: delegated failures preserve their exit status"
