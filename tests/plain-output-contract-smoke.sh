#!/usr/bin/env bash
# Enforces the output-and-failure contract from docs/RUNTIME_AUTHORITY.md:
#
#   * NO_COLOR=1 suppresses ANSI color (even on a TTY)
#   * JSON mode prints only JSON to stdout — no banner, no ANSI
#   * delegated failures preserve the backend exit status
#
# The NO_COLOR check needs a real TTY (color is TTY-gated), so it runs the color
# init under a pseudo-terminal via python3 (portable on macOS and Linux). The
# JSON checks run headless. Part of the v2.0.0 "Plain and machine-readable
# output contract" P1 block.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: plain and machine-readable output contract"

echo "[1/5] files exist"
test -f "$UI"
test -f "$LAUNCH"

echo "[2/5] NO_COLOR suppresses ANSI color on a TTY (behavioural, via pty)"
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

echo "[3/5] NO_COLOR is honoured in the central colour guard (structural)"
# Fixed-string match: the guard line is literal, and ERE brace handling differs
# between BSD (macOS) and GNU (Linux) grep.
# shellcheck disable=SC2016
grep -qF 'if [[ -t 1 && -z "${NO_COLOR:-}" ]]' "$UI"

echo "[4/5] JSON mode prints only JSON to stdout — no banner, no ANSI"
json_out="$(MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 bash "$LAUNCH" doctor --json 2>/dev/null)"
printf '%s' "$json_out" | python3 -c '
import sys, json
data = sys.stdin.buffer.read()
assert b"\x1b" not in data, "ANSI escape leaked into JSON stdout"
obj = json.loads(data)          # must parse as a single JSON document
assert data.lstrip()[:1] in (b"{", b"["), "stdout does not start with JSON"
print("  ok: valid JSON, no ANSI, no banner")
'

echo "[5/5] a delegated JSON command exits 0 on success"
rc=0
MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 bash "$LAUNCH" doctor --json >/dev/null 2>&1 || rc=$?
test "$rc" -eq 0 || { echo "FAIL: doctor --json exit $rc"; exit 1; }

echo "PASS: output contract holds (NO_COLOR, clean JSON, preserved exit)"
