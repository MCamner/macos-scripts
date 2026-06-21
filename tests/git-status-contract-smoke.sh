#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$1"
}

git -C "$TMP_REPO" init -q
git -C "$TMP_REPO" config user.name "MQ Test"
git -C "$TMP_REPO" config user.email "mq-test@example.invalid"
printf 'base\n' > "$TMP_REPO/tracked.txt"
git -C "$TMP_REPO" add tracked.txt
git -C "$TMP_REPO" commit -qm "base"

mkdir -p "$TMP_REPO/generated"
printf 'one\n' > "$TMP_REPO/generated/one.txt"
printf 'two\n' > "$TMP_REPO/generated/two.txt"
printf 'three\n' > "$TMP_REPO/generated/three.txt"
printf 'changed\n' >> "$TMP_REPO/tracked.txt"

# shellcheck disable=SC1090
source "$ROOT/ui/terminal-ui/mq-ui.sh"
snapshot="$(mq_git_status_snapshot "$TMP_REPO")"
[[ "$(printf '%s' "$snapshot" | cut -d'|' -f1)" == "0" ]] || fail "staged count"
[[ "$(printf '%s' "$snapshot" | cut -d'|' -f2)" == "1" ]] || fail "unstaged count"
[[ "$(printf '%s' "$snapshot" | cut -d'|' -f3)" == "1" ]] || fail "untracked directory count"
[[ "$(printf '%s' "$snapshot" | cut -d'|' -f4)" == "2" ]] || fail "canonical change count"
[[ "$(printf '%s' "$snapshot" | cut -d'|' -f5)" == "DIRTY" ]] || fail "dirty state"
[[ "$(printf '%s' "$snapshot" | cut -d'|' -f6)" == "LOW" ]] || fail "dirty severity"
[[ "$(surface_git_state "$TMP_REPO")" == "Dirty (2)" ]] || fail "surface state"
pass "shared Git snapshot uses porcelain entries"

zsh_snapshot="$(zsh -c 'source "$1"; mq_git_status_snapshot "$2"' _ "$ROOT/ui/terminal-ui/mq-ui.sh" "$TMP_REPO")"
[[ "$(printf '%s' "$zsh_snapshot" | cut -d'|' -f4)" == "2" ]] || fail "zsh snapshot"
pass "shared Git snapshot works in zsh"

MACOS_SCRIPTS_HOME="$ROOT"
# shellcheck disable=SC1090
source "$ROOT/terminal/menus/mq-release-menu.sh"
RELEASE_REPO="$TMP_REPO"
printf '1.0.0\n' > "$TMP_REPO/VERSION"
printf '# Changelog\n' > "$TMP_REPO/CHANGELOG.md"
printf '#!/usr/bin/env bash\n' > "$TMP_REPO/release.sh"
chmod +x "$TMP_REPO/release.sh"
refresh_release_paths

[[ "$(release_status_line)" == "blocked — dirty (5)" ]] || fail "release blocked count"
[[ "$(release_status_next)" == "Next: 1. Review status" ]] || fail "release next action"
pass "release footer blocks dirty repositories"

git -C "$TMP_REPO" add -A
git -C "$TMP_REPO" commit -qm "clean"
[[ "$(release_status_line)" == "ready (v1.0.0)" ]] || fail "clean release status"
pass "release footer reports clean repositories ready"

dashboard="$( (cd "$TMP_REPO" && MACOS_SCRIPTS_HOME="$ROOT" bash "$ROOT/ui/ascii/mqlaunch-dashboard-v7.1.sh") 2>&1)"
printf '%s\n' "$dashboard" | grep -q 'DIRTY    0 files' && fail "dashboard unexpectedly dirty"
pass "dashboard consumes shared Git snapshot"

printf 'OK: shared Git/release status contract passed\n'
