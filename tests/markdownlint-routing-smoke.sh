#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/scripts/markdownlint.sh"
MENU="$ROOT/terminal/menus/mq-tools-menu.sh"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
COMMANDS="$ROOT/docs/COMMANDS.md"
README="$ROOT/README.md"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/repo"
cat > "$TMPDIR_TEST/bin/markdownlint-cli2" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$MARKDOWNLINT_ARGS_FILE"
exit "${MARKDOWNLINT_EXIT:-0}"
FAKE
chmod +x "$TMPDIR_TEST/bin/markdownlint-cli2"

export PATH="$TMPDIR_TEST/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MARKDOWNLINT_ARGS_FILE="$TMPDIR_TEST/args"

echo "[1/9] tool exists and has valid syntax"
test -x "$TOOL"
bash -n "$TOOL"

echo "[2/9] default target is all Markdown files in the current repo"
(cd "$TMPDIR_TEST/repo" && "$TOOL")
test "$(cat "$MARKDOWNLINT_ARGS_FILE")" = "**/*.md"

echo "[3/9] arguments and markdownlint exit code are preserved"
set +e
(cd "$TMPDIR_TEST/repo" && MARKDOWNLINT_EXIT=7 "$TOOL" --fix ROADMAP.md)
status=$?
set -e
test "$status" -eq 7
printf '%s\n' --fix ROADMAP.md > "$TMPDIR_TEST/expected"
cmp -s "$TMPDIR_TEST/expected" "$MARKDOWNLINT_ARGS_FILE"

echo "[4/9] mqlaunch command mode exposes the direct route"
grep -q 'markdownlint|mdlint)' "$COMMAND_MODE"
grep -q 'tools/scripts/markdownlint.sh' "$COMMAND_MODE"

echo "[5/9] mqlaunch preserves markdownlint arguments and exit code"
set +e
(cd "$TMPDIR_TEST/repo" && MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
  MQLAUNCH_HEADLESS=1 MARKDOWNLINT_EXIT=7 \
  "$ROOT/terminal/launchers/mqlaunch.sh" markdownlint --fix ROADMAP.md)
status=$?
set -e
test "$status" -eq 7
cmp -s "$TMPDIR_TEST/expected" "$MARKDOWNLINT_ARGS_FILE"

echo "[6/9] Tools menu exposes lint and guarded fix actions"
grep -q '23. Markdown lint' "$MENU"
grep -q '24. Markdown fix' "$MENU"
grep -q 'run_markdownlint_fix' "$MENU"
grep -q 'Fix Markdown files now? \[y/N\]' "$MENU"

echo "[7/9] fix menu action defaults to cancellation"
rm -f "$MARKDOWNLINT_ARGS_FILE"
printf 'n\n' | MACOS_SCRIPTS_HOME="$ROOT" MQ_WORK_DIR="$TMPDIR_TEST/repo" \
  "$MENU" markdownlint-fix ROADMAP.md >/dev/null
test ! -e "$MARKDOWNLINT_ARGS_FILE"

echo "[8/9] confirmed fix menu action invokes markdownlint --fix"
printf 'y\n' | MACOS_SCRIPTS_HOME="$ROOT" MQ_WORK_DIR="$TMPDIR_TEST/repo" \
  "$MENU" markdownlint-fix ROADMAP.md >/dev/null
cmp -s "$TMPDIR_TEST/expected" "$MARKDOWNLINT_ARGS_FILE"

echo "[9/9] command is documented"
grep -q 'mqlaunch markdownlint' "$COMMANDS"
grep -q 'mqlaunch markdownlint' "$README"
grep -q 'mqlaunch markdownlint' "$COMMAND_MODE"

bash -n "$MENU" "$COMMAND_MODE" "$0"
echo "OK: markdownlint tool, routes, menu guard and docs"
