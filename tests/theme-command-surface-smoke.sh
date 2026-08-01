#!/usr/bin/env bash
set -euo pipefail

# The themes menu offered seven actions; the CLI could reach two of them.
# `theme-macos` and `theme-reset` existed, so amber, green, minimal, ice and
# `current` were menu-only — not because the capability was missing, but because
# nothing declared or routed them. `theme_cmd` has always been a pass-through to
# mq-zsh-theme-switcher.sh, which documents `apply <variant>` itself.
#
# Worse than the gap: `theme|themes)` called open_themes_menu and dropped
# everything after the command, so `mqlaunch theme apply amber` opened a menu
# and said nothing about the two words it ignored.
#
# This test drives the dispatcher directly and asserts on the arguments
# theme_cmd receives, so it never touches the real switcher or ~/.zshrc.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

export MACOS_SCRIPTS_HOME="$ROOT"
# shellcheck source=/dev/null
source "$COMMAND_MODE"

CALLS="$TMPDIR_TEST/calls.log"

theme_cmd() {
  printf 'theme_cmd %s\n' "$*" >> "$CALLS"
  return 0
}

open_themes_menu() {
  printf 'menu\n' >> "$CALLS"
  return 0
}

pause_enter() { return 0; }

assert_call() {
  local expected="$1"
  shift
  : > "$CALLS"
  dispatch_cli_command "$@" >/dev/null 2>&1
  local actual
  actual="$(tr -d '\n' < "$CALLS")"
  [[ "$actual" == "$expected" ]] || {
    echo "  mqlaunch $*" >&2
    echo "    expected: $expected" >&2
    echo "    actual:   ${actual:-<nothing>}" >&2
    return 1
  }
}

echo "SMOKE: theme command surface"

echo "[1/9] bare theme still opens the menu"
assert_call 'menu' theme
assert_call 'menu' themes
assert_call 'menu' theme menu

echo "[2/9] apply reaches the switcher with its variant"
assert_call 'theme_cmd apply amber' theme apply amber
assert_call 'theme_cmd apply green' theme apply green
assert_call 'theme_cmd apply minimal' theme apply minimal
assert_call 'theme_cmd apply ice' theme apply ice
assert_call 'theme_cmd apply macos' theme apply macos

echo "[3/9] current, list and reset reach the switcher"
assert_call 'theme_cmd current' theme current
assert_call 'theme_cmd list' theme list
assert_call 'theme_cmd reset' theme reset

echo "[4/9] compatibility spellings keep working"
assert_call 'theme_cmd apply macos' theme-macos
assert_call 'theme_cmd reset' theme-reset

echo "[5/9] an unknown subcommand forwards rather than opening the menu"
# The switcher answers with `Unknown command` and exit 1. Silently showing a
# menu instead would repeat the bug this test exists for.
assert_call 'theme_cmd nonsense' theme nonsense

echo "[6/9] apply without a variant forwards too"
# mq-zsh-theme-switcher.sh prints usage and exits 1 when apply has no argument.
# The dispatcher must not invent a default or swallow the error.
assert_call 'theme_cmd apply' theme apply

echo "[7/9] the switcher's exit code survives the dispatcher"
# Found by running the command rather than the test: `mqlaunch theme nonsense`
# printed `Unknown command` and exited 0, because the arm ended in a bare
# `return 0` that overwrote the delegate's status. docs/RUNTIME_AUTHORITY.md
# lists exit-code preservation as an authority responsibility, and
# delegated-exit-code-smoke.sh holds the same line for the agent backends.
theme_cmd() {
  printf 'theme_cmd %s\n' "$*" >> "$CALLS"
  return "${MQ_TEST_THEME_STATUS:-0}"
}

assert_status() {
  local expected="$1"
  shift
  local actual
  set +e
  dispatch_cli_command "$@" >/dev/null 2>&1
  actual=$?
  set -e
  [[ $actual -eq $expected ]] || {
    echo "  mqlaunch $*: expected exit $expected, got $actual" >&2
    return 1
  }
}

MQ_TEST_THEME_STATUS=1 assert_status 1 theme nonsense
MQ_TEST_THEME_STATUS=1 assert_status 1 theme apply
MQ_TEST_THEME_STATUS=2 assert_status 2 theme apply amber
MQ_TEST_THEME_STATUS=0 assert_status 0 theme current
MQ_TEST_THEME_STATUS=1 assert_status 1 theme-macos
MQ_TEST_THEME_STATUS=1 assert_status 1 theme-reset

echo "[8/9] the registry declares every subcommand the dispatcher routes"
python3 - "$REGISTRY" <<'PY'
import json, sys

registry = json.load(open(sys.argv[1]))
theme = next(c for c in registry["commands"] if c["name"] == "theme")

declared = {s["name"] for s in theme.get("subcommands", [])}
required = {"menu", "apply", "current", "list", "reset"}
missing = required - declared
if missing:
    raise SystemExit(f"theme is missing subcommands: {sorted(missing)}")

if theme.get("unknown_subcommand") != "forward":
    raise SystemExit(
        "theme must record that it forwards unknown subcommands, so a consumer "
        "knows its list is not the whole surface"
    )
PY

echo "[9/9] the menu and the CLI offer the same variants"
# The menu was the only way in for four of these. If someone adds a sixth
# variant to the switcher, both surfaces should grow together.
variants_switcher="$(sed -n '/^theme_list()/,/^}/p' "$ROOT/terminal/themes/mq-zsh-theme-switcher.sh" |
  grep -oE '^(amber|green|minimal|ice|macos)$' | sort | tr '\n' ' ')"
variants_menu="$(grep -oE 'theme_cmd apply [a-z]+' "$ROOT/terminal/menus/mq-themes-menu.sh" |
  awk '{print $3}' | sort | tr '\n' ' ')"
[[ "$variants_switcher" == "$variants_menu" ]] || {
  echo "  switcher offers: $variants_switcher" >&2
  echo "  menu offers:     $variants_menu" >&2
  exit 1
}

echo "PASS: theme command surface"
