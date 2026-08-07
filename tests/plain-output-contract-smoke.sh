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

echo "[1/13] files exist"
test -f "$UI"
test -f "$LAUNCH"
test -f "$DOCTOR"

echo "[2/13] NO_COLOR suppresses ANSI color on a TTY (behavioural, via pty)"
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

echo "[3/13] NO_COLOR is honoured in the central colour guard (structural)"
# Fixed-string match: the guard line is literal, and ERE brace handling differs
# between BSD (macOS) and GNU (Linux) grep.
# shellcheck disable=SC2016
grep -qF 'if [[ -t 1 && -z "${NO_COLOR:-}" ]]' "$UI"

echo "[4/13] JSON mode prints only JSON to stdout — no banner, no ANSI"
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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Runs `status --json` through a launcher and writes its stdout to $2, returning
# the launcher's own exit status.
#
# BASE_DIR is pinned at this checkout. bin/mqlaunch otherwise defaults it to
# $HOME/macos-scripts, which is true on a developer machine and false on a CI
# runner — there the launcher exits 1 with "Main launcher not found" on stderr,
# and a step that only looked at stdout would be measuring a launcher that never
# ran. MQ_NO_TUI keeps any interactive path from blocking if this regresses.
run_launcher_json() {
  local launcher="$1" outfile="$2" st=0
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
    timeout 60 bash "$launcher" status --json >"$outfile" 2>/dev/null || st=$?
  return "$st"
}

# The startup half of the contract, in one predicate so the planted-defect step
# at the end can assert that breaking it is actually noticed: the launcher must
# exit 0 *and* put bytes on stdout. Either alone is insufficient — a launcher
# that dies produces no output but a launcher that prints a perfectly good
# document and then exits 3 produces plenty.
launcher_json_contract_holds() {
  local launcher="$1" outfile="$2"
  run_launcher_json "$launcher" "$outfile" || return 1
  test -s "$outfile"
}

echo "[5/13] mqlaunch status --json emits JSON only — end-to-end through the launcher"
# The producer being clean is not enough: the launcher is what a caller pipes.
#
# The launcher's own exit status is asserted, not discarded. This step used to
# end in `|| true`; the emptiness check caught a launcher that failed to start,
# but not one that printed a valid document and then exited non-zero. Measured
# on the unfixed step: a stub emitting valid JSON with `exit 3` passed.
if ! launcher_json_contract_holds "$LAUNCH" "$WORK/status.json"; then
  echo "FAIL: mqlaunch status --json did not exit 0 with output on stdout" >&2
  BASE_DIR="$ROOT" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
    bash "$LAUNCH" status --json >/dev/null || true
  exit 1
fi
status_out="$(cat "$WORK/status.json")"
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

echo "[6/13] the JSON status path stays side-effect free (structural)"
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

echo "[7/13] plain status is clean when piped and when redirected"
# The banner was the remaining hole in the contract (#67): the colour guard was
# doing its job — zero ANSI in a pipe — but ASCII art is not colour, so a caller
# who did not know about --json got 5.8 KB of dashboard on stdout and exit 0.
# Parseable-looking, unparseable in practice.
#
# Both destinations are checked because they are different tests of the same
# guard: `| cat` gives a pipe, `> file` gives a regular file, and a check that
# looked at anything other than isatty(1) would pass one and fail the other.
# Under $WORK rather than its own mktemp: an EXIT trap replaces the previous
# one, so a second trap here would silently orphan the directory step 5 uses.
plain_dir="$WORK/plain"
mkdir -p "$plain_dir"

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

echo "[8/13] the header still renders on a terminal (both directions, via pty)"
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

echo "[9/13] --no-color disables colour from the command line (both directions, via pty)"
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

echo "[10/13] repo_state means the same thing on every surface"
# #66: `mqlaunch status`, the dashboard and `mqlaunch version` each derived
# repo_state from `git diff --quiet HEAD`, which sees tracked changes only. A
# checkout holding nothing but untracked files therefore read as `clean` — while
# `mqlaunch git`, which has always gated on `git status --porcelain`, treated the
# same tree as having changes. One repo, two answers to "is this tree clean".
#
# Driven against real checkouts rather than read from the sources. The command
# forms take their repo from BASE_DIR, the install root, so pointing them at a
# fixture would mean copying the whole tree; the derivation they all now call is
# exercised directly instead, and the call sites are asserted structurally below.
repo_probe="$(mktemp -d)"
repo_plain="$(mktemp -d)"
git -C "$repo_probe" init -q
printf 'x\n' > "$repo_probe/tracked.txt"
git -C "$repo_probe" add tracked.txt
git -C "$repo_probe" -c user.email=t@t -c user.name=t commit -qm init

