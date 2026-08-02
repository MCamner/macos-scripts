#!/usr/bin/env bash
# Locks the ANSI colour contract for the two surfaces that still wrote escapes
# unconditionally: tools/scripts/pulse.sh, which defines its own colour
# variables, and tools/cli/mq-ui.sh, which is sourced by scan.sh, brew-check.sh
# and doctor.sh.
#
# Measured before the fix: `mqlaunch pulse` wrote 20 ANSI sequences with stdout
# redirected to a file, and neither NO_COLOR=1 nor --no-color removed one of
# them; `mqlaunch scan` wrote 36. Both bypassed the central guard in
# ui/terminal-ui/mq-ui.sh that plain-output-contract-smoke.sh already enforces,
# so the P1 output contract was only true for the commands that happened to go
# through the shared library.
#
# The contract has two halves, and this test checks both — suppressing colour by
# dropping output would otherwise pass a bare "no ANSI" check:
#
#   * zero ANSI when stdout is not a TTY, under NO_COLOR=1, and under --no-color
#   * colour still emitted on a real terminal, with the ASCII banner, headings,
#     rules, glyphs, text and line count identical in both modes
#
# Colour is TTY-gated, so the "colour is still there" half runs under a
# pseudo-terminal via python3 (portable on macOS and Linux), the same technique
# plain-output-contract-smoke.sh uses. The network and Wi-Fi tools pulse.sh
# calls are stubbed, which keeps the run fast, deterministic, and off the
# network — and lets every colour branch fire, including the ones that only
# appear when the probes succeed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULSE="$ROOT/tools/scripts/pulse.sh"
CLI_UI="$ROOT/tools/cli/mq-ui.sh"
LAUNCH="$ROOT/bin/mqlaunch"

echo "SMOKE: colour contract for pulse.sh and tools/cli/mq-ui.sh"

echo "[1/10] files exist"
test -f "$PULSE"
test -f "$CLI_UI"
test -x "$LAUNCH"

# --- stub the probes pulse.sh shells out to -------------------------------
# Values chosen so the success branches run: a present RSSI reaches the
# GREEN/YELLOW/CYAN metrics block instead of the RED "could not retrieve" one,
# and a round-trip line reaches the GREEN latency branch instead of RED TIMEOUT.
STUB="$(mktemp -d)"
trap 'rm -rf "$STUB"' EXIT

cat > "$STUB/networksetup" <<'EOF'
#!/bin/sh
echo "Hardware Port: Wi-Fi"
echo "Device: en0"
EOF

cat > "$STUB/wdutil" <<'EOF'
#!/bin/sh
echo "    RSSI                 : -55 dBm"
echo "    Noise                : -92 dBm"
echo "    Channel              : 6 (2GHz)"
EOF

cat > "$STUB/ping" <<'EOF'
#!/bin/sh
echo "3 packets transmitted, 3 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 1.0/2.0/3.0/0.5 ms"
EOF

cat > "$STUB/route" <<'EOF'
#!/bin/sh
echo "   gateway: 192.168.1.1"
EOF

chmod +x "$STUB"/networksetup "$STUB"/wdutil "$STUB"/ping "$STUB"/route

esc_count() {
  # Count ESC bytes, not lines: several escapes share a line.
  LC_ALL=C python3 -c 'import sys; sys.stdout.write(str(open(sys.argv[1],"rb").read().count(b"\x1b")))' "$1"
}

# --- pulse.sh --------------------------------------------------------------

echo "[2/10] pulse.sh emits zero ANSI when stdout is not a TTY"
# TERM is set deliberately. `clear` writes ^[[3J^[[H^[[2J to a pipe whenever it
# can read a terminfo entry, so a run with TERM unset would pass this check
# without the screen-clear ever being gated.
PATH="$STUB:$PATH" TERM=xterm-256color bash "$PULSE" > "$STUB/plain.txt" 2>/dev/null
plain_esc="$(esc_count "$STUB/plain.txt")"
if [[ "$plain_esc" != "0" ]]; then
  echo "FAIL: pulse.sh emitted $plain_esc ANSI escapes with stdout redirected" >&2
  LC_ALL=C cat -v "$STUB/plain.txt" | head -5 >&2
  exit 1
fi
echo "  ok: 0 escapes headless (TERM=xterm-256color)"

echo "[3/10] pulse.sh emits zero ANSI under NO_COLOR=1 on a real TTY"
python3 - "$ROOT" "$STUB" <<'PY'
import os, pty, subprocess, sys

root, stub = sys.argv[1], sys.argv[2]

