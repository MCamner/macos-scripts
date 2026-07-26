#!/usr/bin/env bash
# Enforces the output contract from docs/RUNTIME_AUTHORITY.md:
#
#   * NO_COLOR=1 suppresses ANSI color (even on a TTY)
#   * --no-color does the same thing from the command line
#   * JSON mode prints only JSON to stdout — no banner, no ANSI
#   * plain commands print no banner, no box drawing and no cursor codes when
#     stdout is not a terminal
#
# (Delegated exit-status preservation is covered by delegated-exit-code-smoke.sh.)
#
# The NO_COLOR check needs a real TTY (color is TTY-gated), so it runs the color
# init under a pseudo-terminal via python3 (portable on macOS and Linux). The
# JSON checks run headless: once against the deterministic producer
# (tools/scripts/doctor.sh) and once end-to-end through the launcher
# (mqlaunch status --json), which is the path a caller actually pipes. Part of
# the v2.0.0 "Plain and machine-readable output contract" P1 block.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: plain and machine-readable output contract"

DOCTOR="$ROOT/tools/scripts/doctor.sh"

echo "[1/9] files exist"
test -f "$UI"
test -f "$LAUNCH"
test -f "$DOCTOR"

echo "[2/9] NO_COLOR suppresses ANSI color on a TTY (behavioural, via pty)"
python3 - "$ROOT" <<'PY'
import os, pty, subprocess, sys

root = sys.argv[1]
ESC = b"\x1b"

def title_on_tty(no_color: bool) -> bytes:
    env = dict(os.environ, MACOS_SCRIPTS_HOME=root)
    if no_color:
        env["NO_COLOR"] = "1"
    else:
        env.pop("NO_COLOR", None)
    # Source the UI lib with a TTY stdout, then emit C_TITLE between markers.
    script = f'source "{root}/ui/terminal-ui/mq-ui.sh"; printf "<%s>" "$C_TITLE"'
    master, slave = pty.openpty()
    proc = subprocess.Popen(["bash", "-c", script], stdout=slave,
                            stderr=subprocess.DEVNULL, env=env)
    os.close(slave)
    out = b""
    while True:
        try:
            chunk = os.read(master, 1024)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
    proc.wait()
    os.close(master)
    return out

colored = title_on_tty(no_color=False)
plain = title_on_tty(no_color=True)

# Sanity: on a TTY without NO_COLOR, the title colour must contain an ESC —
# otherwise the pty is not actually enabling color and the test proves nothing.
assert ESC in colored, f"expected ANSI on a TTY, got {colored!r}"
# The contract: NO_COLOR=1 removes the ANSI colour entirely.
assert ESC not in plain, f"NO_COLOR=1 still emitted ANSI: {plain!r}"
print("  ok: color on TTY, none under NO_COLOR")
PY

echo "[3/9] NO_COLOR is honoured in the central colour guard (structural)"
# Fixed-string match: the guard line is literal, and ERE brace handling differs
# between BSD (macOS) and GNU (Linux) grep.
# shellcheck disable=SC2016
grep -qF 'if [[ -t 1 && -z "${NO_COLOR:-}" ]]' "$UI"

echo "[4/9] JSON mode prints only JSON to stdout — no banner, no ANSI"
# Test the JSON producer directly: it is deterministic regardless of which tools
# are installed. A health check may legitimately exit non-zero when tools are
# missing, so the exit status is captured, not asserted — the contract is that
# --json stdout is clean JSON, not that every check passes.
json_out="$(MACOS_SCRIPTS_HOME="$ROOT" bash "$DOCTOR" --json 2>/dev/null)" || true
printf '%s' "$json_out" | python3 -c '
import sys, json
data = sys.stdin.buffer.read()
assert data, "no JSON on stdout"
assert b"\x1b" not in data, "ANSI escape leaked into JSON stdout"
assert data.lstrip()[:1] in (b"{", b"["), "stdout does not start with JSON"
json.loads(data)                # must parse as a single JSON document
print("  ok: valid JSON, no ANSI, no banner")
'