# Coordinates state of behavior.
state_of() {
  bash -c 'source "$1/ui/terminal-ui/mq-ui.sh" >/dev/null 2>&1; mq_repo_state "$2"' \
    _ "$ROOT" "$1"
}

# Coordinates expect state behavior.
expect_state() {
  # expect_state <repo> <expected> <what>
  local got
  got="$(state_of "$1")"
  if [[ "$got" != "$2" ]]; then
    echo "FAIL: $3 reported '$got', expected '$2'" >&2
    rm -rf "$repo_probe" "$repo_plain"
    exit 1
  fi
}

expect_state "$repo_probe" "clean" "a committed checkout with nothing pending"

touch "$repo_probe/untracked.txt"
expect_state "$repo_probe" "dirty" "a checkout holding only an untracked file"
# The regression this pins: prove the old derivation disagrees, so the fixture
# cannot quietly start passing for the wrong reason if it is ever reverted.
if ! git -C "$repo_probe" diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
  echo "FAIL: the untracked-only fixture is also tracked-dirty — it proves nothing" >&2
  rm -rf "$repo_probe" "$repo_plain"
  exit 1
fi

rm "$repo_probe/untracked.txt"
printf 'y\n' > "$repo_probe/tracked.txt"
expect_state "$repo_probe" "dirty" "a checkout with a modified tracked file"

expect_state "$repo_plain" "not-a-git-repo" "a directory that is not a checkout"

rm -rf "$repo_probe" "$repo_plain"

# All three reporting surfaces must use that one derivation. Without this, the
# checks above would keep passing while a surface quietly went back to its own
# git call — which is exactly how they diverged.
for surface in \
  "$ROOT/terminal/launchers/mqlaunch-command-mode.sh" \
  "$ROOT/terminal/launchers/mqlaunch.sh"; do
  grep -q 'mq_repo_state' "$surface" || {
    echo "FAIL: $surface no longer derives repo_state from mq_repo_state" >&2
    exit 1
  }
done
stale="$(grep -rn 'diff --quiet --ignore-submodules HEAD' \
  "$ROOT/terminal/launchers/mqlaunch.sh" \
  "$ROOT/terminal/launchers/mqlaunch-command-mode.sh" || true)"
if [[ -n "$stale" ]]; then
  echo "FAIL: a surface derives repo_state from a tracked-only diff again:" >&2
  printf '%s\n' "$stale" >&2
  exit 1
fi
echo "  ok: clean, dirty (tracked and untracked), and not-a-git-repo"

echo "[11/13] reporting surfaces stay quiet when the terminal is unknown"
# A stripped environment has no TERM: a GUI launch, a cron job, a nested
# launcher, a CI runner. `tput cols` fails there and prints its own complaint.
#
# This step exists because the rest of this file could not see that. Every check
# above either sets TERM=xterm-256color or sends stderr to DEVNULL, so
# `mqlaunch doctor` could emit a screenful of 'tput: No value for $TERM' and
# 'printf: : invalid number' on stderr and still pass the output contract. The
# first command a new operator runs looked broken while the gate stayed green.
#
# stderr is the assertion. Exit status is not: doctor exits 0 through all of it,
# which is why nothing ever reported it.
term_err="$(mktemp)"
env -u TERM -u COLUMNS MACOS_SCRIPTS_HOME="$ROOT" \
  bash "$DOCTOR" >/dev/null 2>"$term_err" || true
if [[ -s "$term_err" ]]; then
  echo "FAIL: doctor writes to stderr when TERM is unset:" >&2
  sort -u "$term_err" >&2
  rm -f "$term_err"
  exit 1
fi
rm -f "$term_err"

# The separators must still be drawn, and be readable text rather than a run of
# broken bytes. Two failure modes are pinned here:
#
#   * width ''      — the printf defect above left blank lines, not missing lines
#   * `tr ' ' '─'`  — tr is byte-oriented, so under a C locale it maps each space
#                     to 0xe2, the first byte of ─, and the rule becomes invalid
#                     UTF-8. A stripped environment drops LANG along with TERM.
#
# Asserted by decoding, not by grepping for the glyph: a grep for '─' depends on
# the locale of whoever runs the suite, which is the same trap the rule itself
# fell into. Run under LC_ALL=C deliberately — that is the hostile case.
rule_out="$(env -u TERM -u COLUMNS LC_ALL=C LANG=C MACOS_SCRIPTS_HOME="$ROOT" \
  bash "$DOCTOR" 2>/dev/null || true)"
