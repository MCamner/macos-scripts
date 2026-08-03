#!/usr/bin/env bash
# Holds the exit-status contract for the interactive entrypoints, end to end
# through bin/mqlaunch rather than through stubs:
#
#   * a valid interactive menu with no terminal available renders at most once
#     and exits 0
#   * an operation given arguments propagates its real status
#   * an invalid argument is 2
#   * `repos` keeps 1 as a documented exception — it asks for a
#     terminal-dependent repo picker while also offering headless subcommands,
#     so "there was no terminal" is the true answer there
#
# tests/delegated-exit-code-smoke.sh already covers the same split with the
# delegate stubbed, which is the precise test. This one is the coarse one: it
# runs the real commands, in both directions, because the divergence this
# contract exists to remove was invisible to every stubbed test in the suite and
# only showed up in a headless sweep of the public surface.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: exit-status contract for interactive entrypoints"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# BASE_DIR is pinned at this checkout: bin/mqlaunch otherwise defaults it to
# $HOME/macos-scripts, which is false on a CI runner, and every step below would
# be measuring a launcher that never ran.
headless() {
  local st=0
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
    timeout 90 bash "$LAUNCH" "$@" </dev/null \
    >"$WORK/out" 2>"$WORK/err" || st=$?
  return "$st"
}

echo "[1/6] files exist"
test -x "$LAUNCH"

echo "[2/6] every interactive entrypoint exits 0 without a terminal"
# Ten commands, measured together because the defect was that they disagreed.
# `system`, `theme` and `apps` were the three answering 1 while the rest ended at
# the identical prompt and answered 0.
#
# `hal` is not on this list even though the headless sweep found it answering 0.
# It is not a local menu: it delegates to `mq_hal_run`, a bridge into the mq-hal
# repo, and its status is that delegate's. On a machine without mq-hal checked
# out it returns 127, which is the correct answer and not a contract breach —
# CI is exactly that machine. `agent`, `obsidian` and `stack` are absent for the
# same reason. Every command below runs a menu or a script inside this repo.
menus=(git release shortcuts tools workflows system theme apps dev performance)
bad=()
for menu in "${menus[@]}"; do
  st=0
  headless "$menu" || st=$?
  [[ "$st" -eq 0 ]] || bad+=("$menu=$st")
