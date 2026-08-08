#!/usr/bin/env bash
# Locks the operator-facing failure messages for the two commands the P2
# inventory measured as unclear: `skills` and `repos` called with no argument.
#
# Measured before the fix:
#
#   $ mqlaunch skills
#   usage: mq-skills.py [-h] [--repo REPO] {audit,validate,new} ...
#   mq-skills.py: error: the following arguments are required: command   exit 2
#
#   $ mqlaunch repos
#   GitHub repo picker needs a terminal.                                 exit 1
#
# The first hands the operator the delegate's file name and argparse phrasing
# for a command they typed as `mqlaunch skills`. The second names a different
# subject than the word typed — `repos` routes to the hub when bare — and offers
# no next step, even though six `repos` subcommands work headless.
#
# The fix is confined to the message, the usage and the next step. This test
# therefore checks two things in the same breath: that the new message is there,
# and that everything underneath still runs. A "fix" that stopped delegating
# would pass a message-only check.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH="$ROOT/bin/mqlaunch"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"

echo "SMOKE: operator usage messages for skills and repos"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Runs a command through the launcher, headless. BASE_DIR is pinned at this
# checkout: bin/mqlaunch otherwise defaults it to $HOME/macos-scripts, which is
# false on a CI runner, and the step would be measuring a launcher that never
# ran. Returns the launcher's status; stdout and stderr land in $WORK.
launch() {
  local st=0
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
    timeout 90 bash "$LAUNCH" "$@" </dev/null \
    >"$WORK/out" 2>"$WORK/err" || st=$?
  return "$st"
}

echo "[1/8] files exist"
test -x "$LAUNCH"
test -f "$COMMAND_MODE"

echo "[2/8] mqlaunch skills with no command prints mqlaunch usage, not argparse"
skills_status=0
launch skills || skills_status=$?
test "$skills_status" -eq 2
# Diagnostics belong on stderr, and nothing on stdout: a caller piping this
# command must not receive a usage block as if it were data.
if [[ -s "$WORK/out" ]]; then
  echo "FAIL: skills usage went to stdout" >&2
  cat "$WORK/out" >&2
  exit 1
fi
for leaked in 'mq-skills.py' 'the following arguments are required'; do
  if grep -qF -- "$leaked" "$WORK/err"; then
    echo "FAIL: delegate internals reached the operator: $leaked" >&2
    cat "$WORK/err" >&2
    exit 1
  fi
done
grep -qF -- 'Usage: mqlaunch skills' "$WORK/err"
# The next step has to be nameable, not just implied.
for verb in audit validate new; do
  grep -qF -- "$verb" "$WORK/err"
done
echo "  ok: exit 2, mqlaunch usage on stderr, no script name, verbs listed"

echo "[3/8] the same message appears on a real terminal"
# The message must not depend on being headless: someone typing `mqlaunch
# skills` in their terminal is the likelier reader of the two.
python3 - "$ROOT" <<'PY'
import os, pty, subprocess, sys

root = sys.argv[1]
env = dict(os.environ, BASE_DIR=root, MACOS_SCRIPTS_HOME=root)
env.pop("MQ_NO_TUI", None)

master, slave = pty.openpty()
proc = subprocess.Popen(["bash", f"{root}/bin/mqlaunch", "skills"],
                        stdin=subprocess.DEVNULL, stdout=slave, stderr=slave,
                        env=env)
os.close(slave)
out = b""
while True:
    try:
        chunk = os.read(master, 65536)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
proc.wait()
os.close(master)

text = out.decode("utf-8", "replace")
assert "Usage: mqlaunch skills" in text, f"no mqlaunch usage on a TTY: {text!r}"
assert "mq-skills.py" not in text, f"script name leaked on a TTY: {text!r}"
print("  ok: same usage on a TTY, still no script name")
PY

echo "[4/8] mqlaunch skills <verb> still reaches the delegate, with its arguments"
# The guard must fire on the empty argument list only. If it swallowed verbs the
# message check above would still pass and the command would be dead.
#
# The delegate is stubbed rather than run. `mq-skills.py audit` scans the MQ
# repos, so on a machine that has none — a CI runner — it reports nothing and
# the step would be measuring the checkout rather than the routing. What is
# being tested here is which command line the arm builds.
skills_fake="$WORK/skills-fake"
mkdir -p "$skills_fake/tools/scripts"
cat > "$skills_fake/tools/scripts/mq-skills.py" <<'EOF'
#!/usr/bin/env bash
printf 'DELEGATE:'
printf ' %s' "$@"
printf '\n'
EOF
chmod +x "$skills_fake/tools/scripts/mq-skills.py"

routed="$(
  MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 bash -c '
    source "$1" >/dev/null 2>&1
    BASE_DIR="$2"
# Pauses until Enter is pressed.
    pause_enter() { :; }
    dispatch_cli_command skills audit --repo /tmp/x
  ' _ "$COMMAND_MODE" "$skills_fake" 2>&1
)"
if [[ "$routed" != "DELEGATE: audit --repo /tmp/x" ]]; then
  echo "FAIL: skills did not forward the verb and its arguments unchanged" >&2
  printf '  got: %s\n' "$routed" >&2
  exit 1