def run_on_tty(no_color: bool) -> bytes:
    env = dict(os.environ, PATH=f"{stub}:{os.environ['PATH']}",
               TERM="xterm-256color", MACOS_SCRIPTS_HOME=root)
    if no_color:
        env["NO_COLOR"] = "1"
    else:
        env.pop("NO_COLOR", None)
    master, slave = pty.openpty()
    proc = subprocess.Popen(["bash", f"{root}/tools/scripts/pulse.sh"],
                            stdout=slave, stderr=subprocess.DEVNULL,
                            stdin=subprocess.DEVNULL, env=env)
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
    return out

colored = run_on_tty(no_color=False)
plain = run_on_tty(no_color=True)

# Sanity first: if the pty is not actually enabling colour, the NO_COLOR
# assertion below proves nothing.
assert b"\x1b[0;36m" in colored, "expected CYAN on a TTY, pty did not enable colour"
assert b"\x1b[0;32m" in colored, "expected GREEN on a TTY — stubs did not reach the success branch"

# On a real terminal NO_COLOR removes every colour escape. The screen clear is
# not one: it is a terminal action rather than output, and clear_screen() in
# ui/terminal-ui/mq-ui.sh gates it on `[[ ! -t 1 ]]` alone, so every other
# mqlaunch screen still clears under NO_COLOR. pulse.sh follows that rule, and
# the check below names the sequences it is allowed to keep instead of waving
# escapes through in bulk.
import re
CLEAR_SEQS = {b"\x1b[3J", b"\x1b[H", b"\x1b[2J"}
leftover = [m for m in re.findall(rb"\x1b\[[0-9;]*[A-Za-z]", plain)
            if m not in CLEAR_SEQS]
assert not leftover, f"NO_COLOR=1 still emitted colour on a TTY: {leftover!r}"

# The other half of the contract: same visible text, same layout.
def strip(buf: bytes) -> list[str]:
    import re
    text = re.sub(rb"\x1b\[[0-9;]*[A-Za-z]", b"", buf).decode("utf-8", "replace")
    return [ln.rstrip("\r") for ln in text.split("\n")]

if strip(colored) != strip(plain):
    for i, (a, b) in enumerate(zip(strip(colored), strip(plain))):
        if a != b:
            raise SystemExit(f"line {i} differs:\n  colour: {a!r}\n  plain : {b!r}")
    raise SystemExit("line counts differ: "
                     f"{len(strip(colored))} vs {len(strip(plain))}")

print("  ok: colour on TTY, none under NO_COLOR, identical text and layout")
PY

echo "[4/10] pulse.sh keeps its ASCII banner and every heading in plain mode"
for needed in \
  '  :::::::::  :::    ::: :::        ::::::::  :::::::::: ' \
  '  ###         ########  ########## ########  ########## ' \
  '      -- NETWORK LATENCY & SIGNAL DIAGNOSTIC --' \
  '[WIFI ANALYTICS] Interface: en0' \
  'Signal Strength (RSSI): -55 dBm' \
  'Noise Level:          -92 dBm' \
  'Active Channel:       6' \
  '[LATENCY TEST] Pinging core nodes...' \
  'Local Router:   2.0 ms' \
  '[STABILITY] Checking for packet loss (5s)...' \
  'Result: 0.0% packet loss' \
  'Pulse diagnostic complete.'
do
  if ! grep -qF -- "$needed" "$STUB/plain.txt"; then
    echo "FAIL: plain pulse.sh output lost: $needed" >&2
    exit 1
  fi
done
echo "  ok: banner, headings and every measurement survive"

echo "[5/10] mqlaunch pulse --no-color emits zero ANSI end to end"
# BASE_DIR is passed explicitly. bin/mqlaunch defaults it to $HOME/macos-scripts,
# which is true on the developer machine and false on a CI runner — without it
# the launcher exits 1 with "Main launcher not found" and, since that goes to
# stderr, the step would die on set -e with nothing to read.
launch_status=0
PATH="$STUB:$PATH" TERM=xterm-256color MQ_NO_TUI=1 \
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" \
  "$LAUNCH" pulse --no-color > "$STUB/flag.txt" 2>"$STUB/flag.err" || launch_status=$?
if [[ "$launch_status" -ne 0 ]]; then
  echo "FAIL: mqlaunch pulse --no-color exited $launch_status" >&2
  cat "$STUB/flag.err" >&2
  exit 1
fi
flag_esc="$(esc_count "$STUB/flag.txt")"
if [[ "$flag_esc" != "0" ]]; then
  echo "FAIL: mqlaunch pulse --no-color emitted $flag_esc ANSI escapes" >&2
  exit 1
fi
grep -qF -- 'Pulse diagnostic complete.' "$STUB/flag.txt"
echo "  ok: 0 escapes, output still complete"

# --- tools/cli/mq-ui.sh ----------------------------------------------------

