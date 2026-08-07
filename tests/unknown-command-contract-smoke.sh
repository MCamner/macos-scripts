#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/home"
SIDE_EFFECT_LOG="$TMPDIR_TEST/side-effects.log"

for command_name in pbcopy open; do
  cat > "$TMPDIR_TEST/bin/$command_name" <<EOF
#!/usr/bin/env bash
printf '%s\n' '$command_name' >> '$SIDE_EFFECT_LOG'
EOF
  chmod +x "$TMPDIR_TEST/bin/$command_name"
done

# Runs unknown.
run_unknown() {
  local label="$1"
  local unknown="${2:-definitely-not-a-command}"
  local stdout_file="$TMPDIR_TEST/$label.stdout"
  local stderr_file="$TMPDIR_TEST/$label.stderr"
  local status

  set +e
  HOME="$TMPDIR_TEST/home" \
    PATH="$TMPDIR_TEST/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    MACOS_SCRIPTS_HOME="$ROOT" \
    MQ_NO_TUI=1 \
    MQLAUNCH_HEADLESS=1 \
    "$LAUNCHER" "$unknown" >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  [[ $status -eq 2 ]] || {
    echo "$label: expected exit 2, got $status" >&2
    return 1
  }
  [[ ! -s "$stdout_file" ]] || {
    echo "$label: unknown-command diagnostics leaked to stdout" >&2
    return 1
  }
  grep -q "Unknown command: $unknown" "$stderr_file"
  grep -q 'mqlaunch ask' "$stderr_file"
}

# Runs tty unknown.
run_tty_unknown() {
  local output_file="$TMPDIR_TEST/tty.output"
  local status

  set +e
  python3 - "$LAUNCHER" "$ROOT" "$TMPDIR_TEST" >"$output_file" <<'PY'
import os
import sys

launcher, root, temp = sys.argv[1:]
pid, fd = os.forkpty()
if pid == 0:
    env = os.environ.copy()
    env.update(
        HOME=f"{temp}/home",
        PATH=f"{temp}/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        MACOS_SCRIPTS_HOME=root,
    )
    env.pop("MQ_NO_TUI", None)
    env.pop("MQLAUNCH_HEADLESS", None)
    os.execve(launcher, [launcher, "doctro"], env)

while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    sys.stdout.buffer.write(chunk)

_, wait_status = os.waitpid(pid, 0)
raise SystemExit(os.waitstatus_to_exitcode(wait_status))
PY
  status=$?
  set -e

  [[ $status -eq 2 ]] || {
    echo "tty: expected exit 2, got $status" >&2
    return 1
  }
  grep -q 'Unknown command: doctro' "$output_file"
}

# Runs discover input contract.
run_discover_input_contract() {
  local output expected exit_output

  output="$(
    ROOT_UNDER_TEST="$ROOT" bash <<'BASH'
set -euo pipefail
BASE_DIR="$ROOT_UNDER_TEST"
APP_TITLE="MQLAUNCH"
source "$ROOT_UNDER_TEST/terminal/menus/mq-main-menu.sh"

# Opens command palette or help.
open_command_palette_or_help() { printf 'palette\n'; }
# Opens help or index.
open_help_or_index() { printf 'help\n'; }
# Runs main shell command.
run_main_shell_command() { printf 'shell:%s\n' "$1"; }
# Runs mqworkflows.
run_mqworkflows() { printf 'command:workflows\n'; }
# Routes cli command to the matching command handler.
dispatch_cli_command() {
  printf 'unknown:%s\n' "$*"
  return 0
}
# Pauses until Enter is pressed.
pause_enter() { :; }

for original in "/" "/." "/ Palette" "/. Palette" "?" "?." "? Help" "?. Help index" "!printf contract-shell" "workflows"; do
  handle_main_menu_choice "$original"
done
BASH
  )"

  expected="$(printf 'palette\npalette\npalette\npalette\nhelp\nhelp\nhelp\nhelp\nshell:printf contract-shell\ncommand:workflows')"
  [[ "$output" == "$expected" ]] || {
    echo "DISCOVER input escaped its advertised route:" >&2
    printf '%s\n' "$output" >&2
    return 1
  }

  exit_output="$(
    ROOT_UNDER_TEST="$ROOT" bash <<'BASH'
set -euo pipefail
BASE_DIR="$ROOT_UNDER_TEST"
APP_TITLE="MQLAUNCH"
source "$ROOT_UNDER_TEST/terminal/menus/mq-main-menu.sh"
handle_main_menu_choice "x"
BASH
  )"
  [[ "$exit_output" == "Exiting MQLAUNCH..." ]] || {
    echo "DISCOVER x shortcut did not exit cleanly" >&2
    return 1
  }
}

echo "SMOKE: unknown command contract"
run_unknown redirected
printf '' | run_unknown headless
run_unknown nearest-command doctro
grep -q 'Did you mean: mqlaunch doctor' "$TMPDIR_TEST/nearest-command.stderr"
run_tty_unknown
run_discover_input_contract

[[ ! -e "$SIDE_EFFECT_LOG" ]] || {
  echo "unknown command triggered a clipboard or open side effect" >&2
  exit 1
}

bash -n "$0"
echo "OK: unknown commands are side-effect free and return 2"
