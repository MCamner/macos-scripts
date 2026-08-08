#!/usr/bin/env bash
# Locks the contract of ui_spinner, the shell half of the progress surface.
#
# mq-agent has shown a spinner for slow work since it grew rich panels; the
# shell side had no progress primitive at all, so every menu that shelled out
# to gh, ollama or a test run simply went quiet. This adds one helper, and the
# risk of a helper that wraps arbitrary commands is that it quietly changes
# what those commands do. So the contract is exactly three promises:
#
#   1. the wrapped command's exit status is the helper's exit status
#   2. the wrapped command's stdout passes through untouched
#   3. nothing is drawn unless a human is watching a terminal
#
# (3) is the same rule plain-output-contract-smoke.sh enforces for the banner:
# frames and cursor codes must never reach a pipe. The pty step proves the
# other half — that a human *does* get frames — because a spinner that is
# merely safe is a spinner that never animates.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"

echo "SMOKE: ui_spinner progress helper"

echo "[1/9] the helper exists"
test -f "$UI"
grep -q "^ui_spinner()" "$UI"

echo "[2/9] a successful command exits 0 and its stdout passes through"
output="$(bash -c "source '$UI'; ui_spinner 'Working' printf 'hello\n'")"
test "$output" = "hello"

echo "[3/9] a failing command's exit status is the helper's exit status"
rc=0
bash -c "source '$UI'; ui_spinner 'Working' sh -c 'exit 7'" || rc=$?
test "$rc" -eq 7

echo "[4/9] headless output is byte-identical to running the command directly"
# No frames, no \r, no erase-line. A caller that pipes ui_spinner into a parser
# must not have to strip anything.
captured="$(bash -c "source '$UI'; ui_spinner 'Working' printf 'a\nb\n'" | od -c | head -3)"
direct="$(printf 'a\nb\n' | od -c | head -3)"
test "$captured" = "$direct"

echo "[5/9] MQ_NO_SPINNER=1 disables animation even on a terminal"
python3 - "$UI" <<'PY'
import os, pty, sys

ui = sys.argv[1]
# CI runs the whole suite with MQ_NO_TUI=1 (.github/workflows/quality.yml),
# which also suppresses the spinner. Drop it so this step proves MQ_NO_SPINNER
# and nothing else.
os.environ.pop("MQ_NO_TUI", None)
os.environ["MQ_NO_SPINNER"] = "1"
seen = bytearray()


def read(fd):
    chunk = os.read(fd, 1024)
    seen.extend(chunk)
    return chunk


status = pty.spawn(["bash", "-c", f"source '{ui}'; ui_spinner 'Working' sleep 0.3"], read)
assert os.waitstatus_to_exitcode(status) == 0
assert b"\xe2\xa0" not in seen, "braille frame leaked with MQ_NO_SPINNER=1"
PY

echo "[6/9] on a real terminal a human sees frames, and they are cleaned up"
# The capture case is the one that matters: `out="$(ui_spinner … )"` is how a
# shell caller actually uses a slow command, and gating the animation on stdout
# being a terminal would silently disable the spinner in exactly that shape.
# Frames go to /dev/tty, so the capture stays clean while the human still sees
# something move.
python3 - "$UI" <<'PY'
import os, pty, sys

ui = sys.argv[1]
# Same reason as step 5: this step is *about* the interactive path, so the
# headless switch CI sets globally has to come off first.
os.environ.pop("MQ_NO_TUI", None)
os.environ.pop("MQ_NO_SPINNER", None)
seen = bytearray()


def read(fd):
    chunk = os.read(fd, 1024)
    seen.extend(chunk)
    return chunk


script = (
    f"source '{ui}'\n"
    "ui_spinner 'Working' sleep 0.5\n"
    "out=\"$(ui_spinner 'Capturing' printf 'captured\\n')\"\n"
    "printf 'GOT:%s\\n' \"$out\"\n"
)
status = pty.spawn(["bash", "-c", script], read)
assert os.waitstatus_to_exitcode(status) == 0, "spinner changed the exit status"
# Braille frames are U+28xx, which is 0xE2 0xA0 in UTF-8.
assert b"\xe2\xa0" in seen, "no spinner frame reached the terminal"
assert b"\x1b[K" in seen, "the spinner line was never erased"
assert b"GOT:captured" in seen, "command substitution lost the wrapped output"
PY

echo "[7/9] MQ_NO_TUI=1 suppresses the spinner, which is what CI relies on"
python3 - "$UI" <<'PYNOTUI'
import os, pty, sys

ui = sys.argv[1]
os.environ.pop("MQ_NO_SPINNER", None)
os.environ["MQ_NO_TUI"] = "1"
seen = bytearray()


def read(fd):
    chunk = os.read(fd, 1024)
    seen.extend(chunk)
    return chunk


status = pty.spawn(["bash", "-c", f"source '{ui}'; ui_spinner 'Working' sleep 0.3"], read)
assert os.waitstatus_to_exitcode(status) == 0
assert b"\xe2\xa0" not in seen, "braille frame leaked with MQ_NO_TUI=1"
PYNOTUI

echo "[8/9] a wrapped command that writes to stderr keeps writing to stderr"
err="$(bash -c "source '$UI'; ui_spinner 'Working' sh -c 'echo oops >&2'" 2>&1 >/dev/null)"
test "$err" = "oops"

echo "[9/9] it runs under zsh, which is the shell the menus actually use"
# The regenerate-views fix was a bash-clean function that died under zsh on a
# read-only builtin. Background jobs plus `wait` are exactly the kind of
# construct that diverges between the two, so assert it here rather than assume.
output="$(zsh -c "
  source '$UI'
  ui_spinner 'Working' printf 'zsh-ok\n'
" 2>&1)"
grep -q "zsh-ok" <<<"$output"
! grep -qi "read-only variable\|parse error\|command not found" <<<"$output"

echo "OK: ui_spinner smoke passed"