echo "[5/9] mqlaunch status --json emits JSON only — end-to-end through the launcher"
# The producer being clean is not enough: the launcher is what a caller pipes.
# bin/mqlaunch resolves the repo through BASE_DIR, so pin it at this checkout.
# MQ_NO_TUI keeps any interactive path from blocking if this ever regresses.
status_out="$(BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
  bash "$LAUNCH" status --json 2>/dev/null)" || true
printf '%s' "$status_out" | python3 -c '
import sys, json
data = sys.stdin.buffer.read()
assert data, "no JSON on stdout"
assert b"\x1b" not in data, "ANSI escape leaked into status --json stdout"
assert b"MQLAUNCH" not in data, "banner leaked into status --json stdout"
assert data.lstrip()[:1] == b"{", "stdout does not start with a JSON object"
doc = json.loads(data)              # must parse as a single JSON document
for key in ("project", "version", "repo_state"):
    assert key in doc, f"status --json is missing key: {key}"
print("  ok: status --json is a single clean JSON document")
'

echo "[6/9] the JSON status path stays side-effect free (structural)"
# print_status_json must not fall back into the dashboard renderer: that one runs
# the full test suite and calls pause_enter, so reusing it here would make a
# machine-readable command slow, interactive, and (run from test-all) recursive.
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
json_status_body="$(awk '/^print_status_json\(\) \{/{f=1} f{print} f&&/^\}/{exit}' \
  "$COMMAND_MODE")"
test -n "$json_status_body"
! grep -q 'test-all.sh' <<<"$json_status_body"
! grep -q 'pause_enter' <<<"$json_status_body"
! grep -q 'print_header' <<<"$json_status_body"
# Without --json, status must still render the dashboard.
grep -q 'show_about_dashboard' "$COMMAND_MODE"

echo "[7/9] plain status is clean when piped and when redirected"
# The banner was the remaining hole in the contract (#67): the colour guard was
# doing its job — zero ANSI in a pipe — but ASCII art is not colour, so a caller
# who did not know about --json got 5.8 KB of dashboard on stdout and exit 0.
# Parseable-looking, unparseable in practice.
#
# Both destinations are checked because they are different tests of the same
# guard: `| cat` gives a pipe, `> file` gives a regular file, and a check that
# looked at anything other than isatty(1) would pass one and fail the other.
plain_dir="$(mktemp -d)"
trap 'rm -rf "$plain_dir"' EXIT

set +e
BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
  timeout 30 bash "$LAUNCH" status | cat >"$plain_dir/piped.out" 2>/dev/null
piped_status="${PIPESTATUS[0]}"
BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
  timeout 30 bash "$LAUNCH" status >"$plain_dir/file.out" 2>/dev/null
file_status=$?
set -e

test "$piped_status" -eq 0
test "$file_status" -eq 0

python3 - "$plain_dir/piped.out" "$plain_dir/file.out" <<'PY'
import sys

# Every marker here is something that only makes sense on a terminal.
DECORATION = {
    "ANSI escape": b"\x1b",          # colour and cursor control both start here
    "ASCII logo": "█".encode(),
    "phosphor banner": b"PHOSPHOR GRID",
    "box drawing": "╔".encode(),
    "panel border": "┌─".encode(),
}

for path in sys.argv[1:]:
    with open(path, "rb") as handle:
        data = handle.read()
    label = path.rsplit("/", 1)[-1]

    assert data, f"{label}: status produced no output at all"
    for name, marker in DECORATION.items():
        assert marker not in data, f"{label}: {name} leaked into non-TTY output"

    # Content must survive the decoration being removed — a contract met by
    # printing nothing would be worse than the banner.
    for field in (b"Project:", b"Version:", b"Repo state:"):
        assert field in data, f"{label}: lost {field.decode()} in plain mode"

    # Rows are padded to BOX_INNER for the box borders to line up. There is no
    # box here, so the padding is trailing whitespace on every line, and the
    # 88-column truncation that comes with it silently cuts long paths.
    padded = [n for n, line in enumerate(data.decode().splitlines(), 1)
              if line != line.rstrip()]
    assert not padded, f"{label}: trailing box padding on lines {padded[:5]}"

    # Asking for status must not run the test suite. It is a thirty-second side
    # effect, and since the suite runs this very test it would not terminate.
    for line in data.decode().splitlines():
        if line.startswith("Smoke tests:"):
            assert "PASS" not in line and "FAIL" not in line, \
                f"{label}: plain status ran the suite ({line.strip()})"