fi
echo "  ok: verb and arguments forwarded verbatim"

echo "[5/8] an unknown verb still reaches the delegate, which names the word typed"
# Deliberately not intercepted. mqlaunch would have to carry a second copy of
# the verb list to do it, and the delegate's error already names the word the
# operator typed, which is the part that helps.
bogus_status=0
launch skills bogus || bogus_status=$?
test "$bogus_status" -eq 2
grep -qF -- 'bogus' "$WORK/err"
echo "  ok: invalid choice still answered by the delegate"

echo "[6/8] mqlaunch repos with no command explains itself and names the way out"
repos_status=0
launch repos || repos_status=$?
# Exit status is deliberately unchanged at 1. The command did not fail on usage
# — it is valid with no argument on a terminal — so this stays an environment
# failure, and no caller's exit-code handling moves.
test "$repos_status" -eq 1
if [[ -s "$WORK/out" ]]; then
  echo "FAIL: repos diagnostics went to stdout" >&2
  exit 1
fi
if grep -qF -- 'GitHub repo picker' "$WORK/err"; then
  echo "FAIL: the message still names a subject the operator did not type" >&2
  cat "$WORK/err" >&2
  exit 1
fi
grep -qF -- 'mqlaunch repos' "$WORK/err"
# Every subcommand that does work without a terminal has to be listed, or the
# operator is still stuck.
for verb in list status roadmaps skills wiki-status diff-summary; do
  if ! grep -qF -- "$verb" "$WORK/err"; then
    echo "FAIL: repos message does not offer '$verb' as a next step" >&2
    cat "$WORK/err" >&2
    exit 1
  fi
done
echo "  ok: exit 1, names the command typed, lists all six headless subcommands"

echo "[7/8] on a terminal, bare repos still opens the hub"
# The behaviour, not the absence of a message. BASE_DIR points at a tree holding
# nothing but a stubbed bin/mqlaunch, so reaching the hub is observable and
# nothing interactive actually starts.
fake="$WORK/fake"
mkdir -p "$fake/bin"
cat > "$fake/bin/mqlaunch" <<'EOF'
#!/usr/bin/env bash
printf 'HUB REACHED: %s\n' "$*"
EOF
chmod +x "$fake/bin/mqlaunch"

hub_out="$(python3 - "$ROOT" "$COMMAND_MODE" "$fake" <<'PY'
import os, pty, subprocess, sys

root, command_mode, fake = sys.argv[1], sys.argv[2], sys.argv[3]
script = (f'source "{command_mode}" >/dev/null 2>&1; '
          f'BASE_DIR="{fake}"; pause_enter() {{ :; }}; '
          'dispatch_cli_command repos')
env = dict(os.environ, MACOS_SCRIPTS_HOME=root)
env.pop("MQ_NO_TUI", None)

master, slave = pty.openpty()
proc = subprocess.Popen(["bash", "-c", script], stdin=slave, stdout=slave,
                        stderr=slave, env=env)
os.close(slave)
out = b""
while True:
    try:
        chunk = os.read(master, 65536)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
proc.wait()
os.close(master)
sys.stdout.write(out.decode("utf-8", "replace"))
PY
)"
if ! grep -qF 'HUB REACHED: hub' <<<"$hub_out"; then
  echo "FAIL: bare repos no longer opens the hub on a terminal" >&2
  printf '%s\n' "$hub_out" >&2
  exit 1
fi
echo "  ok: the terminal path is untouched"

echo "[8/8] repos subcommands still forward unchanged"
# Stubbed for the same reason as step 4: mq-repos.py reads the MQ repos from
# disk, and a CI runner has none, so running it for real would measure the
# checkout instead of the routing.
repos_fake="$WORK/repos-fake"
mkdir -p "$repos_fake/tools/scripts"
cat > "$repos_fake/tools/scripts/mq-repos.py" <<'EOF'
#!/usr/bin/env bash
printf 'DELEGATE:'
printf ' %s' "$@"
printf '\n'
EOF
chmod +x "$repos_fake/tools/scripts/mq-repos.py"

for probe in "list" "status --short" "diff-summary"; do
  # shellcheck disable=SC2086  # deliberate: the probe is a command line
  got="$(
    MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 bash -c '
      source "$1" >/dev/null 2>&1
      BASE_DIR="$2"
# Pauses until Enter is pressed.
      pause_enter() { :; }
      shift 2
      dispatch_cli_command repos "$@"
    ' _ "$COMMAND_MODE" "$repos_fake" $probe 2>&1
  )"
  if [[ "$got" != "DELEGATE: $probe" ]]; then
    echo "FAIL: repos $probe did not forward unchanged" >&2
    printf '  got: %s\n' "$got" >&2
    exit 1
  fi
done
echo "  ok: three subcommands forward verbatim, guard fires only on the empty case"

echo "PASS: operator usage messages for skills and repos"