echo "[6/10] tools/cli/mq-ui.sh leaves every colour variable empty headless"
# The variables carry `\033[...` as a literal backslash sequence, resolved by
# printf/echo -e at use, so the check is for the two-character prefix, not ESC.
vars_out="$(bash -c "source '$CLI_UI'; printf '<%s><%s><%s><%s><%s><%s>' \
  \"\$C_OK\" \"\$C_WARN\" \"\$C_ERR\" \"\$C_TITLE\" \"\$C_RESET\" \"\${C_BLINK:-}\"")"
if [[ "$vars_out" != "<><><><><><>" ]]; then
  echo "FAIL: colour variables set with stdout redirected: $vars_out" >&2
  exit 1
fi
echo "  ok: C_OK C_WARN C_ERR C_TITLE C_RESET C_BLINK all empty"

echo "[7/10] tools/cli/mq-ui.sh still colours on a real TTY, and not under NO_COLOR"
python3 - "$CLI_UI" <<'PY'
import os, pty, subprocess, sys

cli_ui = sys.argv[1]

def probe(no_color: bool, theme: str = "green") -> str:
    env = dict(os.environ, MQ_THEME=theme, TERM="xterm-256color")
    if no_color:
        env["NO_COLOR"] = "1"
    else:
        env.pop("NO_COLOR", None)
    script = (f'source "{cli_ui}"; '
              r'printf "<%s><%s><%s><%s><%s><%s>" '
              r'"$C_OK" "$C_WARN" "$C_ERR" "$C_TITLE" "$C_RESET" "${C_BLINK:-}"')
    master, slave = pty.openpty()
    proc = subprocess.Popen(["bash", "-c", script], stdout=slave,
                            stderr=subprocess.DEVNULL, env=env)
    os.close(slave)
    out = b""
    while True:
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
    proc.wait()
    os.close(master)
    return out.decode("utf-8", "replace")

for theme in ("green", "amber", "ice"):
    lit = probe(no_color=False, theme=theme)
    assert lit.count("\\033[") == 6, f"{theme}: expected 6 escapes on a TTY, got {lit!r}"
    off = probe(no_color=True, theme=theme)
    assert off.replace("\r", "").replace("\n", "") == "<><><><><><>", \
        f"{theme}: NO_COLOR=1 still set colours: {off!r}"
print("  ok: green, amber and ice all colour on a TTY and all go quiet under NO_COLOR")
PY

echo "[8/10] tools/cli/mq-ui.sh output helpers keep their glyphs and text headless"
helpers_out="$(bash -c "source '$CLI_UI'; \
  header 'HEAD ONE'; section 'SECT TWO'; \
  ok 'ok line'; warn 'warn line'; err 'err line'; blink_err 'blink line'")"
printf '%s' "$helpers_out" > "$STUB/helpers.txt"
helpers_esc="$(esc_count "$STUB/helpers.txt")"
if [[ "$helpers_esc" != "0" ]]; then
  echo "FAIL: helpers emitted $helpers_esc ANSI escapes headless" >&2
  LC_ALL=C cat -v "$STUB/helpers.txt" >&2
  exit 1
fi
for needed in 'HEAD ONE' 'SECT TWO' '✔ ok line' '⚠ warn line' '✖ err line' '✖ blink line'; do
  if ! grep -qF -- "$needed" "$STUB/helpers.txt"; then
    echo "FAIL: helper output lost: $needed" >&2
    exit 1
  fi
done
# hr() draws the rule with box-drawing characters, not ANSI — it must survive.
grep -q '─' "$STUB/helpers.txt"
echo "  ok: 0 escapes, glyphs, labels and rules intact"

echo "[9/10] blink_err carries no hard-coded escape of its own"
# It used to open with a literal \033[5m outside the theme block, so it leaked
# one escape per call even after the C_* variables were emptied.
# Scoped to the function body. A plain grep around the name also catches the
# comment that explains the move, which is prose, not an escape.
blink_body="$(awk '/^blink_err\(\) \{/,/^\}/' "$CLI_UI")"
test -n "$blink_body"
if printf '%s' "$blink_body" | grep -q '\\033\['; then
  echo "FAIL: blink_err still contains a hard-coded escape sequence" >&2
  printf '%s\n' "$blink_body" >&2
  exit 1
fi
echo "  ok: blink uses a guarded variable"

echo "[10/10] both files gate on the same condition as the central guard"
# shellcheck disable=SC2016
for f in "$PULSE" "$CLI_UI"; do
  if ! grep -qF 'if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then' "$f"; then
    echo "FAIL: $f does not use the shared colour guard condition" >&2
    exit 1
  fi
done
echo "  ok: pulse.sh and tools/cli/mq-ui.sh both use the TTY + NO_COLOR guard"

echo "PASS: colour contract for pulse.sh and tools/cli/mq-ui.sh"
