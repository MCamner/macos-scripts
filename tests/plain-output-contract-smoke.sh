#!/usr/bin/env bash
# Enforces the output contract from docs/RUNTIME_AUTHORITY.md:
#
#   * NO_COLOR=1 suppresses ANSI color (even on a TTY)
#   * JSON mode prints only JSON to stdout — no banner, no ANSI
#
# (Delegated exit-status preservation is covered by delegated-exit-code-smoke.sh.)
#
# The NO_COLOR check needs a real TTY (color is TTY-gated), so it runs the color
# init under a pseudo-terminal via python3 (portable on macOS and Linux). The
# JSON check runs headless against the deterministic producer. Part of the
# v2.0.0 "Plain and machine-readable output contract" P1 block.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: plain and machine-readable output contract"

DOCTOR="$ROOT/tools/scripts/doctor.sh"

echo "[1/4] files exist"
test -f "$UI"
test -f "$LAUNCH"
test -f "$DOCTOR"

echo "[2/4] NO_COLOR suppresses ANSI color on a TTY (behavioural, via pty)"
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

echo "[3/4] NO_COLOR is honoured in the central colour guard (structural)"
# Fixed-string match: the guard line is literal, and ERE brace handling differs
# between BSD (macOS) and GNU (Linux) grep.
# shellcheck disable=SC2016
grep -qF 'if [[ -t 1 && -z "${NO_COLOR:-}" ]]' "$UI"

echo "[4/4] JSON mode prints only JSON to stdout — no banner, no ANSI"
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

echo "PASS: output contract holds (NO_COLOR suppressed, clean JSON on stdout)"