done
if [[ ${#bad[@]} -gt 0 ]]; then
  echo "FAIL: a menu ending was reported as a failure: ${bad[*]}" >&2
  exit 1
fi
echo "  ok: all ${#menus[@]} return 0"

echo "[3/6] a menu with no terminal renders once, not in a loop"
# Exiting 0 is only half the contract. A loop that re-prints its panel on every
# failed read would also exit 0 eventually, after filling the caller's pipe.
for menu in system theme tools; do
  headless "$menu" || true
  drawn="$(grep -c 'option, mqlaunch command' "$WORK/out" || true)"
  if [[ "$drawn" -ne 1 ]]; then
    echo "FAIL: $menu drew its prompt $drawn times, want exactly 1" >&2
    exit 1
  fi
done
echo "  ok: system, theme and tools each draw their prompt exactly once"

echo "[4/6] the same holds on a real terminal whose stdin is closed"
# The headless run above sets MQ_NO_TUI. This one does not: stdout is a pty, so
# the launcher takes the interactive path and the menu loop is the thing that
# meets EOF. That is the case the operator actually hits over ssh or in a
# harness, and the one the guard has to answer.
python3 - "$ROOT" <<'PY'
import os, pty, subprocess, sys

root = sys.argv[1]

def run(cmd):
    env = dict(os.environ, BASE_DIR=root, MACOS_SCRIPTS_HOME=root,
               TERM="xterm-256color")
    env.pop("MQ_NO_TUI", None)
    master, slave = pty.openpty()
    proc = subprocess.Popen(["bash", f"{root}/bin/mqlaunch", cmd],
                            stdin=subprocess.DEVNULL, stdout=slave,
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
    return proc.returncode, out

for cmd in ("system", "theme", "tools"):
    status, out = run(cmd)
    assert status == 0, f"{cmd} on a pty with closed stdin exited {status}, want 0"
    drawn = out.count(b"option, mqlaunch command")
    assert drawn == 1, f"{cmd} drew its prompt {drawn} times on a pty, want 1"

# The documented exception. `repos` is not a menu: it asks for the repo picker,
# which needs a terminal it does not have here, and it answers with the six
# subcommands that do work. 1 is the true statement.
status, out = run("repos")
assert status == 1, f"repos exited {status}, want 1 (documented exception)"
assert b"mqlaunch repos" in out, "repos did not name the command that was typed"
print("  ok: system, theme, tools are 0 and draw once; repos is a deliberate 1")
PY

echo "[5/6] an operation given arguments still propagates its real status"
# The half of the contract a "make everything 0" fix would break.
for probe in "system check:0" "system time:0" "theme current:0" "theme list:0"; do
  cmd="${probe%:*}"
  want="${probe#*:}"
  st=0
  # shellcheck disable=SC2086  # deliberate: the probe is a command line
  headless $cmd || st=$?
  if [[ "$st" -ne "$want" ]]; then
    echo "FAIL: mqlaunch $cmd exited $st, want $want" >&2
    cat "$WORK/err" >&2
    exit 1
  fi
done
echo "  ok: four operations report their own result"

echo "[6/6] an invalid argument is 2, on both surfaces"
# `theme` answered 1 here until this contract was written: the switcher exited 1
# for an unknown command word, for `apply` with no variant, and for a variant
# that does not exist. 1 reads as "the theme could not be applied" rather than
# "that is not a theme". `system` already answered 2, which is what settled it.
for probe in \
  "system bogusverb" \
  "theme bogusverb" \
  "theme apply" \
  "theme apply no-such-variant"
do
  st=0
  # shellcheck disable=SC2086  # deliberate: the probe is a command line
  headless $probe || st=$?
  if [[ "$st" -ne 2 ]]; then
    echo "FAIL: mqlaunch $probe exited $st, want 2" >&2
    cat "$WORK/err" >&2
    exit 1
  fi
done
# Runtime failures keep 1, and the distinction is the whole point of using 2
# above: 2 says "that is not a theme", 1 says "the theme could not be applied".
#
# `apply` with a valid variant rewrites `$ZSHRC`, so this runs against an
# isolated tree and an isolated HOME rather than the machine running the suite.
# An earlier version of this step tried to force the branch by setting
# THEME_FILE, which the switcher assigns unconditionally and never reads from
# the environment — so the override did nothing and the theme was applied for
# real. MACOS_SCRIPTS_HOME is the handle that does work.
fake_tree="$WORK/switcher-tree"
mkdir -p "$fake_tree/terminal/themes" "$WORK/switcher-home"
ln -s "$ROOT/ui" "$fake_tree/ui"

missing_status=0
MACOS_SCRIPTS_HOME="$fake_tree" HOME="$WORK/switcher-home" \
  bash "$ROOT/terminal/themes/mq-zsh-theme-switcher.sh" apply amber \
  >/dev/null 2>"$WORK/switcher.err" || missing_status=$?
if [[ "$missing_status" -ne 1 ]]; then
  echo "FAIL: a missing theme file exited $missing_status, want 1 (runtime, not usage)" >&2
  cat "$WORK/switcher.err" >&2
  exit 1
fi
grep -qF 'Missing theme file' "$WORK/switcher.err"
# Nothing may have been written on the way to that verdict.
if [[ -e "$WORK/switcher-home/.zshrc" ]]; then
  echo "FAIL: the switcher wrote a .zshrc while failing" >&2
  exit 1
fi
echo "  ok: four usage errors are 2, a missing theme file is 1, and nothing was written"

echo "PASS: exit-status contract for interactive entrypoints"
