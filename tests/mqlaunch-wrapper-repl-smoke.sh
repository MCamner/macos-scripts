#!/usr/bin/env bash
# Regression guard for four gaps in the mqlaunch entry points:
#   1. bin/mqlaunch and the REPL must honour MACOS_SCRIPTS_HOME (what install.sh
#      exports), not only BASE_DIR, so an install outside ~/macos-scripts works.
#   2. REPL perf/dev/demo must reach mqlaunch.sh's command router. They used to
#      execute bridge files that only define functions (status 0, no effect) or
#      call a function that does not exist (run_demo, status 127).
#   3. `mqlaunch dashboard --no-color` must work: the wrapper's dashboard
#      shortcut bypassed mqlaunch.sh, which is where --no-color is stripped.
#   4. The REPL must emit no ANSI escapes when NO_COLOR is set.
# Real files are copied into a temp tree; downstream targets are stubs that
# record their argv, so nothing interactive runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Marks a failing check.
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

TREE="$TMP/install"
LOG="$TMP/calls.log"
mkdir -p "$TREE/bin" "$TREE/terminal/launchers" "$TREE/terminal/dashboard" "$TMP/home"
cp "$ROOT/bin/mqlaunch" "$TREE/bin/mqlaunch"
cp "$ROOT/terminal/launchers/mqlaunch-repl.sh" "$TREE/terminal/launchers/mqlaunch-repl.sh"
chmod +x "$TREE/bin/mqlaunch" "$TREE/terminal/launchers/mqlaunch-repl.sh"

cat > "$TREE/terminal/launchers/mqlaunch.sh" <<EOF
#!/usr/bin/env bash
printf 'launcher %s\n' "\$*" >> "$LOG"
EOF
chmod +x "$TREE/terminal/launchers/mqlaunch.sh"

cat > "$TREE/terminal/dashboard/mq_dashboard.py" <<EOF
import os, sys
with open("$LOG", "a") as f:
    f.write("dashboard %s NO_COLOR=%s\n" % (" ".join(sys.argv[1:]), os.environ.get("NO_COLOR", "")))
EOF

# Runs a command with a clean install environment: no BASE_DIR, empty HOME.
run_clean() {
  env -u BASE_DIR -u NO_COLOR HOME="$TMP/home" MACOS_SCRIPTS_HOME="$TREE" "$@"
}

# 1. MACOS_SCRIPTS_HOME
: > "$LOG"
run_clean "$TREE/bin/mqlaunch" help >/dev/null 2>&1 \
  || fail "bin/mqlaunch help exits non-zero with only MACOS_SCRIPTS_HOME set"
grep -qx 'launcher help' "$LOG" || fail "bin/mqlaunch did not reach mqlaunch.sh via MACOS_SCRIPTS_HOME"

# 2. REPL perf/dev/demo route to mqlaunch.sh
for cmd in perf dev demo; do
  : > "$LOG"
  out="$(printf '%s\nx\n' "$cmd" | run_clean "$TREE/terminal/launchers/mqlaunch-repl.sh" 2>&1)" \
    || fail "REPL exited non-zero on '$cmd'"
  case "$out" in *"command not found"*) fail "REPL '$cmd': $out" ;; esac
  grep -qx "launcher $cmd" "$LOG" || fail "REPL '$cmd' did not delegate to mqlaunch.sh $cmd"
done

# 3. dashboard --no-color after the subcommand
: > "$LOG"
run_clean "$TREE/bin/mqlaunch" dashboard --no-color --json >/dev/null 2>&1 \
  || fail "mqlaunch dashboard --no-color exits non-zero"
grep -qx 'dashboard --json NO_COLOR=1' "$LOG" \
  || fail "dashboard --no-color not stripped/exported: $(cat "$LOG")"

# 4. REPL honours NO_COLOR (the shell fallback line is colored by default)
colored="$(printf 'true\nx\n' | run_clean "$TREE/terminal/launchers/mqlaunch-repl.sh" 2>&1)"
[[ "$colored" == *$'\033['* ]] || fail "sanity: REPL output has no ANSI without NO_COLOR"
plain="$(printf 'true\nx\n' | run_clean env NO_COLOR=1 "$TREE/terminal/launchers/mqlaunch-repl.sh" 2>&1)"
[[ "$plain" != *$'\033['* ]] || fail "REPL emits ANSI escapes with NO_COLOR=1"

printf '[PASS] mqlaunch wrapper/REPL: install dir, perf/dev/demo routing, --no-color, NO_COLOR\n'
