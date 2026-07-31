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

run_palette_shortcut_contract() {
  local output expected
  output="$(
    ROOT_UNDER_TEST="$ROOT" bash <<'BASH'
set -euo pipefail
BASE_DIR="$ROOT_UNDER_TEST"
source "$ROOT_UNDER_TEST/terminal/menus/mq-main-menu.sh"

run_command_palette() {
  printf 'palette\n'
}

# These are failure sentinels: a recognized shortcut must return before either
# generic path. They deliberately succeed after printing so the output
# comparison catches the fallthrough rather than set -e hiding it.
dispatch_cli_command() {
  printf 'unknown:%s\n' "$*"
  return 0
}
run_main_shell_command() {
  printf 'shell:%s\n' "$*"
  return 0
}

for original in "/" "/." "/ palette" "/. Palette"; do
  normalized="$(printf '%s' "$original" | tr '[:upper:]' '[:lower:]')"
  handle_main_prompt_command "$normalized" "$original"
done
BASH
  )"
  expected="$(printf 'palette\npalette\npalette\npalette')"
  [[ "$output" == "$expected" ]] || {
    echo "palette shortcuts escaped to an unknown-command or shell route:" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
}

echo "SMOKE: unknown command contract"
run_unknown redirected
printf '' | run_unknown headless
run_unknown nearest-command doctro
grep -q 'Did you mean: mqlaunch doctor' "$TMPDIR_TEST/nearest-command.stderr"
run_tty_unknown
run_palette_shortcut_contract

[[ ! -e "$SIDE_EFFECT_LOG" ]] || {
  echo "unknown command triggered a clipboard or open side effect" >&2
  exit 1
}

bash -n "$0"
echo "OK: unknown commands are side-effect free and return 2"