printf '%s' "$rule_out" | python3 -c '
import sys
raw = sys.stdin.buffer.read()
try:
    text = raw.decode("utf-8")
except UnicodeDecodeError as exc:
    sys.exit(f"FAIL: doctor output is not valid UTF-8 with TERM unset: {exc}")
runs = [len(l) for l in text.splitlines() if l and set(l) == {"─"}]
if not runs:
    sys.exit("FAIL: doctor drew no horizontal rule with TERM unset")
if max(runs) < 60:
    sys.exit(f"FAIL: widest rule was {max(runs)} chars, below the 60-column clamp")
' || exit 1
echo "  ok: no stderr noise, rules drawn as valid UTF-8 without TERM or LANG"

echo "[12/13] no dispatched tool clears the screen unguarded"
# Step 11 proves `doctor` is quiet without TERM by running it. That does not
# generalise: `pulse` takes twenty seconds of network probing, so executing every
# command to check the same property would make the suite unusable.
#
# A bare `clear` is the whole defect. Without TERM it writes "TERM environment
# variable not set." to stderr and exits non-zero — which is what `mqlaunch pulse`
# did, from a GUI launch, cron or a CI runner. The repo already had the fix in
# four scripts (`clear 2>/dev/null || true`); it was simply not everywhere.
#
# Scoped to the scripts the dispatcher actually invokes, because that is the
# surface a caller reaches through the documented CLI. Menus and TUI internals
# always have a terminal by construction and are out of it. The relation is read
# from the dispatcher rather than guessed from filenames — a basename match would
# be a heuristic, and the expected count here is zero, so there is no allowance
# for one being wrong.
python3 - "$ROOT" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
dispatch = (root / "terminal/launchers/mqlaunch-command-mode.sh").read_text(
    encoding="utf-8", errors="replace"
)
invoked = sorted(set(re.findall(r"\$BASE_DIR/(tools/scripts/[A-Za-z0-9_./-]+\.sh)", dispatch)))
if not invoked:
    sys.exit("FAIL: found no dispatched tools/scripts paths — the regex or the dispatcher moved")

bare = re.compile(r"^\s*clear\s*$")
offenders = []
for rel in invoked:
    path = root / rel
    if not path.is_file():
        continue
    for number, line in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        if bare.match(line):
            offenders.append(f"{rel}:{number}")

if offenders:
    sys.exit(
        "FAIL: unguarded `clear` in dispatched tools — use `clear 2>/dev/null || true`:\n  "
        + "\n  ".join(offenders)
    )
print(f"  ok: {len(invoked)} dispatched tools, none clearing unguarded")
PY

echo "[13/13] a launcher that fails to start makes step 5 fail"
# The step above proves the contract holds. This one proves the step can notice
# when it does not — otherwise a launcher that stopped running would be reported
# as a passing output contract, which is the failure mode this test exists to
# rule out.
#
# Three stubs, one per way the startup contract can break. The third is the one
# that motivated the change: it produces a document indistinguishable from the
# real thing and only the exit status gives it away.
planted="$WORK/planted"
mkdir -p "$planted"

cat > "$planted/dead" <<'EOF'
#!/usr/bin/env bash
echo "[MQ] Main launcher not found or not executable" >&2
exit 1
EOF

cat > "$planted/silent" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$planted/wrong-status" <<'EOF'
#!/usr/bin/env bash
printf '{"project":"x","version":"0","repo_state":"clean"}'
exit 3
EOF

chmod +x "$planted/dead" "$planted/silent" "$planted/wrong-status"

for defect in dead silent wrong-status; do
  if launcher_json_contract_holds "$planted/$defect" "$WORK/planted.out"; then
    echo "FAIL: the '$defect' launcher defect was not detected" >&2
    exit 1
  fi
done

# And the real launcher must still pass the same predicate, so the three
# rejections above are not simply a predicate that rejects everything.
launcher_json_contract_holds "$LAUNCH" "$WORK/planted.out"
echo "  ok: startup failure, empty output and a bad exit status are all caught"

echo "PASS: output contract holds (no decoration off-TTY, colour opt-out, clean JSON)"