print("  ok: piped and redirected status carry content without decoration")
PY

echo "[8/9] the header still renders on a terminal (both directions, via pty)"
# The risk in suppressing the banner is suppressing it everywhere. This asserts
# the human path in the same breath as the machine path, because a guard that
# only ever proves the negative would also pass if print_header were deleted.
python3 - "$ROOT" <<'PY'
import os, pty, subprocess, sys

root = sys.argv[1]
script = f'source "{root}/ui/terminal-ui/mq-ui.sh"; print_header'
env = dict(os.environ, MACOS_SCRIPTS_HOME=root, TERM="xterm-256color")
env.pop("NO_COLOR", None)

master, slave = pty.openpty()
proc = subprocess.Popen(["bash", "-c", script], stdin=slave, stdout=slave,
                        stderr=subprocess.DEVNULL, env=env)
os.close(slave)
on_tty = b""
while True:
    try:
        chunk = os.read(master, 4096)
    except OSError:
        break
    if not chunk:
        break
    on_tty += chunk
proc.wait()
os.close(master)

piped = subprocess.run(["bash", "-c", script], capture_output=True, env=env).stdout

assert b"MQLaunch" in on_tty or b"-----" in on_tty, \
    f"header did not render on a TTY: {on_tty[:200]!r}"
assert piped == b"", f"header rendered into a pipe: {piped[:200]!r}"
print("  ok: header on a terminal, nothing in a pipe")
PY

echo "[9/9] --no-color disables colour from the command line (both directions, via pty)"
# NO_COLOR is an environment variable; a caller with a command line and no
# control over the environment needs the flag form. `commands` is the probe
# because it colours its output and returns without waiting for a keypress.
#
# The comparison runs the same command twice under the same pty, so the only
# variable is the flag. Cursor control (ESC [ H, ESC [ 2 J) is not colour, so
# this matches SGR sequences specifically instead of any escape.
python3 - "$ROOT" <<'PY'
import os, pty, re, select, subprocess, sys, time

root = sys.argv[1]
SGR = re.compile(rb"\x1b\[[0-9;]*m")

def run_on_tty(args):
    env = dict(os.environ, MACOS_SCRIPTS_HOME=root, BASE_DIR=root,
               TERM="xterm-256color")
    env.pop("NO_COLOR", None)
    master, slave = pty.openpty()
    proc = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave,
                            env=env, cwd=root)
    os.close(slave)
    out = b""
    deadline = time.time() + 30
    answers = 0
    while time.time() < deadline:
        ready, _, _ = select.select([master], [], [], 0.5)
        if ready:
            try:
                chunk = os.read(master, 8192)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
        elif proc.poll() is not None:
            break
        elif answers < 3:
            # There is a terminal here, so `pause_enter` does pause. Answer it,
            # or the command sits on the deadline instead of exiting.
            os.write(master, b"\n")
            answers += 1
    if proc.poll() is None:
        proc.kill()
    proc.wait()
    os.close(master)
    return out

launcher = f"{root}/bin/mqlaunch"
colored = run_on_tty(["bash", launcher, "commands"])
plain = run_on_tty(["bash", launcher, "--no-color", "commands"])

assert b"Unknown command" not in plain, "--no-color was dispatched as a command"
# Sanity, again: without the flag this command must actually emit colour, or the
# comparison below is vacuous.
assert SGR.search(colored), "expected SGR colour on a TTY without --no-color"
assert not SGR.search(plain), \
    f"--no-color still emitted colour: {SGR.findall(plain)[:3]!r}"
# The flag must be consumed, not forwarded — the command still has to run.
assert len(plain) > 1000, f"--no-color suppressed the output itself: {len(plain)} bytes"
print("  ok: colour on a TTY, none with --no-color, command still runs")
PY

echo "PASS: output contract holds (no decoration off-TTY, colour opt-out, clean JSON)"
